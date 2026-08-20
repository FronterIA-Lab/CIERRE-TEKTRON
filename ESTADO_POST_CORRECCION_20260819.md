# Estado post-corrección 2026-08-19 (Jetson)

**Objetivo:** MAX Árboles de Espejos + MCC + SHA (N0 = piso).

## Hecho

| Paso | Resultado |
|------|-----------|
| Cuarentena + filtrar L1 | 11 640 → 11 586 (−54) |
| Andamiaje `00_Core` | 15 PDF + 15 MD |
| Chunks andamiaje | +687 → **12 273** en `chunks.jsonl` |
| Probes texto MCC | OK (grieta, certeza, núcleo Zenodo) |
| Rebuild FAISS (CPU) | **SYNC OK** `ntotal=12273` **dim=384** |

## Atención: dimensión — RESUELTO el diagnóstico

- Índice previo / bridge vivo (`retrieve_l1.py`): **mpnet-base-v2 → dim 768**
- Rebuild equivocado: MiniLM-L12-v2 → dim 384  
- Acción: rebuild FAISS otra vez con mpnet (CPU).

## Siguiente

```bash
cd ~/Downloads/CIERRE-TEKTRON && git pull
scp tektron_probe_mcc_retrieve.sh tektron@192.168.100.84:/mnt/tektron/workspace/
ssh tektron@192.168.100.84 'bash /mnt/tektron/workspace/tektron_probe_mcc_retrieve.sh'
```

Esperado: hits de `zenodo_17728016` / `zenodo_21500800`.  
Si error de dim → rebuild con el modelo 768 del bridge (el probe lo busca en el código).

Luego: reiniciar bridge si hace falta → Gate v8.
