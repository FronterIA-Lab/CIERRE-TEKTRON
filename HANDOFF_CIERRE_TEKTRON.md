# HANDOFF — Estado honesto para cerrar TEKTRON

**Para:** el siguiente asistente / humano que retome el cierre  
**De:** sesión cloud agent 2026-08-19/20 (rama `cursor/analisis-cierre-tektron-6f65`)  
**Host:** `tektron@192.168.100.84` · SSD `/mnt/tektron`  
**Repo:** `FronterIA-Lab/CIERRE-TEKTRON`

Este documento es un **relevo**. No es un Gate. No es un acta de cierre.  
Si el asistente siguiente optimiza silencio, reinicios o parches de `meta.json`, está repitiendo el fallo que ya contaminó meses de trabajo.

---

## 1. Objetivo (no negociable)

TEKTRON es un **analista situado** que aplica el **MCC** para producir **Árboles de Espejos** (tesis HEG vs antítesis SIT, tensión **sin síntesis**) + preguntas MCC + evidencia SHA-256.

```
MAX J = MirrorCoverage × DualPoleDensity × TensionFaithfulness × EvidenceIntegrity
```

Constraints: `FalseN0 ≤ ε` · `TrueN0 ≥ floor` · `SynthesisRate = 0` · polos gold sin mislabel.

| Salida correcta | Valor |
|-----------------|-------|
| Árbol dual + MCC + SHA | máximo |
| Mono-polo + declaración explícita del polo ausente + MCC | alto (honesto) |
| N0 real (“No sé” + hash vacío) | piso anti-confabulación, **no** premio |
| Concepto ENTRA con 0 hits | **INDEX_GAP** → remediar corpus/índice; **nunca** celebrar como N0 |

Fuentes de verdad del objetivo: `README.md` (Arquitectura Fija) · `ANALISIS_COMPLETO_TEKTRON.md` · `PROTOCOLO_CIERRE_TEKTRON_v8.md` · `ERROR CONSTANTE` (como **anti-patrón** a no repetir).

**Cerrado** solo si se cumplen C1–C7 del PROTOCOLO v8 (conectividad, probes MCC>0, densidad dual, calibración, Gate de **capacidad**, interfaz MCC, acta con hashes reales).  
Bridge UP ≠ cerrado. `ABSTENER` ≠ cerrado.

---

## 2. Error en el que estamos (honesto)

### 2.1 Error de fondo (meses)

Se invirtió la función objetivo: se maximizó **no equivocarse** (purga NO ENTRA, Gate de abstención, “MCC=0 es fallo correcto”) en vez de **maximizar Árboles**.  
Documentado en `ERROR CONSTANTE` y `ERRORES-ERROR-HISTORICO`. El PROTOCOLO v8 ya lo corrige por escrito; la **ejecución** en el nodo sigue incompleta.

### 2.2 Error técnico de esta sesión (agosto 2026)

Se intentó poblar andamiaje MCC en `index_l1` **sin respetar el paquete atómico del índice vivo**.

El índice L1 no es solo `chunks.jsonl` + `faiss.idx` + `meta.json`.  
En el nodo, `IndexL1` (`retrieve_l1.py`) exige coherencia con:

| Artefacto | Rol |
|-----------|-----|
| `chunks.jsonl` | texto + `tipo_epistemico` (`SITUADO` / `HEGEMONICO` / `TECNICO`) |
| `faiss.idx` | vectores alineados 1:1 con filas jsonl · dim **768** · modelo **paraphrase-multilingual-mpnet-base-v2** |
| `bm25.pkl` | sparse |
| **`ids_sit.npy` / `ids_heg.npy` / `ids_tec.npy`** | conjuntos de índices por polo |
| `meta.json` | `n_chunks`, `n_sit`, `n_heg`, `n_tec` deben coincidir con `len(ids_*.npy)` |

`construir_index_curado.py` (en Jetson) documenta ese paquete (`artifacts`: chunks, faiss, bm25, ids_*, meta) y regenera `ids_*.npy` + conteos al **curar**.  
**No** es un ingest de papers nuevos: solo filtra/reetiqueta un índice ya existente reutilizando vectores.

Lo que rompió el bridge:

1. Append de andamiaje con polo corto `SIT` (YAML Zenodo) vs vocabulario L1 `SITUADO`.
2. `meta["n_sit"] += N` sin regenerar `ids_sit.npy`.
3. Rebuild FAISS / reconcile / align-meta / restarts **sin** el paquete completo.
4. Restore incompleto (chunks+meta+faiss sin `ids_*.npy`) → más daño hasta copiar los `.npy`.

Assert observado:

```text
retrieve_l1.py: assert len(self.set_sit) == self.meta["n_sit"]
```

