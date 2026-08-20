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

## Siguiente comando (iMac → Jetson)

```bash
cd ~/Downloads/CIERRE-TEKTRON
git pull
scp tektron_rebuild_faiss_from_chunks.py \
  tektron@192.168.100.84:/mnt/tektron/workspace/

# opcional: ver desfase
ssh tektron@192.168.100.84 \
  '/mnt/tektron/venv_tektron/bin/python3 /mnt/tektron/workspace/tektron_rebuild_faiss_from_chunks.py --dry-run'

# rebuild completo (puede tardar en Jetson)
ssh tektron@192.168.100.84 \
  '/mnt/tektron/venv_tektron/bin/python3 /mnt/tektron/workspace/tektron_rebuild_faiss_from_chunks.py'
```

Luego verificar retrieve:

```bash
ssh tektron@192.168.100.84 \
  'curl -sS -X POST http://127.0.0.1:8000/retrieve -H "Content-Type: application/json" \
   -d "{\"query\":\"¿Qué es el MCC?\"}" | head -c 2000'
```

Esperado: fragmentos de `zenodo_17728016` / `zenodo_21500800`, no abstención vacía.

## Después del sync FAISS

1. Gate v8 (capacidad: FalseN0≤ε, árboles en consultas duales).  
2. No tocar `memoria_usuario.json`.  
3. Opcional: reiniciar bridge/backend si cachean el índice en RAM.
