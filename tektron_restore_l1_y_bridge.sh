#!/usr/bin/env bash
# Restore limpio de index_l1 — una sola acción.
# Elige el snapshot que tenga chunks.jsonl + meta.json + faiss.idx,
# respalda el L1 roto, restaura, smoke IndexL1, arranca bridge si pasa.
#
# Uso en Jetson:
#   bash /mnt/tektron/workspace/tektron_restore_l1_y_bridge.sh
set -euo pipefail

ROOT="${TEKTRON_ROOT:-/mnt/tektron}"
L1="$ROOT/index_l1"
PY="$ROOT/venv_tektron/bin/python3"
APP="$ROOT/tektron_bridge_l1.py"
LOG="$ROOT/workspace/bridge_l1.log"

CANDIDATES=(
  "$ROOT/_snapshots/pre_correccion_l1_20260819_190207"
  "$ROOT/index_l1_precuracion_20260819"
  "$L1/_bak_reconcile_20260819_220856"
)

echo "=== 1) stop crash-loop ==="
sudo systemctl stop tektron-bridge.service 2>/dev/null || true
pkill -f tektron_bridge_l1.py 2>/dev/null || true
sleep 1

echo "=== 2) elegir snapshot (debe tener chunks+meta+faiss) ==="
SRC=""
for d in "${CANDIDATES[@]}"; do
  echo "-- $d"
  if [[ ! -d "$d" ]]; then
    echo "   (no existe)"
    continue
  fi
  ls -la "$d" | sed 's/^/   /'
  if [[ -f "$d/chunks.jsonl" && -f "$d/meta.json" && -f "$d/faiss.idx" ]]; then
    SRC="$d"
    echo "   → COMPLETO (candidato elegido)"
    break
  else
    echo "   → incompleto (falta faiss o meta o chunks)"
  fi
done

if [[ -z "$SRC" ]]; then
  echo "ERROR: ningún snapshot tiene el trío completo."
  echo "Si pre_correccion solo tiene chunks+meta, usaremos precuracion a mano:"
  echo "  ls -la $ROOT/index_l1_precuracion_20260819"
  exit 1
fi

echo "=== 3) backup del L1 roto actual ==="
TS=$(date +%Y%m%d_%H%M%S)
BROKEN="$ROOT/_snapshots/l1_roto_pre_restore_$TS"
mkdir -p "$BROKEN"
for f in chunks.jsonl meta.json faiss.idx bm25.pkl bm25_index.pkl; do
  [[ -f "$L1/$f" ]] && cp -a "$L1/$f" "$BROKEN/"
done
echo "roto guardado en $BROKEN"

echo "=== 4) restore desde $SRC ==="
cp -a "$SRC/chunks.jsonl" "$L1/chunks.jsonl"
cp -a "$SRC/meta.json" "$L1/meta.json"
cp -a "$SRC/faiss.idx" "$L1/faiss.idx"
[[ -f "$SRC/bm25.pkl" ]] && cp -a "$SRC/bm25.pkl" "$L1/bm25.pkl" || true
[[ -f "$SRC/bm25_index.pkl" ]] && cp -a "$SRC/bm25_index.pkl" "$L1/bm25_index.pkl" || true

echo "=== 5) smoke IndexL1 (sin bridge) ==="
CUDA_VISIBLE_DEVICES= "$PY" - <<PY
import json, os, sys
from pathlib import Path
os.environ["CUDA_VISIBLE_DEVICES"] = ""
sys.path.insert(0, "$ROOT")
import faiss
l1 = Path("$L1")
n = sum(1 for line in open(l1/"chunks.jsonl", encoding="utf-8", errors="ignore") if line.strip())
meta = json.loads((l1/"meta.json").read_text())
idx = faiss.read_index(str(l1/"faiss.idx"))
print("chunks", n, "faiss", idx.ntotal, "dim", idx.d, "sync", idx.ntotal == n)
print("meta", {k: meta.get(k) for k in ("n_chunks", "n_sit", "n_heg", "n_tec")})
from retrieve_l1 import IndexL1
ix = IndexL1(str(l1), device="cpu")
print("IndexL1 OK set_sit=", len(ix.set_sit), "meta_n_sit=", ix.meta.get("n_sit"))
PY

echo "=== 6) arrancar bridge UNA vez (nohup) ==="
cd "$ROOT"
nohup "$PY" -u "$APP" >>"$LOG" 2>&1 &
echo "PID $!"
for i in 1 2 3 4 5 6 7 8 9 10 12 15 20; do
  sleep 1
  if ss -ltn 2>/dev/null | grep -q ':8000'; then
    echo "LISTEN :8000 OK (t=${i}s)"
    break
  fi
  echo "esperando :8000… ($i)"
done

echo "=== 7) probe MCC ==="
curl -sS -m 90 -X POST http://127.0.0.1:8000/retrieve \
  -H 'Content-Type: application/json' \
  -d '{"query":"¿Qué es el MCC?"}' || echo "curl fail"
echo ""
echo "DONE. Si IndexL1 OK y :8000 escucha, el bridge ya no está roto."
echo "Andamiaje MCC se reintroduce DESPUÉS, con construir_index_curado — no ahora."
