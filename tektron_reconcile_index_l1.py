#!/usr/bin/env python3
"""
Reconciliación limpia de index_l1 (única vía tras mutar chunks.jsonl).

Fuente de verdad:  chunks.jsonl
Derivados:         meta.json  (conteos de polo)
                   faiss.idx  (solo se toca con --rebuild-faiss)
                   bm25.pkl   (junto a FAISS)

NO incrementa n_sit a mano. NO arranca el bridge.
NO es un parche: normaliza polos + regenera meta + smoke IndexL1.

Uso Jetson (estado actual: FAISS ya sync, bridge crash por meta):

  sudo systemctl stop tektron-bridge.service

  /mnt/tektron/venv_tektron/bin/python3 \\
    /mnt/tektron/workspace/tektron_reconcile_index_l1.py --dry-run

  /mnt/tektron/venv_tektron/bin/python3 \\
    /mnt/tektron/workspace/tektron_reconcile_index_l1.py --apply

  # si smoke OK → un solo arranque del bridge (nohup o systemctl start)
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("TEKTRON_ROOT", "/mnt/tektron"))
L1_DEFAULT = Path(os.environ.get("TEKTRON_INDEX_L1", str(ROOT / "index_l1")))

# Vocabulario canónico que usa IndexL1 / corpus histórico L1
CANON = {
    "SIT": "SITUADO",
    "SITUADO": "SITUADO",
    "SITUADA": "SITUADO",
    "HEG": "HEGEMONICO",
    "HEGEMONICO": "HEGEMONICO",
    "HEGEMÓNICO": "HEGEMONICO",
    "HEGEMONICA": "HEGEMONICO",
    "HEGEMÓNICA": "HEGEMONICO",
    "TEC": "TECNICO",
    "TECNICO": "TECNICO",
    "TÉCNICO": "TECNICO",
    "TECH": "TECNICO",
}


def polo_of(row: dict) -> str:
    raw = row.get("tipo_epistemico") or row.get("polo") or row.get("tipo") or ""
    s = str(raw).strip().upper()
    return CANON.get(s, s or "?")


def normalize_row(row: dict) -> tuple[dict, bool]:
    p = polo_of(row)
    changed = False
    out = dict(row)
    if p in ("SITUADO", "HEGEMONICO", "TECNICO"):
        if out.get("tipo_epistemico") != p or out.get("polo") != p:
            out["tipo_epistemico"] = p
            out["polo"] = p
            changed = True
    return out, changed


def load_jsonl(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8", errors="ignore") as f:
        for i, line in enumerate(f, 1):
            if not line.strip():
                continue
            rows.append(json.loads(line))
    return rows


def write_jsonl(path: Path, rows: list[dict]) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    tmp.replace(path)


def check_faiss(l1: Path, n_chunks: int) -> dict:
    info = {"ok": False, "ntotal": None, "dim": None, "path": str(l1 / "faiss.idx")}
    faiss_path = l1 / "faiss.idx"
    if not faiss_path.exists():
        info["error"] = "missing faiss.idx"
        return info
    try:
        import faiss

        idx = faiss.read_index(str(faiss_path))
        info["ntotal"] = int(idx.ntotal)
        info["dim"] = int(idx.d)
        info["ok"] = idx.ntotal == n_chunks
        if not info["ok"]:
            info["error"] = f"desync faiss={idx.ntotal} jsonl={n_chunks}"
    except Exception as e:
        info["error"] = f"{type(e).__name__}: {e}"
    return info


def smoke_index_l1(l1: Path) -> dict:
    """Carga IndexL1 exactamente como el bridge. Debe pasar el assert n_sit."""
    try:
        sys.path.insert(0, str(ROOT))
        from retrieve_l1 import IndexL1  # type: ignore

        idx = IndexL1(str(l1), device="cpu")
        return {
            "ok": True,
            "set_sit": len(getattr(idx, "set_sit", [])),
            "meta_n_sit": (getattr(idx, "meta", {}) or {}).get("n_sit"),
            "n_chunks": len(getattr(idx, "chunks", getattr(idx, "docs", [])) or []),
        }
    except Exception as e:
        return {"ok": False, "error": f"{type(e).__name__}: {e}"}


def main() -> None:
    ap = argparse.ArgumentParser(description="Reconciliar index_l1 desde chunks.jsonl")
    ap.add_argument("--l1", type=Path, default=L1_DEFAULT)
    ap.add_argument("--dry-run", action="store_true", help="solo reportar (default si no --apply)")
    ap.add_argument("--apply", action="store_true", help="escribir chunks+meta")
    ap.add_argument(
        "--rebuild-faiss",
        action="store_true",
        help="además re-embeber FAISS (solo si faiss desync; lento en CPU)",
    )
    ap.add_argument("--skip-smoke", action="store_true")
    args = ap.parse_args()

    if not args.apply:
        args.dry_run = True

    l1 = args.l1
    chunks_path = l1 / "chunks.jsonl"
    meta_path = l1 / "meta.json"
    if not chunks_path.exists():
        raise SystemExit(f"ERROR: no existe {chunks_path}")

    rows = load_jsonl(chunks_path)
    raw_polos = Counter(str(r.get("tipo_epistemico") or r.get("polo") or "?").upper() for r in rows)

    normed = []
    n_changed = 0
    for r in rows:
        nr, ch = normalize_row(r)
        normed.append(nr)
        if ch:
            n_changed += 1
    canon_polos = Counter(polo_of(r) for r in normed)
    n_sit = int(canon_polos.get("SITUADO", 0))
    n_heg = int(canon_polos.get("HEGEMONICO", 0))
    n_tec = int(canon_polos.get("TECNICO", 0))
    n_chunks = len(normed)

    meta_old = {}
    if meta_path.exists():
        meta_old = json.loads(meta_path.read_text(encoding="utf-8"))

    faiss_info = check_faiss(l1, n_chunks)

    print("=== RECONCILE index_l1 ===")
    print(f"l1={l1}")
    print(f"jsonl n={n_chunks}")
    print(f"polos crudos:   {dict(raw_polos)}")
    print(f"polos canónicos:{dict(canon_polos)}")
    print(f"filas a normalizar (SIT→SITUADO etc.): {n_changed}")
    print(
        f"meta ACTUAL: n_chunks={meta_old.get('n_chunks')} "
        f"n_sit={meta_old.get('n_sit')} n_heg={meta_old.get('n_heg')} n_tec={meta_old.get('n_tec')}"
    )
    print(f"meta NUEVO:  n_chunks={n_chunks} n_sit={n_sit} n_heg={n_heg} n_tec={n_tec}")
    print(
        f"faiss: ok={faiss_info.get('ok')} ntotal={faiss_info.get('ntotal')} "
        f"dim={faiss_info.get('dim')} {faiss_info.get('error','')}"
    )

    need_meta = (
        meta_old.get("n_chunks") != n_chunks
        or meta_old.get("n_sit") != n_sit
        or meta_old.get("n_heg") != n_heg
        or meta_old.get("n_tec") != n_tec
        or n_changed > 0
    )

    if args.dry_run and not args.apply:
        print("\nDRY-RUN — no se escribió nada.")
        print("Siguiente: --apply   (y --rebuild-faiss SOLO si faiss ok=False)")
        if not faiss_info.get("ok"):
            print("AVISO: FAISS desync → hace falta --apply --rebuild-faiss")
        raise SystemExit(0)

    # --apply
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = l1 / f"_bak_reconcile_{ts}"
    bak.mkdir(exist_ok=True)
    shutil.copy2(chunks_path, bak / "chunks.jsonl")
    if meta_path.exists():
        shutil.copy2(meta_path, bak / "meta.json")
    if (l1 / "faiss.idx").exists() and args.rebuild_faiss:
        shutil.copy2(l1 / "faiss.idx", bak / "faiss.idx")
    print(f"backup → {bak}")

    if n_changed:
        write_jsonl(chunks_path, normed)
        print(f"chunks.jsonl: normalizadas {n_changed} filas")
    else:
        print("chunks.jsonl: sin cambios de polo")

    meta = dict(meta_old)
    meta["n_chunks"] = n_chunks
    meta["n_sit"] = n_sit
    meta["n_heg"] = n_heg
    meta["n_tec"] = n_tec
    meta["reconcile_utc"] = datetime.now(timezone.utc).isoformat()
    meta["reconcile_note"] = "counts from chunks.jsonl; polo canon SITUADO|HEGEMONICO|TECNICO"
    if faiss_info.get("dim") is not None:
        meta["faiss_ntotal"] = faiss_info["ntotal"]
        meta["faiss_dim"] = faiss_info["dim"]
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print("meta.json: regenerado desde chunks")

    if args.rebuild_faiss or not faiss_info.get("ok"):
        if not args.rebuild_faiss and not faiss_info.get("ok"):
            print("ERROR: FAISS desync. Re-ejecuta con --apply --rebuild-faiss")
            raise SystemExit(2)
        print("Invocando rebuild FAISS (puede tardar en CPU)…")
        # delegar al script de rebuild del mismo workspace
        rebuild = Path(__file__).resolve().parent / "tektron_rebuild_faiss_from_chunks.py"
        if not rebuild.exists():
            rebuild = ROOT / "workspace" / "tektron_rebuild_faiss_from_chunks.py"
        import subprocess

        env = os.environ.copy()
        env["CUDA_VISIBLE_DEVICES"] = ""
        rc = subprocess.call(
            [sys.executable, str(rebuild), "--device", "cpu"],
            cwd=str(ROOT),
            env=env,
        )
        if rc != 0:
            raise SystemExit(f"rebuild FAISS falló rc={rc}")
        faiss_info = check_faiss(l1, n_chunks)
        print(f"faiss post-rebuild: {faiss_info}")

    if args.skip_smoke:
        print("smoke IndexL1: skipped")
        return

    print("smoke IndexL1 (como el bridge)…")
    smoke = smoke_index_l1(l1)
    print(smoke)
    if not smoke.get("ok"):
        print(
            "FAIL: IndexL1 no carga. Pega:\n"
            "  sed -n '90,160p' /mnt/tektron/retrieve_l1.py"
        )
        raise SystemExit(3)
    print("OK reconcile — puedes arrancar el bridge UNA vez.")


if __name__ == "__main__":
    main()
