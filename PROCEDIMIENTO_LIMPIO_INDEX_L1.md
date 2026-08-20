# Procedimiento limpio — index_l1 + bridge

**No ciclar:** no más “rebuild FAISS → restart → diagnose → restart”.
Un solo orden. Una fuente de verdad.

## Arquitectura

```
chunks.jsonl     ← ÚNICA fuente de verdad del índice vivo
    ↓ reconcile
meta.json        ← n_sit/n_heg/n_tec recalculados (nunca n_sit += N)
faiss.idx        ← solo si ntotal ≠ len(jsonl)
    ↓ smoke IndexL1
tektron_bridge   ← arrancar UNA vez
    ↓
POST /retrieve
```

## Por qué fallaba el bridge

```
retrieve_l1.py: assert len(self.set_sit) == self.meta["n_sit"]
```

1. Andamiaje escribió polos `SIT` y el IndexL1 cuenta `SITUADO`.
2. El indexador hizo `n_sit += 687` en `meta.json` (parche) en vez de recalcular.
3. Reiniciar systemd no arregla meta: el proceso arranca, falla el assert, muere, reinicia en loop.

FAISS puede estar sync (12273=12273) y el bridge igual caer. **No hace falta otro rebuild FAISS** si `faiss ok=True`.

## Estado actual (Jetson) — qué hacer YA

### Terminal 1

```bash
# 1) Parar el crash-loop
sudo systemctl stop tektron-bridge.service
sudo systemctl reset-failed tektron-bridge.service 2>/dev/null || true

# 2) Crear el reconciliador (pegar el archivo del repo o este cat)
#    Si ya hiciste git pull + scp, salta al paso 3.
```

Copia `tektron_reconcile_index_l1.py` a `/mnt/tektron/workspace/` (desde el iMac):

```bash
# en iMac
cd ~/CIERRE-TEKTRON && git pull
scp tektron_reconcile_index_l1.py tektron@192.168.100.84:/mnt/tektron/workspace/
```

### Dry-run → apply

```bash
/mnt/tektron/venv_tektron/bin/python3 \
  /mnt/tektron/workspace/tektron_reconcile_index_l1.py --dry-run

/mnt/tektron/venv_tektron/bin/python3 \
  /mnt/tektron/workspace/tektron_reconcile_index_l1.py --apply
```

Esperado: `OK reconcile` y `smoke IndexL1` con `ok: True`.

- Si dice `faiss ok=False` → entonces sí:
  ```bash
  CUDA_VISIBLE_DEVICES= /mnt/tektron/venv_tektron/bin/python3 \
    /mnt/tektron/workspace/tektron_reconcile_index_l1.py --apply --rebuild-faiss
  ```
- Si smoke falla → pega `sed -n '90,160p' /mnt/tektron/retrieve_l1.py` (no inventar otro restart).

### Arrancar bridge UNA vez

```bash
cd /mnt/tektron
nohup /mnt/tektron/venv_tektron/bin/python3 -u /mnt/tektron/tektron_bridge_l1.py \
  >> /mnt/tektron/workspace/bridge_l1.log 2>&1 &
sleep 4
ss -ltn | grep 8000
```

(Cuando smoke pase de forma estable, puedes volver a `sudo systemctl start tektron-bridge.service`.)

### Terminal 2 — probe

```bash
curl -s http://127.0.0.1:8000/retrieve \
  -H 'Content-Type: application/json' \
  -d '{"query":"¿Qué es el MCC?"}'
```

Esperado: fuentes `zenodo_21500800` / `zenodo_17728016` (no Connection refused, no ABSTENER vacío).

## Regla de oro (para no ciclar)

| Cambio | Acción obligatoria |
|--------|-------------------|
| Mutaste `chunks.jsonl` | `tektron_reconcile_index_l1.py --apply` |
| FAISS desync | reconcile con `--rebuild-faiss` |
| Solo bridge caído pero smoke IndexL1 OK | arrancar bridge (no tocar índice) |
| Bridge crash con AssertionError n_sit | reconcile (no restart en loop) |

**Prohibido:** incrementar `n_sit` a mano; reiniciar systemd sin smoke; rebuild FAISS “por si acaso”.

## Scripts

| Script | Rol |
|--------|-----|
| `tektron_reconcile_index_l1.py` | **Única** vía post-mutación |
| `tektron_rebuild_faiss_from_chunks.py` | Solo embebido (lo llama reconcile si hace falta) |
| `tektron_fix_meta_l1.py` | Legacy → usar reconcile |
| `tektron_indexar_andamiaje_l1.py` | Solo append chunks; luego reconcile |
| `tektron_diagnose_retrieve_mcc.py` | Lectura / verify |
