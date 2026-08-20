# Estado post-corrección 2026-08-19 (Jetson)

**Run:** `/mnt/tektron/workspace/correccion_20260819_190207/`  
**Objetivo:** MAX Árboles de Espejos + MCC + SHA (N0 = piso).

## Hecho

| Fase | Resultado |
|------|-----------|
| 1 Cuarentena | Ejecutada |
| 2 Filtrar L1 | 11 640 → **11 586** (−54 contaminación) |
| 3 Andamiaje `00_Core` | **15** PDF + **15** MD |
| 4 Indexar L1 | **+687** chunks → ≈**12 273** en `chunks.jsonl` |
| 5 Probes texto | MCC / certeza / grieta / soberanía / núcleo Zenodo = **OK** |

## Bloqueo actual (crítico)

`construir_index_curado.py` abortó:

```
faiss (11640) != jsonl (11586)
```

Tras fase 4, `chunks.jsonl` ≈ 12 273 pero **FAISS no quedó alineado**.  
Sin rebuild denso, `/retrieve` puede **no** devolver el andamiaje MCC aunque el jsonl ya lo tenga.

`arbol_de_espejos` = INDEX_GAP en corpus: es **salida** del sistema (README), no un paper; no bloquea si MCC ya tiene hits.

faiss OK ntotal=12273 dim=384 → …  
SYNC OK: faiss.ntotal == len(chunks.jsonl)

**Atención:** el índice vivo anterior reportaba **dim=768**; este rebuild usó
`paraphrase-multilingual-MiniLM-L12-v2` → **dim=384**.  
Si el bridge embebe consultas en 768, `/retrieve` fallará hasta alinear modelo.

```bash
cd ~/Downloads/CIERRE-TEKTRON && git pull
scp tektron_probe_mcc_retrieve.sh tektron@192.168.100.84:/mnt/tektron/workspace/
ssh tektron@192.168.100.84 'bash /mnt/tektron/workspace/tektron_probe_mcc_retrieve.sh'
```

Si hay error de dimensión, rebuild con el modelo 768 que use el bridge, p. ej.:

```bash
ssh tektron@192.168.100.84 \
  'CUDA_VISIBLE_DEVICES= /mnt/tektron/venv_tektron/bin/python3 \
   /mnt/tektron/workspace/tektron_rebuild_faiss_from_chunks.py --device cpu \
   --model sentence-transformers/paraphrase-multilingual-mpnet-base-v2'
```
(Confirmar el nombre exacto con el grep del probe.)

## Después del sync FAISS

1. Gate v8 (capacidad: FalseN0≤ε, árboles en consultas duales).  
2. No tocar `memoria_usuario.json`.  
3. Opcional: reiniciar bridge/backend si cachean el índice en RAM.
