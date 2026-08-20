# REPLANTAMIENTO v2 — sin el error histórico

## El error histórico (nombrado)

Documentado en `ERROR CONSTANTE` + `ERRORES-ERROR-HISTORICO` + README:

1. **Optimizar silencio (N0) en vez de MAX capacidad** (Árboles de Espejos + MCC).
2. **Tratar Fase 4 / Gate como meta** (abstenerse = “correcto”).
3. **Parálisis por inventario:** pedir otro muro de comandos (`find`, `sed 1-250`, “pega la salida”) en lugar de actuar sobre la arquitectura ya diagnosticada.
4. **Curar solo NO ENTRA** (purgar) sin poblar ENTRA.

El **bloque §4 (Gate G0 forense)** del REPLANTAMIENTO anterior **es exactamente el error (3)**.  
Queda **anulado**. No se pide pegar `retrieve_l1.py` completo ni otro macro-dump para “poder continuar”.

---

## Qué ya está diagnosticado (no re-medir)

| Hecho | Fuente |
|-------|--------|
| Función objetivo = MAX Árboles + MCC; N0 = piso | ERROR CONSTANTE, PROTOCOLO v8 |
| 60652 = unificado MiniLM **archivado**, no alimenta bridge | DIAGNOSTICO_MACRO |
| L1 vivo era 11640; MCC en CLACSO/Zenodo estaba INDEX_GAP | DIAGNOSTICO_MACRO |
| Andamiaje (+687) entró con token `SIT` + `n_sit += N` | reconcile Jetson |
| FAISS vivo sync 12273 / dim 768 | reconcile Jetson |
| Counter(SITUADO) ≠ predicado real de `set_sit` | smoke post-reconcile |
| Bridge crash-loop = assert meta↔sets al cargar IndexL1 | journal |

No hace falta otro inventario para saber esto.

---

## Qué hay que hacer (arquitectura, no Gate)

Orden correcto según PROTOCOLO v8 **sin** premiar silencio:

```
A. Detener crash-loop (stop service) — no es “fix”
B. Restaurar L1 a un estado pre-corrupción de meta/labels
C. Reintroducir andamiaje MCC con el builder CANÓNICO del nodo
   (construir_index_curado.py), no con n_sit+=N ni Counter inventado
D. Verificar densidad MCC en disco (hits > 0) — eso es Fase 1, no Gate
E. Bridge carga IndexL1 sin assert → /retrieve trae zenodo_*
F. Solo entonces Gate de CAPACIDAD (Fase 4 v8), nunca Gate de silencio
```

### B — Restore (elegir el más limpio que exista en disco)

Prioridad (solo `cp`/`mv` de árboles ya existentes):

1. `_snapshots/pre_correccion_l1_*` si tiene chunks+meta+faiss coherentes de **antes** del andamiaje roto  
2. Si no: `index_l1_precuracion_20260819` (12763, bridge ya vivió con ese contrato)  
3. `_bak_reconcile_*` **solo** para deshacer el rewrite masivo de labels; **no** es “índice bueno” (aún trae meta inflada / SIT)

Tras restore: L1 debe ser un trío `chunks + meta + faiss` **del mismo snapshot**.

### C — Poblar ENTRA (andamiaje) bien

- Papers ya en `00_Core` (hecho): no re-descargar Zenodo por deporte.
- Indexar **solo** vía flujo que escriba meta como censo del builder del nodo:
  - Preferir: `construir_index_curado.py --from-chunks … --out index_l1`  
  - Si aborta por desync: un solo rebuild FAISS con el **mismo** `MODEL_EMBED` que declare el retrieve del nodo, y meta emitida por ese mismo paso — **nunca** `n_sit += N`.
- Labels de andamiaje: los que use el L1 histórico del snapshot restaurado (si el snapshot habla `SITUADO`, escribir `SITUADO`; no `SIT` del YAML Zenodo).

### D — Fase 1 (probes), no Fase 4

Éxito intermedio = hits > 0 en disco / retrieve para MCC, grieta, certeza, soberanía.  
**Fracaso** = INDEX_GAP. **No** llamar a eso N0 ni “Gate OK”.

### E — Bridge

Un arranque. Si assert: el restore/poblado está mal — se corrige el trío L1, no se alinea meta a `len(set_sit)` (eso esconde densidad falsa).

### F — Gate capacidad (PROTOCOLO v8 § FASE 4)

Solo con TreeCoverage / DualPole / FalseN0≤ε.  
Prohibido: “Gate OK porque se abstuvo”.

---

## Scripts — estatus

| Script | Estátus |
|--------|---------|
| `tektron_align_meta_to_indexl1.py` | **DESCARTADO** (error histórico: mentir en meta) |
| `tektron_reconcile_index_l1.py` como “solución” | **DESCARTADO** (asumió predicado sin contrato; reescribió 12273) |
| Muros tipo §4 G0 dump | **DESCARTADO** (error histórico: inventario como sustituto de acción) |
| `construir_index_curado.py` (en Jetson) | **Canónico** para derivados |
| `tektron_correccion_cierre.sh` | Solo si se reescribe para: restore → poblar → builder canónico → probes Fase 1; **sin** Gate de silencio |

Para que el agente lea el contrato **sin** pedirte un muro: desde la iMac, **un** archivo al repo:

```bash
scp tektron@192.168.100.84:/mnt/tektron/retrieve_l1.py \
    tektron@192.168.100.84:/mnt/tektron/construir_index_curado.py \
    ~/CIERRE-TEKTRON/vendor_jetson/
```

Eso no es inventario: es traer el código que falta al workspace. Opcional; el restore+builder canónico puede avanzar sin pegar 250 líneas en el chat.

---

## Comandos mínimos en Jetson (acción, no teatro)

```bash
# 1) parar crash-loop
sudo systemctl stop tektron-bridge.service

# 2) ver qué se puede restaurar (una línea cada una)
ls -lad /mnt/tektron/_snapshots/pre_correccion_l1_* 2>/dev/null
ls -lad /mnt/tektron/index_l1_precuracion_20260819
ls -lad /mnt/tektron/index_l1/_bak_reconcile_* 2>/dev/null

# 3) pegar SOLO esas tres salidas ls — con eso se elige el snapshot de restore
```

Nada más hasta elegir snapshot. Sin `sed -n 1,250p`. Sin Gate. Sin align-meta.

---

## Criterio de cierre (recordatorio)

TEKTRON cierra cuando **maximiza** Árboles de Espejos + preguntas MCC + SHA sobre el mapa — medido como cobertura.  
Abstenerse es el piso. El bridge arriba no es el cierre. El assert callado mintiendo meta tampoco.