### 2.3 Qué NO es el problema ahora

- No es “el puerto 8000 mágico”.
- No es falta de reiniciar systemd.
- No es que MCC “deba abstenerse correctamente”.
- El misterio **60 652** ya está resuelto (`DIAGNOSTICO_MACRO_20260819.md`): índice unificado MiniLM en `_archivo/`, **desconectado** del bridge. No swapearlo a ciegas sobre L1.

---

## 3. Estado medido del nodo (post-sesión)

| Pieza | Estado | Evidencia |
|-------|--------|-----------|
| Bridge `:8000` | **Vivo** | log: `TEKTRON L1 listo — chunks=12763 sit=8321 heg=4304` · `LISTEN :8000` |
| L1 vivo | Restore **completo** desde `index_l1_precuracion_20260819` | chunks+meta+faiss+bm25+**ids_*.npy** |
| `IndexL1` smoke | OK | `ids_sit=8321` match meta; `IndexL1 OK 8321 8321` |
| Embed | mpnet multilingual, dim 768 | log SentenceTransformer |
| `/retrieve` “¿Qué es el MCC?” | `ABSTENER`, `fuentes=[]` | **INDEX_GAP** en este snapshot (sin andamiaje en L1) |
| Papers MCC en repo | `corpus/andamiaje_propio/` (15 PDF+MD) | `ZENODO_CATALOGO_16.md` |
| Path Jetson andamiaje | `/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/...` | (con prefijo `corpus/`) — **verificar** si la instalación de esta sesión quedó; un `ls` falló por path incompleto |
| Snapshot pre-restore roto | `/mnt/tektron/_snapshots/l1_roto_pre_restore_20260819_222128` | contiene el L1 mutado (12273) por si se audita; **no** swapear sin regenerar ids |
| `pre_correccion` | solo chunks+meta (sin faiss) | incompleto como restore |
| Código runtime | **No está en este repo** | vive en `/mnt/tektron/retrieve_l1.py`, `tektron_bridge_l1.py`, `construir_index_curado.py`, `mcc_layer.py`, `tektron_backend.py` |

ZIM/wikipedia cargan como capa GENERAL en el bridge (`router=OFF`) — correcto; **no** mezclar ZIM en L1 dual.

---

## 4. Cuello de botella para el cierre (arquitectura)

El cierre no avanza por **densidad ENTRA del andamiaje MCC en el índice vivo**.

Prioridad de contenido (Arquitectura + catálogo):

1. Núcleo MCC: Zenodo `17728016` + `21500800`
2. Satélites: Certeza sin sustancia, Grieta Generativa, Soberanía Cognitiva / Neuroderechos
3. Resto andamiaje `00_Core` + material CLACSO ENTRA aún desconectado (ver DIAGNOSTICO_MACRO)
4. Luego densidad dual por anclas del mapa (punto 5 README)
5. Recién entonces Gate de **capacidad** (PROTOCOLO v8 Fase 4)

`construir_index_curado.py` no resuelve el ingest. Hace falta un **pipeline de adición** que, al mutar `chunks.jsonl`, regenere **todo** el paquete (incluye `ids_*.npy` + meta censo + faiss para filas nuevas con el mismo modelo 768).

---

## 5. Trabajo ordenado para el siguiente asistente

### Paso 0 — Traer el contrato al repo (obligatorio antes de escribir L1)

Desde la máquina del arquitecto:

```bash
mkdir -p vendor_jetson
scp tektron@192.168.100.84:/mnt/tektron/retrieve_l1.py \
    tektron@192.168.100.84:/mnt/tektron/tektron_bridge_l1.py \
    tektron@192.168.100.84:/mnt/tektron/construir_index_curado.py \
    tektron@192.168.100.84:/mnt/tektron/mcc_layer.py \
    tektron@192.168.100.84:/mnt/tektron/tektron_backend.py \
    vendor_jetson/
```

Leer cómo se construyen `set_sit` / `ids_*.npy`. No adivinar.

### Paso 1 — Localizar andamiaje en disco

Confirmar PDFs/MD en:

- Repo: `corpus/andamiaje_propio/`
- Jetson: `/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/{raw,markdown}/zenodo/`
- Respaldo CLACSO: `/mnt/tektron/_clacso_archivo/.../corpora` (MCC histórico en PDF)

Si `00_Core` está vacío, sync desde el repo (`tektron_sync_andamiaje_jetson.sh`) **sin** indexar aún.

### Paso 2 — Un solo ingest que respete el paquete

Requisitos del script nuevo (escribirlo **después** de leer `retrieve_l1.py`):

