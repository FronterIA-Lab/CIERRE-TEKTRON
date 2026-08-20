#!/usr/bin/env python3
"""
Reconstruir FAISS (y BM25 si hay API) desde index_l1/chunks.jsonl.

Contexto TEKTRON 2026-08-19:
  construir_index_curado.py ABORTA si faiss.ntotal != len(jsonl).
  Tras expulsar 54 chunks y añadir 687 de andamiaje, el índice denso
  quedó desfasado → retrieve no refleja el Corpus Base.

Uso en Jetson:
  /mnt/tektron/venv_tektron/bin/python3 /mnt/tektron/workspace/tektron_rebuild_faiss_from_chunks.py

Objetivo: alinear faiss.idx con chunks.jsonl (dim 768 MiniLM) para que
los probes MCC / Árboles de Espejos usen el andamiaje recién indexado.
"""
from __future__ import annotations

import argparse
import json
import os
import pickle
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path


def die(msg: str, code: int = 1) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    raise SystemExit(code)


def load_chunks(path: Path) -> list[dict]:
    rows = []
    with path.open(encoding="utf-8", errors="ignore") as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception as e:
                die(f"jsonl línea {i}: {e}")
    return rows


def text_of(d: dict) -> str:
    for k in ("text", "contenido", "chunk", "body"):
        if d.get(k):
            return str(d[k])
    return ""


def rebuild_bm25(texts: list[str], out_path: Path) -> str:
    try:
        from rank_bm25 import BM25Okapi
    except Exception as e:
        return f"skip_bm25:{e}"
    tokenized = [t.lower().split() for t in texts]
    bm25 = BM25Okapi(tokenized)
    with out_path.open("wb") as f:
        pickle.dump({"bm25": bm25, "n": len(texts)}, f)
    return f"wrote {out_path} n={len(texts)}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="/mnt/tektron")
    ap.add_argument("--l1", default="")
    ap.add_argument(
        "--model",
        default=os.environ.get(
            "TEKTRON_EMBED_MODEL",
            "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        ),
    )
    ap.add_argument("--batch-size", type=int, default=16)
    ap.add_argument(
        "--device",
        default=os.environ.get("TEKTRON_EMBED_DEVICE", "cpu"),
        help="cpu|cuda — en Jetson usa cpu si la GPU está ocupada (llama/bridge)",
    )
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    root = Path(args.root)
    l1 = Path(args.l1) if args.l1 else root / "index_l1"
    chunks_path = l1 / "chunks.jsonl"
    faiss_path = l1 / "faiss.idx"

    if "memoria_usuario" in str(l1):
        die("ruta memoria_usuario fuera de alcance", 3)
    if not chunks_path.exists():
        die(f"no existe {chunks_path}")

    rows = load_chunks(chunks_path)
    texts = [text_of(r) for r in rows]
    empty = sum(1 for t in texts if not t.strip())
    print(f"chunks={len(rows)} empty_text={empty} model={args.model}")

    if args.dry_run:
        if faiss_path.exists():
            try:
                import faiss  # type: ignore

                idx = faiss.read_index(str(faiss_path))
                print(f"faiss_current ntotal={idx.ntotal} dim={idx.d}")
                print(f"mismatch={idx.ntotal != len(rows)}")
            except Exception as e:
                print(f"faiss_read_fail: {e}")
        print("DRY-RUN: no write")
        return

    try:
        import faiss  # type: ignore
        import numpy as np
        from sentence_transformers import SentenceTransformer
    except Exception as e:
        die(f"deps FAISS/ST: {e}")

    # backup
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    bak_dir = l1 / f"_bak_faiss_{ts}"
    bak_dir.mkdir(exist_ok=True)
    if faiss_path.exists():
        shutil.copy2(faiss_path, bak_dir / "faiss.idx")
    for name in ("bm25.pkl", "bm25_index.pkl", "meta.json"):
        p = l1 / name
        if p.exists():
            shutil.copy2(p, bak_dir / name)
    print(f"backup → {bak_dir}")

    print("cargando modelo…")
    model = SentenceTransformer(args.model)
    print("embedding…")
    emb = model.encode(
        texts,
        batch_size=args.batch_size,
        show_progress_bar=True,
        normalize_embeddings=True,
        convert_to_numpy=True,
    )
    emb = np.asarray(emb, dtype="float32")
    if emb.ndim != 2 or emb.shape[0] != len(rows):
        die(f"bad emb shape {emb.shape} vs n={len(rows)}")

    index = faiss.IndexFlatIP(emb.shape[1])
    index.add(emb)
    tmp = faiss_path.with_suffix(".idx.tmp")
    faiss.write_index(index, str(tmp))
    tmp.replace(faiss_path)
    print(f"faiss OK ntotal={index.ntotal} dim={index.d} → {faiss_path}")

    # BM25 best-effort
    bm25_out = l1 / "bm25.pkl"
    print(rebuild_bm25(texts, bm25_out))

    meta_path = l1 / "meta.json"
    meta = {}
    if meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except Exception:
            meta = {}
    meta["n_chunks"] = len(rows)
    meta["faiss_ntotal"] = int(index.ntotal)
    meta["faiss_dim"] = int(index.d)
    meta["faiss_rebuild_utc"] = datetime.now(timezone.utc).isoformat()
    meta["faiss_model"] = args.model
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    # sanity
    idx2 = faiss.read_index(str(faiss_path))
    if idx2.ntotal != len(rows):
        die(f"post-check fail faiss={idx2.ntotal} jsonl={len(rows)}")
    print("SYNC OK: faiss.ntotal == len(chunks.jsonl)")
    print("Siguiente: reiniciar bridge :8000 si hace falta; probe retrieve '¿Qué es el MCC?'")


if __name__ == "__main__":
    main()
