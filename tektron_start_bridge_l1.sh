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

# Preferir nohup: systemd a menudo "restart OK" vía polkit pero el unit
# queda failed/inactive y :8000 no escucha.
start_nohup() {
  echo "Arranque directo (nohup)…"
  nohup "$PY" -u "$APP" >>"$LOG" 2>&1 &
  echo "PID $!  log=$LOG"
}

if [[ "${TEKTRON_USE_SYSTEMD:-0}" == "1" ]] && systemctl restart tektron-bridge.service 2>/dev/null; then
  echo "OK: systemctl restart tektron-bridge.service"
else
  start_nohup
fi

LISTEN=0
for i in 1 2 3 4 5 6 7 8 9 10 12 15 20; do
  sleep 1
  if ss -ltn 2>/dev/null | grep -q ':8000'; then
    echo "LISTEN :8000 OK (t=${i}s)"
    LISTEN=1
    break
  fi
  echo "esperando :8000… ($i)"
done

if [[ "$LISTEN" != "1" ]]; then
  echo "WARN: :8000 no escucha tras restart. Forzando nohup…"
  # si systemd dejó un unit fallido, igual intentamos proceso directo
  start_nohup
  for i in 1 2 3 4 5 6 7 8 9 10 15 20 30; do
    sleep 1
    if ss -ltn 2>/dev/null | grep -q ':8000'; then
      echo "LISTEN :8000 OK via nohup (t=${i}s)"
      LISTEN=1
      break
    fi
    echo "esperando :8000 (nohup)… ($i)"
  done
fi

if [[ "$LISTEN" != "1" ]]; then
  echo "FAIL: :8000 sigue abajo. Diagnóstico:"
  systemctl status tektron-bridge.service --no-pager -l 2>/dev/null | head -40 || true
  echo "---- tail log ----"
  tail -n 80 "$LOG" 2>/dev/null || true
  echo "---- journal ----"
  journalctl -u tektron-bridge.service -n 40 --no-pager 2>/dev/null || true
  exit 1
fi

echo "=== probe MCC ==="
curl -sS -m 90 -X POST http://127.0.0.1:8000/retrieve \
  -H 'Content-Type: application/json' \
  -d '{"query":"¿Qué es el MCC?"}'
echo ""
