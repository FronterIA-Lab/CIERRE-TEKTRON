#!/usr/bin/env bash
# Reinicia el bridge L1 de TEKTRON (recarga faiss.idx en RAM).
# Uso:
#   ssh tektron@192.168.100.84 'bash /mnt/tektron/workspace/tektron_restart_bridge.sh'
set -euo pipefail
ROOT="${TEKTRON_ROOT:-/mnt/tektron}"

echo "=== procesos :8000 / retrieve / bridge ==="
ss -ltnp 2>/dev/null | grep -E ':8000|:8001' || netstat -ltnp 2>/dev/null | grep -E ':8000|:8001' || true
ps aux | grep -E 'retrieve_l1|bridge|tektron_backend|uvicorn|8000' | grep -v grep || true

echo ""
echo "Intento reinicio (varios mecanismos; ignora los que fallen)…"

# systemd units comunes
for u in tektron-bridge tektron_bridge bridge-l1 tektron-retrieve tektron; do
  if systemctl list-units --type=service --all 2>/dev/null | grep -q "$u"; then
    echo "systemctl restart $u"
    sudo systemctl restart "$u" && echo "OK $u" || true
  fi
done

# si hay script de arranque en /mnt/tektron
if [[ -x "$ROOT/restart_bridge.sh" ]]; then
  bash "$ROOT/restart_bridge.sh" || true
fi

# matar solo retrieve_l1 en 8000 (último recurso; el usuario debe tener un watcher)
PID=$(ss -ltnp 2>/dev/null | awk '/:8000/ {print}' | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -1)
if [[ -n "${PID:-}" ]]; then
  echo "PID en :8000 = $PID"
  echo "Si el bridge no recargó solo, reinícialo a mano con tu comando habitual."
  echo "Ejemplo (NO ejecuto kill automático): kill $PID && nohup … &"
fi

sleep 1
echo ""
echo "=== health ==="
curl -sS -m 5 http://127.0.0.1:8000/docs -o /dev/null -w "8000 docs http=%{http_code}\n" || echo "8000 no responde"
curl -sS -m 5 http://127.0.0.1:8001/docs -o /dev/null -w "8001 docs http=%{http_code}\n" || echo "8001 no responde"

echo ""
echo "Luego:"
echo "  bash /mnt/tektron/workspace/tektron_diagnose_retrieve_mcc.py"
echo "  bash /mnt/tektron/workspace/tektron_probe_mcc_retrieve.sh"
