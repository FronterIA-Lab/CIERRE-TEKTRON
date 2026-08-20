#!/usr/bin/env bash
# Diagnóstico rápido post-rebuild FAISS (solo lectura + un retrieve)
# Uso:
#   ssh tektron@192.168.100.84 'bash -s' < tektron_probe_mcc_retrieve.sh
# o copiar a workspace y:
#   bash /mnt/tektron/workspace/tektron_probe_mcc_retrieve.sh
set -euo pipefail
ROOT="${TEKTRON_ROOT:-/mnt/tektron}"
PY="${ROOT}/venv_tektron/bin/python3"
L1="${ROOT}/index_l1"

echo "=== meta / faiss ==="
"$PY" - <<PY
import json
from pathlib import Path
import faiss
l1=Path("$L1")
meta={}
if (l1/"meta.json").exists():
    meta=json.loads((l1/"meta.json").read_text())
idx=faiss.read_index(str(l1/"faiss.idx"))
n_jsonl=sum(1 for line in open(l1/"chunks.jsonl",encoding="utf-8",errors="ignore") if line.strip())
print("meta_keys", sorted(meta.keys())[:40])
for k in ("n_chunks","faiss_ntotal","faiss_dim","faiss_model","model","embedding","dim","embed_model"):
    if k in meta: print(f"  meta[{k}]={meta[k]}")
print(f"faiss ntotal={idx.ntotal} dim={idx.d}")
print(f"jsonl={n_jsonl} sync={idx.ntotal==n_jsonl}")
PY

echo "=== buscar modelo embed en código vivo ==="
grep -RIn -E 'SentenceTransformer|embed_model|MiniLM|mpnet|e5-|768|384' \
  "$ROOT"/*.py "$ROOT"/bridge*.py "$ROOT"/retrieve*.py "$ROOT"/tektron*.py 2>/dev/null \
  | head -40 || true

echo "=== retrieve MCC ==="
curl -sS -m 120 -X POST "http://127.0.0.1:8000/retrieve" \
  -H "Content-Type: application/json" \
  -d '{"query":"¿Qué es el MCC?"}' \
  | "$PY" - <<'PY'
import sys, json
raw=sys.stdin.read()
print(raw[:2500])
try:
    d=json.loads(raw)
except Exception:
    sys.exit(0)
# best-effort shape
for key in ("results","hits","chunks","documents","items"):
    if isinstance(d, dict) and key in d:
        xs=d[key]
        print(f"\n--- {key} n={len(xs) if hasattr(xs,'__len__') else '?'} ---")
        for i,x in enumerate(list(xs)[:5]):
            if isinstance(x, dict):
                fuente=x.get("fuente") or x.get("source") or x.get("doc_id") or ""
                text=(x.get("text") or x.get("contenido") or x.get("chunk") or "")[:200]
                print(f"[{i}] fuente={fuente}")
                print(text.replace("\n"," ")[:200])
            else:
                print(f"[{i}]", str(x)[:200])
        break
PY