- Labels L1: `SITUADO` / `HEGEMONICO` / `TECNICO` (no `SIT`/`HEG` sueltos).
- Append chunks andamiaje (polo SITUADO para papers de método, salvo TEC explícito).
- Embed solo filas nuevas **o** rebuild completo con **mpnet-768**.
- Regenerar `ids_sit.npy`, `ids_heg.npy`, `ids_tec.npy` desde el censo de **todo** el jsonl.
- `meta.json`: `n_*` = `len(ids_*)` (censo, nunca `+=`).
- Smoke: `IndexL1(path)` carga; `faiss.ntotal == n_chunks`.
- Recargar bridge **una** vez.
- Probe: “¿Qué es el MCC?” debe devolver fuentes `zenodo_17728016` / `21500800` (u equivalentes), no `fuentes=[]`.

### Paso 3 — Fase 1 PROTOCOLO (probes)

Emitir `mcc_probe_hits.json`: MCC, grieta, certeza, soberanía, neuroderechos. Hits>0 o remediación.  
INDEX_GAP se remedia; no se traduce a N0.

### Paso 4 — Seguir v8

Densidad dual por ancla → calibración de canales → Gate de **capacidad** (TreeCoverage / DualPole / FalseN0) → interfaz → acta con hashes medidos.

---

## 6. Prohibiciones (para no ciclar)

El asistente **no debe**:

1. Tratar N0 / `ABSTENER` / “el Gate falló correctamente” como progreso de cierre.
2. Ejecutar solo purga NO ENTRA sin poblar ENTRA.
3. Mutar `chunks`/`faiss`/`meta` sin regenerar **`ids_*.npy`**.
4. Hacer `meta[n_sit] = len(set_sit)` para silenciar el assert (esconde densidad falsa).
5. Swapear `_archivo/index_unificado_minilm_*` (60652) sobre L1 sin auditoría.
6. Mezclar ZIM/Wikipedia en el dual HEG/SIT.
7. Sustituir arquitectura por muros de diagnóstico o restart loops.
8. Usar scripts de esta sesión como “solución”:  
   `tektron_align_meta_to_indexl1.py`, `tektron_reconcile_index_l1.py` (asumió predicado), restores incompletos, `n_sit += N` en indexar antiguo.

Scripts útiles solo como **contexto histórico de fallo**, no como runbook.

---

## 7. Mapa de documentos en el repo

| Documento | Uso |
|-----------|-----|
| `README.md` | Arquitectura Fija (qué es TEKTRON, ENTRA/NO ENTRA) |
| `PROTOCOLO_CIERRE_TEKTRON_v8.md` | Orden de cierre C1–C7 / fases |
| `ANALISIS_COMPLETO_TEKTRON.md` | Función J y corpus ideal |
| `DIAGNOSTICO_MACRO_20260819.md` | 60652 resuelto; CLACSO/MCC desconectados |
| `ZENODO_CATALOGO_16.md` | Núcleo MCC + andamiaje propio |
| `ERROR CONSTANTE` / `ERRORES-ERROR-HISTORICO` | Anti-patrones (leer para **no** repetir) |
| `PROTOCOLO DE CIERRE — TEKTRON v7.0 -MAL IMPLEMENTADO` | Histórico; no ejecutar |
| Este archivo | Estado honesto + handoff |

Ignorar como guía de cierre: `PARADA_PROTOCOLO_HONESTO.md` (parcial), `PROCEDIMIENTO_LIMPIO_INDEX_L1.md` (predicado incompleto), `ESTADO_POST_*` viejos si contradicen este handoff.

---

## 8. Criterio de éxito del próximo tramo

El próximo tramo **terminó bien** cuando:

1. El código del nodo está en `vendor_jetson/` (o equivalente versionado).
2. L1 vivo contiene chunks del núcleo MCC con polos L1 válidos.
3. Paquete `ids_*.npy` + meta + faiss coherente; bridge carga sin assert.
4. `/retrieve` “¿Qué es el MCC?” devuelve fuentes del andamiaje (no lista vacía).
5. Probes Fase 1 documentados en JSON.

Eso aún **no** es el cierre total (faltan C3–C7), pero sí el puente roto que bloquea maximizar Árboles.

---

## 9. Compromiso explícito

La sesión que precede a este handoff **falló en disciplina**: escribió el índice sin el contrato completo y cicló en síntomas.  
El objetivo no cambió: **maximizar capacidad de analista situado**.  
El estado útil que deja: bridge estable en precuración 12763 con `ids_*.npy` correctos — un piso para poblar MCC bien, no un resultado de cierre.

Cualquier asistente que retome: **poblar ENTRA con paquete atómico**, medir cobertura, Gate de capacidad al final. Nada más.
