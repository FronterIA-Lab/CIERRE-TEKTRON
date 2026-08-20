#!/usr/bin/env bash
# Restore COMPLETO del trío + ids_*.npy + bm25 desde precuracion.
# El restore anterior omitió ids_sit/heg/tec.npy — causa probable del assert.
set -euo pipefail
ROOT=/mnt/tektron
L1=$ROOT/index_l1
SRC=$ROOT/index_l1_precuracion_20260819
PY=$ROOT/venv_tektron/bin/python3

sudo systemctl stop tektron-bridge.service 2>/dev/null || true
pkill -f tektron_bridge_l1.py 2>/dev/null || true
sleep 1

echo "=== contenido SRC ==="
ls -la "$SRC"

echo "=== copiar TODO el artefacto de índice (no solo chunks/meta/faiss) ==="
for f in chunks.jsonl meta.json faiss.idx bm25.pkl \
         ids_sit.npy ids_heg.npy ids_tec.npy; do
  if [[ -f "$SRC/$f" ]]; then
    cp -a "$SRC/$f" "$L1/$f"
    echo "  OK $f"
  else
    echo "  FALTA en SRC: $f"
  fi
done

echo "=== L1 ahora ==="
ls -la "$L1" | egrep 'chunks|meta|faiss|bm25|ids_'

echo "=== smoke IndexL1 ==="
CUDA_VISIBLE_DEVICES= "$PY" - <<'PY'
import json, os, sys
from pathlib import Path
os.environ["CUDA_VISIBLE_DEVICES"] = ""
sys.path.insert(0, "/mnt/tektron")
import faiss, numpy as np
l1 = Path("/mnt/tektron/index_l1")
n = sum(1 for line in open(l1/"chunks.jsonl", encoding="utf-8", errors="ignore") if line.strip())
meta = json.loads((l1/"meta.json").read_text())
idx = faiss.read_index(str(l1/"faiss.idx"))
print("chunks", n, "faiss", idx.ntotal, "dim", idx.d, "sync", idx.ntotal == n)
print("meta", {k: meta.get(k) for k in ("n_chunks", "n_sit", "n_heg", "n_tec")})
for name in ("ids_sit.npy", "ids_heg.npy", "ids_tec.npy"):
    p = l1 / name
    if p.exists():
        a = np.load(p)
        print(name, "shape", a.shape, "len", len(a))
    else:
        print(name, "MISSING")
from retrieve_l1 import IndexL1
ix = IndexL1(str(l1), device="cpu")
print("IndexL1 OK set_sit=", len(ix.set_sit), "meta_n_sit=", ix.meta.get("n_sit"))
PY

echo "Si IndexL1 OK, arranca:"
echo "  cd /mnt/tektron && nohup ./venv_tektron/bin/python3 -u tektron_bridge_l1.py >> workspace/bridge_l1.log 2>&1 &"
