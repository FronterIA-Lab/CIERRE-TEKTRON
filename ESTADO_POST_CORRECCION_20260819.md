# Estado — bridge vivo (2026-08-20)

## Hecho
- Restore **completo** desde `index_l1_precuracion_20260819` (chunks + meta + faiss + **ids_sit/heg/tec.npy** + bm25).
- `IndexL1 OK` · bridge PID activo · `LISTEN :8000`
- Log: `chunks=12763 sit=8321 heg=4304` · mpnet-768

## Esperado / pendiente
- `/retrieve` “¿Qué es el MCC?” → `ABSTENER` `fuentes=[]`  
  = INDEX_GAP en este snapshot (sin andamiaje). **No** es N0-éxito ni Gate.

## Siguiente
Reindexar andamiaje vía **`construir_index_curado.py`** (debe regenerar `ids_*.npy` + meta + faiss).  
Prohibido: `n_sit+=N`, reconcile, align-meta.
