# Estado — restore (un solo paso)

Tres snapshots existen. Siguiente acción: **restaurar** el trío completo y levantar bridge.
Sin Gate. Sin reconcile. Sin align-meta.

## En Jetson — pegar esto

```bash
cat > /mnt/tektron/workspace/tektron_restore_l1_y_bridge.sh << 'ENDOFFILE'
PLACEHOLDER
ENDOFFILE
# (mejor: copiar el script del repo; ver comando abajo)
```

O desde iMac:
```bash
cd ~/CIERRE-TEKTRON && git pull
scp tektron_restore_l1_y_bridge.sh tektron@192.168.100.84:/mnt/tektron/workspace/
```

En Jetson:
```bash
bash /mnt/tektron/workspace/tektron_restore_l1_y_bridge.sh
```

Prioridad de restore: `pre_correccion` (si tiene faiss) → sino `index_l1_precuracion_20260819`.

Pega la salida del script. Con IndexL1 OK + :8000, el crash terminó; el andamiaje MCC se reincorpora en un segundo paso controlado.
