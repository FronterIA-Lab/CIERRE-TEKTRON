# Estado post-corrección (Jetson)

**Objetivo:** MAX Árboles de Espejos + MCC + SHA (N0 = piso).

## Hecho

| Paso | Resultado |
|------|-----------|
| Andamiaje en `00_Core` | 15 PDF + MD |
| `chunks.jsonl` | **12 273** (incl. +687 andamiaje) |
| FAISS mpnet | **SYNC OK** · ntotal=12273 · **dim=768** |
| `faiss_model` | paraphrase-multilingual-mpnet-base-v2 (= `retrieve_l1.py`) |
| Probe `/retrieve` “¿Qué es el MCC?” | **ABSTENER** · `fuentes=[]` |

## Diagnose (confirmado)

- FAISS disco Top-8 incluye `zenodo_21500800` / `zenodo_17728016` (scores ~0.61–0.52).
- `/retrieve` sigue ABSTENER → **bridge con FAISS viejo en RAM**.

## Lectura

Disco OK. El bridge habla (`http 200`, `bridge=l1`) pero **no recupera** MCC.  
Causa más probable: **FAISS cargado en RAM antes del rebuild**, o umbral N0 sobre índice viejo.

## Siguiente (en este orden)

```bash
cd ~/Downloads/CIERRE-TEKTRON && git pull
scp tektron_diagnose_retrieve_mcc.py tektron_restart_bridge.sh \
  tektron@192.168.100.84:/mnt/tektron/workspace/

# A) ¿FAISS en disco sí encuentra MCC?
ssh tektron@192.168.100.84 \
  'CUDA_VISIBLE_DEVICES= /mnt/tektron/venv_tektron/bin/python3 \
   /mnt/tektron/workspace/tektron_diagnose_retrieve_mcc.py'

# B) Reinicia el bridge :8000 (tu comando habitual, o el script)
ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_restart_bridge.sh'

# C) Probe otra vez
ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_probe_mcc_retrieve.sh'
```

- Si A encuentra MCC y C sigue ABSTENER → reinicio del bridge incompleto.  
- Si A no encuentra MCC → problema de indexación (revisar).  
- Si C ya trae fuentes → pasar a Gate v8.
