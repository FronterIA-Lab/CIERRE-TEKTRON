# Estado post-corrección (Jetson)

**Objetivo:** MAX Árboles de Espejos + MCC + SHA (N0 = piso).

## Diagnóstico limpio (no ciclar)

| Pieza | Estado |
|-------|--------|
| `chunks.jsonl` | 12 273 (andamiaje incluido) |
| FAISS | sync OK · dim 768 · **no es el bloqueo actual** |
| Bridge `:8000` | crash-loop: `assert len(set_sit) == meta["n_sit"]` |
| Causa | polos `SIT` vs `SITUADO` + `n_sit += N` ad-hoc en meta |
| Chunks ¿suficientes? | **Sí** para Gate MCC (FAISS Top-8 trae zenodo MCC) |

## Solución limpia (una sola)

Ver **`PROCEDIMIENTO_LIMPIO_INDEX_L1.md`**.

```bash
sudo systemctl stop tektron-bridge.service

# iMac: git pull && scp tektron_reconcile_index_l1.py …:/mnt/tektron/workspace/

/mnt/tektron/venv_tektron/bin/python3 \
  /mnt/tektron/workspace/tektron_reconcile_index_l1.py --dry-run

/mnt/tektron/venv_tektron/bin/python3 \
  /mnt/tektron/workspace/tektron_reconcile_index_l1.py --apply
# (añade --rebuild-faiss SOLO si dry-run dice faiss ok=False)

# smoke OK → arrancar bridge UNA vez
cd /mnt/tektron
nohup ./venv_tektron/bin/python3 -u tektron_bridge_l1.py \
  >> workspace/bridge_l1.log 2>&1 &
ss -ltn | grep 8000

curl -s http://127.0.0.1:8000/retrieve \
  -H 'Content-Type: application/json' \
  -d '{"query":"¿Qué es el MCC?"}'
```

**Prohibido mientras tanto:** restart systemd en loop, rebuild FAISS “por si acaso”, otro diagnose sin reconcile.

Cuando `/retrieve` traiga fuentes zenodo → Gate v8.
