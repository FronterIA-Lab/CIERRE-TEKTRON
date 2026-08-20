#!/usr/bin/env bash
# Recarga el bridge L1 (:8000) para que lea el faiss.idx nuevo.
# Uso:
#   ssh tektron@192.168.100.84 'bash /mnt/tektron/workspace/tektron_reload_bridge_l1.sh'
set -euo pipefail
ROOT="${TEKTRON_ROOT:-/mnt/tektron}"
cd "$ROOT"

echo "=== quién escucha :8000 / :8001 ==="
if command -v ss >/dev/null; then
  ss -ltnp | grep -E ':8000|:8001' || true
else
  netstat -ltnp 2>/dev/null | grep -E ':8000|:8001' || true
fi
echo ""
echo "=== candidatos de proceso ==="
ps aux | grep -E 'retrieve_l1|uvicorn|tektron_backend|bridge' | grep -v grep || true
echo ""

# Preferir systemd si existe
restarted=0
for u in $(systemctl list-units --type=service --all --no-legend 2>/dev/null | awk '{print $1}' | grep -iE 'tektron|bridge|retrieve' || true); do
  echo "systemctl restart $u"
  if sudo systemctl restart "$u"; then
    echo "OK restarted $u"
    restarted=1
  fi
done

if [[ "$restarted" -eq 0 ]]; then
  echo "No hay unit systemd clara."
  echo "Busca el arranque habitual, p.ej. en screen/tmux o nohup."
  echo ""
  echo "Opción A — si usas un script conocido:"
  echo "  ls $ROOT/*bridge* $ROOT/*retrieve* $ROOT/start* 2>/dev/null"
  echo ""
  echo "Opción B — reinicio manual típico (ajusta la línea de nohup a la tuya):"
  echo "  PID=\$(ss -ltnp | sed -n 's/.*:8000.*pid=\\([0-9]*\\).*/\\1/p' | head -1)"
  echo "  kill \$PID"
  echo "  # luego vuelve a lanzar retrieve_l1 / uvicorn como siempre"
  echo ""
  # Intentar localizar retrieve_l1.py y un pid
  PID=$(ss -ltnp 2>/dev/null | sed -n 's/.*:8000.*pid=\([0-9]*\).*/\1/p' | head -1 || true)
  if [[ -n "${PID:-}" ]]; then
    echo "PID actual :8000 = $PID"
    echo "cmdline:"
    tr '\0' ' ' < /proc/$PID/cmdline 2>/dev/null; echo
    # Si el padre es un restart loop, SIGHUP a veces basta — muchos no recargan FAISS
    echo "Enviando SIGTERM a $PID (el supervisor debería relanzar)…"
    kill -TERM "$PID" || true
    sleep 3
    NEW=$(ss -ltnp 2>/dev/null | sed -n 's/.*:8000.*pid=\([0-9]*\).*/\1/p' | head -1 || true)
    echo "PID :8000 ahora = ${NEW:-ninguno}"
    if [[ -z "${NEW:-}" ]]; then
      echo "No volvió solo. Relanza a mano, por ejemplo:"
      if [[ -f $ROOT/retrieve_l1.py ]]; then
        echo "  cd $ROOT && nohup $ROOT/venv_tektron/bin/python3 -u retrieve_l1.py > /tmp/retrieve_l1.log 2>&1 &"
      fi
    fi
  fi
fi

sleep 2
echo ""
echo "=== probe rápido ==="
curl -sS -m 60 -X POST http://127.0.0.1:8000/retrieve \
  -H 'Content-Type: application/json' \
  -d '{"query":"¿Qué es el MCC?"}' || echo "curl fail"
echo ""
