#!/usr/bin/env python3
"""
Diagnóstico: ¿los chunks MCC están en jsonl+FAISS y el bridge los ve?

Uso en Jetson:
  CUDA_VISIBLE_DEVICES= /mnt/tektron/venv_tektron/bin/python3 \\
    /mnt/tektron/workspace/tektron_diagnose_retrieve_mcc.py

No modifica índices. Si FAISS local encuentra MCC pero /retrieve abstiene,
reinicia el bridge (índice viejo en RAM).
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ.get("TEKTRON_ROOT", "/mnt/tektron"))
L1 = ROOT / "index_l1"
QUERY = "¿Qué es el MCC?"
MODEL = "sentence-transformers/paraphrase-multilingual-mpnet-base-v2"


def main() -> None:
    os.environ["CUDA_VISIBLE_DEVICES"] = ""
    chunks_path = L1 / "chunks.jsonl"
    faiss_path = L1 / "faiss.idx"
    rows = []
    with chunks_path.open(encoding="utf-8", errors="ignore") as f:
        for line in f:
            if line.strip():
                rows.append(json.loads(line))
    print(f"jsonl n={len(rows)}")

    pat = re.compile(r"mcc|calibraci[oó]n contextual|17728016|21500800", re.I)
    hits = []
    for i, r in enumerate(rows):
        text = str(r.get("text") or r.get("contenido") or "")
        fuente = str(r.get("fuente") or "")
        if pat.search(text) or pat.search(fuente) or "zenodo_17728016" in fuente or "zenodo_21500800" in fuente:
            hits.append((i, fuente, r.get("polo") or r.get("tipo_epistemico"), text[:120].replace("\n", " ")))
    print(f"chunks MCC-ish en jsonl: {len(hits)}")
    for i, fuente, polo, snip in hits[:8]:
        print(f"  [{i}] polo={polo} fuente={fuente}")
        print(f"       {snip}")

    import faiss
    import numpy as np
    from sentence_transformers import SentenceTransformer

    idx = faiss.read_index(str(faiss_path))
    print(f"faiss ntotal={idx.ntotal} dim={idx.d} sync={idx.ntotal == len(rows)}")
    if idx.ntotal != len(rows):
        print("ERROR: desfase faiss/jsonl — no seguir")
        sys.exit(2)
    if idx.d != 768:
        print(f"AVISO: dim={idx.d} (bridge mpnet espera 768)")

    print(f"embed query con {MODEL} (cpu)…")
    model = SentenceTransformer(MODEL, device="cpu")
    q = model.encode([QUERY], normalize_embeddings=True, convert_to_numpy=True).astype("float32")
    scores, ids = idx.search(q, 8)
    print(f"\nTop-8 FAISS para: {QUERY!r}")
    for rank, (sc, i) in enumerate(zip(scores[0], ids[0])):
        if i < 0:
            continue
        r = rows[int(i)]
        fuente = r.get("fuente")
        text = (r.get("text") or "")[:160].replace("\n", " ")
        print(f"  #{rank} score={sc:.4f} i={i} fuente={fuente}")
        print(f"      {text}")

    # HTTP retrieve
    try:
        import urllib.request

        req = urllib.request.Request(
            "http://127.0.0.1:8000/retrieve",
            data=json.dumps({"query": QUERY}).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = resp.read().decode()
        print("\n/retrieve raw:", body[:800])
        d = json.loads(body)
        print("decision=", d.get("decision"), "fuentes=", d.get("fuentes"), "n_sit=", d.get("n_sit"), "n_heg=", d.get("n_heg"))
        if d.get("decision") == "ABSTENER" and len(hits) > 0:
            print(
                "\nCONCLUSIÓN: hay MCC en disco/FAISS pero el bridge abstiene.\n"
                "→ Reinicia el proceso del bridge :8000 para recargar faiss.idx."
            )
    except Exception as e:
        print(f"\n/retrieve FAIL: {e}")
        print("→ Bridge caído o no escucha en :8000")


if __name__ == "__main__":
    main()
