#!/usr/bin/env python3
"""
Indexar andamiaje propio (papers arquitecta) en index_l1.

Arquitectura TEKTRON:
  Corpus Base (Andamiaje) → index_l1
  Los markdown bajo 00_Core/markdown/zenodo/ SON el sistema, no memoria_usuario.

Prioridad:
  1) Núcleo MCC: 17728016, 21500800
  2) Satélites: 19932561, 18800211
  3) Resto

Uso en Jetson:
  /mnt/tektron/venv_tektron/bin/python3 tektron_indexar_andamiaje_l1.py \\
      --root /mnt/tektron

Nunca escribe en memoria_usuario*.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

MCC_CORE = ("17728016", "21500800")
MCC_SAT = ("19932561", "18800211")

ROLE_BY_ID = {
    "17728016": "NUCLEO_MCC",
    "21500800": "NUCLEO_MCC",
    "19932561": "SATELITE_MCC",
    "18800211": "SATELITE_MCC",
}


def die(msg: str, code: int = 1) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


def assert_safe_path(p: Path) -> None:
    s = str(p).replace("\\", "/").lower()
    if "memoria_usuario" in s:
        die(f"ruta prohibida (memoria_usuario fuera de alcance): {p}", 3)


def strip_frontmatter(md: str) -> tuple[dict, str]:
    meta: dict = {}
    if md.startswith("---"):
        end = md.find("\n---", 3)
        if end != -1:
            block = md[3:end].strip()
            body = md[end + 4 :].lstrip("\n")
            for line in block.splitlines():
                if ":" in line:
                    k, v = line.split(":", 1)
                    meta[k.strip()] = v.strip().strip('"').strip("'")
            return meta, body
    return meta, md


def chunk_text(text: str, size: int = 900, overlap: int = 120) -> list[str]:
    text = re.sub(r"<!-- page \d+ -->\n?", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    if not text:
        return []
    # prefer paragraph breaks
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    chunks: list[str] = []
    buf = ""
    for p in paras:
        if len(buf) + len(p) + 2 <= size:
            buf = f"{buf}\n\n{p}".strip() if buf else p
        else:
            if buf:
                chunks.append(buf)
            if len(p) <= size:
                buf = p
            else:
                # hard split long paragraph
                start = 0
                while start < len(p):
                    end = min(len(p), start + size)
                    chunks.append(p[start:end])
                    start = max(end - overlap, end) if end < len(p) else end
                buf = ""
    if buf:
        chunks.append(buf)
    # add overlap windows for very short last pieces already handled
    return [c for c in chunks if len(c.strip()) > 40]


def priority_key(rid: str) -> tuple[int, str]:
    if rid in MCC_CORE:
        return (0, rid)
    if rid in MCC_SAT:
        return (1, rid)
    return (2, rid)


def load_existing_fuentes(chunks_path: Path) -> set[str]:
    fuentes: set[str] = set()
    if not chunks_path.exists():
        return fuentes
    with chunks_path.open(encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            for k in ("fuente", "source", "doc_id", "canon_id"):
                if d.get(k):
                    fuentes.add(str(d[k]))
    return fuentes


def try_rebuild_faiss(root: Path, l1: Path, new_texts: list[str], dry: bool) -> dict:
    """Prefer full rebuild helper; avoid append-on-desynced index."""
    info: dict = {"faiss": "skipped"}
    if dry:
        return info
    rebuild = root / "workspace" / "tektron_rebuild_faiss_from_chunks.py"
    if not rebuild.exists():
        # same dir as this script
        rebuild = Path(__file__).resolve().parent / "tektron_rebuild_faiss_from_chunks.py"
    if rebuild.exists():
        import subprocess

        r = subprocess.run(
            [sys.executable, str(rebuild), "--root", str(root)],
            cwd=str(root),
            capture_output=True,
            text=True,
        )
        info["faiss"] = "full_rebuild"
        info["returncode"] = r.returncode
        info["stdout_tail"] = (r.stdout or "")[-2500:]
        info["stderr_tail"] = (r.stderr or "")[-2500:]
        print(r.stdout or "")
        if r.stderr:
            print(r.stderr, file=sys.stderr)
        return info

    constructor = root / "construir_index_curado.py"
    if constructor.exists():
        import subprocess

        r = subprocess.run(
            [sys.executable, str(constructor), "--from-chunks", str(l1 / "chunks.jsonl"), "--out", str(l1)],
            cwd=str(root),
            capture_output=True,
            text=True,
        )
        info["faiss"] = "construir_index_curado"
        info["returncode"] = r.returncode
        info["stdout_tail"] = (r.stdout or "")[-2000:]
        info["stderr_tail"] = (r.stderr or "")[-2000:]
        return info

    info["faiss"] = "unavailable"
    info["hint"] = "Colocar tektron_rebuild_faiss_from_chunks.py en workspace/"
    return info


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="/mnt/tektron")
    ap.add_argument("--core", default="")
    ap.add_argument("--out-report", default="")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--chunk-size", type=int, default=900)
    args = ap.parse_args()

    root = Path(args.root)
    core = Path(args.core) if args.core else root / "corpus" / "Corpus_Tektron_F12" / "00_Core"
    l1 = root / "index_l1"
    md_root = core / "markdown" / "zenodo"
    chunks_path = l1 / "chunks.jsonl"

    for p in (root, core, l1, md_root, chunks_path):
        assert_safe_path(p)

    if not md_root.is_dir():
        die(f"no existe markdown andamiaje: {md_root}")

    existing = load_existing_fuentes(chunks_path)
    md_files = sorted(md_root.rglob("*.md"), key=lambda p: priority_key(p.parent.name))
    report = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "core": str(core),
        "l1": str(l1),
        "dry_run": args.dry_run,
        "docs": [],
        "added_chunks": 0,
        "skipped_docs": 0,
    }

    new_records: list[dict] = []
    new_texts: list[str] = []

    for md in md_files:
        rid = md.parent.name
        meta, body = strip_frontmatter(md.read_text(encoding="utf-8", errors="ignore"))
        title = meta.get("title") or rid
        doi = meta.get("doi") or f"10.5281/zenodo.{rid}"
        role = meta.get("role") or ROLE_BY_ID.get(rid, "TEKTRON")
        fuente = f"zenodo_{rid}"
        # skip if already present
        if fuente in existing or any(rid in f for f in existing):
            report["skipped_docs"] += 1
            report["docs"].append({"id": rid, "status": "ALREADY_IN_L1", "fuente": fuente})
            continue

        pieces = chunk_text(body, size=args.chunk_size)
        doc_info = {
            "id": rid,
            "doi": doi,
            "title": title,
            "role": role,
            "n_chunks": len(pieces),
            "status": "QUEUED" if args.dry_run else "INDEXED",
        }
        for i, piece in enumerate(pieces):
            cid = hashlib.sha256(f"{fuente}:{i}:{piece[:80]}".encode()).hexdigest()[:16]
            rec = {
                "id": cid,
                "text": piece,
                "fuente": fuente,
                "titulo": title,
                "doi": doi,
                "zenodo_record": rid,
                "role": role,
                "tipo_epistemico": "SITUADO",
                "polo": "SITUADO",
                "granero": "00_Core",
                "canon_id": "00_Core",
                "chunk_ix": i,
                "sha256": hashlib.sha256(piece.encode()).hexdigest(),
                "origen": "andamiaje_propio_zenodo",
            }
            new_records.append(rec)
            new_texts.append(piece)
        report["docs"].append(doc_info)
        report["added_chunks"] += len(pieces)
        print(f"{role:12} {rid} chunks={len(pieces)}  {title[:60]}")

    if args.dry_run:
        print(f"DRY-RUN would add {len(new_records)} chunks from {len(report['docs'])} docs")
    else:
        l1.mkdir(parents=True, exist_ok=True)
        if chunks_path.exists():
            bak = l1 / f"chunks.jsonl.bak_andamiaje_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            shutil.copy2(chunks_path, bak)
            report["backup"] = str(bak)
        with chunks_path.open("a", encoding="utf-8") as f:
            for rec in new_records:
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")

        # update meta if present
        meta_path = l1 / "meta.json"
        meta = {}
        if meta_path.exists():
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
            except Exception:
                meta = {}
        n_total = sum(1 for _ in chunks_path.open(encoding="utf-8", errors="ignore") if _.strip())
        meta["n_chunks"] = n_total
        meta["n_sit"] = int(meta.get("n_sit") or 0) + len(new_records)
        meta["andamiaje_propio_utc"] = report["ts"]
        meta["andamiaje_propio_added"] = len(new_records)
        meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

        report["faiss"] = try_rebuild_faiss(root, l1, new_texts, dry=False)
        print(f"added_chunks={len(new_records)} total_chunks≈{n_total} faiss={report['faiss'].get('faiss')}")

    if args.out_report:
        Path(args.out_report).write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    else:
        print(json.dumps({k: report[k] for k in ("added_chunks", "skipped_docs", "faiss") if k in report}, indent=2))


if __name__ == "__main__":
    main()
