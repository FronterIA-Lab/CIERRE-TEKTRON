# Estado — error histórico reconocido

**El bloque §4 (muro forense / Gate-dump) queda anulado.**  
Era el patrón del error histórico: inventario en vez de arquitectura; Gate/silencio en vez de MAX capacidad.

Ver **`REPLANTAMIENTO_CIERRE_RIGOR.md` (v2)**.

## Siguiente (mínimo)

En Jetson, solo:

```bash
sudo systemctl stop tektron-bridge.service
ls -lad /mnt/tektron/_snapshots/pre_correccion_l1_* 2>/dev/null
ls -lad /mnt/tektron/index_l1_precuracion_20260819
ls -lad /mnt/tektron/index_l1/_bak_reconcile_* 2>/dev/null
```

Con eso se elige **restore** del trío chunks+meta+faiss, luego poblar andamiaje con `construir_index_curado.py` (canónico), probes Fase 1 (MCC hits), bridge.  
Gate de capacidad = al final, nunca como meta de silencio.
