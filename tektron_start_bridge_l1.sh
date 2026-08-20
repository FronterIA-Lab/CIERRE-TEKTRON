#!/usr/bin/env bash
# Relanza tektron_bridge_l1.py en :8000 (sin sudo).
# Uso:
#   ssh -t tektron@192.168.100.84 'bash /mnt/tektron/workspace/tektron_start_bridge_l1.sh'
#   # o con systemd (pide password):
#   ssh -t tektron@192.168.100.84 'sudo systemctl restart tektron-bridge.service'
set -euo pipefail
ROOT="${TEKTRON_ROOT:-/mnt/tektron}"
PY="${ROOT}/venv_tektron/bin/python3"
APP="${ROOT}/tektron_bridge_l1.py"
LOG="${ROOT}/workspace/bridge_l1.log"
cd "$ROOT"

if [[ ! -f "$APP" ]]; then
  echo "ERROR: no está $APP"
  exit 1
fi

# matar listener viejo en 8000 si existe
PID=$(ss -ltnp 2>/dev/null | sed -n 's/.*:8000.*pid=\([0-9]*\).*/\1/p' | head -1 || true)
if [[ -n "${PID:-}" ]]; then
  echo "Matando PID $PID en :8000"
  kill -TERM "$PID" 2>/dev/null || true
  sleep 2
fi

# si systemd puede sin password, úsalo
if systemctl restart tektron-bridge.service 2>/dev/null; then
  echo "OK: systemctl restart tektron-bridge.service"
else
  echo "Arranque directo (nohup)…"
  nohup "$PY" -u "$APP" >>"$LOG" 2>&1 &
  echo "PID $!  log=$LOG"
fi

for i in 1 2 3 4 5 6 7 8 9 10; do
  sleep 1
  if ss -ltn 2>/dev/null | grep -q ':8000'; then
    echo "LISTEN :8000 OK (t=${i}s)"
    break
  fi
  echo "esperando :8000… ($i)"
done

echo "=== probe MCC ==="
curl -sS -m 90 -X POST http://127.0.0.1:8000/retrieve \
  -H 'Content-Type: application/json' \
  -d '{"query":"¿Qué es el MCC?"}'
echo ""
