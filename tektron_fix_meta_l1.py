#!/usr/bin/env python3
"""
Repara meta.json de index_l1 para que n_sit/n_heg/n_tec coincidan con chunks.jsonl.

Causa típica del crash del bridge:
  retrieve_l1.py: assert len(self.set_sit) == self.meta["n_sit"]  → AssertionError

También normaliza polos del andamiaje (SIT→SITUADO, HEG→HEGEMONICO) para alinearse
con el corpus L1 histórico.

Uso en Jetson:
  /mnt/tektron/venv_tektron/bin/python3 /mnt/tektron/workspace/tektron_fix_meta_l1.py
  /mnt/tektron/venv_tektron/bin/python3 /mnt/tektron/workspace/tektron_fix_meta_l1.py --apply
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
import os

ROOT = Path(os.environ.get("TEKTRON_ROOT", "/mnt/tektron"))
L1 = Path(os.environ.get("TEKTRON_INDEX_L1", str(ROOT / "index_l1")))


def polo_of(row: dict) -> str:
    raw = (
        row.get("tipo_epistemico")
        or row.get("polo")
        or row.get("tipo")
        or ""
    )
    s = str(raw).strip().upper()
    if s in ("SIT", "SITUADO", "SITUADA", "S"):
        return "SITUADO"
    if s in ("HEG", "HEGEMONICO", "HEGEMÓNICO", "HEGEMONICA", "HEGEMÓNICA", "H"):
        return "HEGEMONICO"
    if s in ("TEC", "TECNICO", "TÉCNICO", "TECH", "T"):
        return "TECNICO"
    return s or "?"


def normalize_row(row: dict) -> dict:
    p = polo_of(row)
    if p == "SITUADO":
        row["tipo_epistemico"] = "SITUADO"
        row["polo"] = "SITUADO"
    elif p == "HEGEMONICO":
        row["tipo_epistemico"] = "HEGEMONICO"
        row["polo"] = "HEGEMONICO"
    elif p == "TECNICO":
        row["tipo_epistemico"] = "TECNICO"
        row["polo"] = "TECNICO"
    return row


def peek_retrieve_l1() -> None:
    path = ROOT / "retrieve_l1.py"
    if not path.exists():
        print(f"(no hay {path})")
        return
    text = path.read_text(encoding="utf-8", errors="ignore")
    print("=== retrieve_l1.py: líneas con set_sit / n_sit / assert ===")
    for i, line in enumerate(text.splitlines(), 1):
        if re.search(r"set_sit|n_sit|assert.*sit|tipo_epistemico|SITUADO", line):
            if 80 <= i <= 180 or "assert" in line or "set_sit" in line:
                print(f"{i:4d}: {line.rstrip()}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="escribir chunks+meta (default: dry-run)")
    ap.add_argument("--l1", type=Path, default=L1)
    args = ap.parse_args()
    l1 = args.l1
    chunks_path = l1 / "chunks.jsonl"
    meta_path = l1 / "meta.json"
    if not chunks_path.exists():
        raise SystemExit(f"no existe {chunks_path}")

    peek_retrieve_l1()

    rows = []
    with chunks_path.open(encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.strip():
                rows.append(json.loads(line))

    before = Counter(polo_of(r) for r in rows)
    normed = [normalize_row(dict(r)) for r in rows]
    after = Counter(polo_of(r) for r in normed)

    meta = {}
    if meta_path.exists():
        meta = json.loads(meta_path.read_text(encoding="utf-8"))

    n_sit = after.get("SITUADO", 0)
    n_heg = after.get("HEGEMONICO", 0)
    n_tec = after.get("TECNICO", 0)
    n_chunks = len(normed)

    print("\n=== conteos polo (tras normalizar SIT→SITUADO) ===")
    for k, v in after.most_common():
        print(f"  {k}: {v}")
    print(f"\nmeta ACTUAL: n_chunks={meta.get('n_chunks')} n_sit={meta.get('n_sit')} "
          f"n_heg={meta.get('n_heg')} n_tec={meta.get('n_tec')}")
    print(f"meta NUEVO:  n_chunks={n_chunks} n_sit={n_sit} n_heg={n_heg} n_tec={n_tec}")
    print(f"mismatch n_sit? meta={meta.get('n_sit')} vs chunks_sit={n_sit}")

    if before != after:
        print("polos crudos distintos de normalizados:", dict(before), "→", dict(after))

    if not args.apply:
        print("\nDRY-RUN. Para aplicar: añade --apply")
        print("Luego: sudo systemctl stop tektron-bridge.service; arrancar nohup / systemctl start")
        return

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak = l1 / f"_bak_meta_fix_{ts}"
    bak.mkdir(exist_ok=True)
    shutil.copy2(chunks_path, bak / "chunks.jsonl")
    if meta_path.exists():
        shutil.copy2(meta_path, bak / "meta.json")
    print(f"backup → {bak}")

    tmp = chunks_path.with_suffix(".jsonl.tmp")
    with tmp.open("w", encoding="utf-8") as f:
        for r in normed:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    tmp.replace(chunks_path)

    meta["n_chunks"] = n_chunks
    meta["n_sit"] = n_sit
    meta["n_heg"] = n_heg
    meta["n_tec"] = n_tec
    meta["meta_fix_utc"] = datetime.now(timezone.utc).isoformat()
    meta["meta_fix_note"] = "recomputed from chunks.jsonl; SIT/HEG normalized"
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print("OK: chunks.jsonl + meta.json actualizados")

    # smoke: intentar IndexL1 si está importable
    try:
        import sys

        sys.path.insert(0, str(ROOT))
        from retrieve_l1 import IndexL1  # type: ignore

        idx = IndexL1(str(l1), device="cpu")
        print(f"IndexL1 OK  set_sit={len(idx.set_sit)} meta_n_sit={idx.meta.get('n_sit')}")
    except Exception as e:
        print(f"IndexL1 smoke: {type(e).__name__}: {e}")
        print("(si sigue AssertionError, pega líneas de retrieve_l1 con set_sit)")


if __name__ == "__main__":
    main()
