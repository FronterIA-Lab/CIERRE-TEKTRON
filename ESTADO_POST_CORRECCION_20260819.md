# Estado post-corrección (Jetson)

**Objetivo:** MAX Árboles de Espejos + MCC + SHA (N0 = piso).

## Hecho

| Paso | Resultado |
|------|-----------|
| Andamiaje en `00_Core` | 15 PDF + MD |
| `chunks.jsonl` | **12 273** (incl. +687 andamiaje) |
| FAISS mpnet | **SYNC OK** · ntotal=12273 · **dim=768** |
| `faiss_model` | paraphrase-multilingual-mpnet-base-v2 (= `retrieve_l1.py`) |
| Probe `/retrieve` “¿Qué es el MCC?” | bloqueado: **bridge :8000 caído** (FAISS disco OK) |
| Chunks ¿suficientes? | **Sí para Gate MCC**: FAISS Top-8 trae `21500800`/`17728016`. Los “203 MCC-ish” eran ruido regex. |

## Diagnose (confirmado)

- FAISS disco Top-8 incluye `zenodo_21500800` / `zenodo_17728016` (scores ~0.61–0.52).
- `/retrieve` sigue ABSTENER → **bridge con FAISS viejo en RAM**.

## Lectura

Disco/FAISS OK (MCC recuperable). **Cierre bloqueado solo por bridge :8000 caído** (`Connection refused`).  
No hace falta más andamiaje para el probe “¿Qué es el MCC?”.

## Siguiente (en este orden)

```bash
cd ~/CIERRE-TEKTRON && git pull
scp tektron_diagnose_retrieve_mcc.py tektron_start_bridge_l1.sh \
  tektron@192.168.100.84:/mnt/tektron/workspace/

# 1) Levantar bridge
ssh -t tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_start_bridge_l1.sh'
# o: sudo systemctl restart tektron-bridge.service

# 2) Diagnose (debe pasar /retrieve, no Connection refused)
ssh tektron@192.168.100.84 \
  'CUDA_VISIBLE_DEVICES= /mnt/tektron/venv_tektron/bin/python3 \
   /mnt/tektron/workspace/tektron_diagnose_retrieve_mcc.py'
```

- Si `/retrieve` trae fuentes zenodo → Gate v8.  
- Si sigue `Connection refused` → el start no dejó LISTEN en :8000 (ver `bridge_l1.log`).  
- Si habla pero ABSTENER vacío → bridge con índice viejo en RAM (reload otra vez).
