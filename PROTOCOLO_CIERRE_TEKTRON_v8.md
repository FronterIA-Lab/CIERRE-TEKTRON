# PROTOCOLO DE CIERRE — TEKTRON v8.0

**Basado en:** Arquitectura Fija · ERROR CONSTANTE · ERRORES-ERROR-HISTORICO · análisis de 15 papers  
**Función objetivo:** MAXIMIZAR capacidad de analista situado (Árboles de Espejos), no minimizar error.  
**Estado:** Fuente de verdad operativa. Cualquier desviación hacia “premiar silencio” se descarta.

---

## Principios no negociables

1. **Corpus antes que Gate.** Inventario total del disco (fuentes + índices + Wikipedia/general) es Fase −1. Sin `$INV/10_CORPUS_INVENTORY_REPORT.json` no hay cierre. Playbook: `INVENTARIO_CORPUS_JETSON.md`.
2. **N0 es piso, no meta.** Abstenerse no suma puntos de cierre.
3. **Poblar / reconectar antes de purgar.** Si el corpus nunca fue tocado pero el índice está mal, se reindexa el puente; no se borra la fuente.
4. **INDEX_GAP ≠ N0.** Concepto ENTRA con 0 hits es fallo de corpus/índice.
5. **Wikipedia / conocimiento general ≠ andamiaje dual.** Enciclopedia genérica (ZIM, wiki-rag, dumps) vive en namespace `GENERAL` separado; **no** se mezcla en `index_l1` HEG/SIT (punto 5 Arquitectura: sin estructura de disputa = NO ENTRA a L1).
6. **Sin síntesis.** Tensión HEG↔SIT; MCC pregunta, no resuelve.
7. **Scores por canal normalizados.** Prohibido umbral global sobre BM25 crudo mezclado.

---

## Definición de CERRADO

TEKTRON está cerrado solo si **todas** las condiciones valen:

| # | Condición | Evidencia |
|---|-----------|-----------|
| C1 | Conectividad corpus↔índice documentada | `CORPUS_CONNECTIVITY_REPORT.json` firmado |
| C2 | Probes MCC con hits > 0 (o remediación + reindex verificada) | `mcc_probe_hits.json` |
| C3 | Densidad dual medida por ancla del mapa (punto 5) | `dual_density_por_ancla.tsv` |
| C4 | Canales de retrieval calibrados y separables | `calibracion_n0_v8.json` con margen > 0 |
| C5 | Gate de **capacidad** aprobado (FalseN0≤ε, TrueN0≥floor) | `resultados_gate_v8.json` |
| C6 | Backend emite Árbol / MONO / N0 / INDEX_GAP con MCC + SHA | smoke tests `/analizar` |
| C7 | Acta con hashes reales (no cifras heredadas sin traza) | `ACTA_CIERRE_TEKTRON_v8.json` |

---

## FASE −1 — Inventario total del corpus (BLOQUEANTE)

**Objetivo:** revisar la Jetson entera — documentos, ubicaciones, estado, generaciones de índice, LLM Wiki — **antes** de curar o cerrar.

### Arranque rápido (recomendado)

En la Jetson, copiar `tektron_macro_scan.sh` a `/mnt/tektron/workspace/` y ejecutar:

```bash
bash /mnt/tektron/workspace/tektron_macro_scan.sh
# luego pegar en el chat:
#   /mnt/tektron/workspace/macro_*/MACRO_REPORT.txt
```

El script es **solo lectura**. Detalle manual adicional: `INVENTARIO_CORPUS_JETSON.md`.

Salidas mínimas obligatorias (vía script o playbook) en el directorio de inventario:

| Archivo | Pregunta que responde |
|---------|----------------------|
| `01_du_top.txt` | Qué pesa |
| `02_docs_mtime.tsv` / `02_corpus_docs.tsv` / `02_clacso_docs.tsv` | Qué documentos hay y dónde |
| `03_wiki_files.txt` + `03_origin_refs.txt` | ¿Existe la Wikipedia/GitHub de conocimiento general? |
| `04_chunks_inventory.txt` + `04_meta_dump.txt` | Todas las generaciones de índice |
| `05_*` | ¿Corpus desconectado del índice vivo? |
| `06_generaciones.txt` | pre_f15 vs l1 vs unificado |
| `09_probes_*.txt` | Qué falta descargar vs qué solo falta reindexar |
| `10_CORPUS_INVENTORY_REPORT.json` | Hipótesis + siguiente acción |

**Regla de decisión post-inventario:**

| Caso | Acción |
|------|--------|
| PDF en disco, 0 en índice | **Reindexar** (corpus intacto; puente roto) |
| 0 en disco, 0 en índice, probe ENTRA | **Descargar / agregar** |
| Wikipedia/ZIM/wiki-rag encontrada | Namespace `GENERAL` aparte; no mezclar en L1 |
| Wikipedia chunks dentro de `index_l1` | Contaminación → sacar a GENERAL o FUERA |
| Índice unificado mal construido, corpus intacto | No tocar corpus; reconstruir índice desde fuentes |

Solo con `$INV/10_CORPUS_INVENTORY_REPORT.json` firmado se pasa a Fase 0 / 0b.

---

## FASE 0 — Inventario de verdad de índices (BLOQUEANTE)

**Objetivo:** saber qué hay en disco vs qué sirve el bridge. Sin interpretación. Completar/cruzar con Fase −1.

### 0.1 Contar índices

```bash
cd /mnt/tektron
for m in \
  index_l1/meta.json \
  index_l1_precuracion_20260819/meta.json \
  _snapshots/l1_gate_20260807/index_l1/meta.json \
  _snapshots/pre_cierre_20260818/index_l1/meta.json
do
  echo "── $m"
  python3 -c "import json;d=json.load(open('$m'));print({k:d.get(k) for k in ['n_chunks','n_sit','n_heg','n_tec','created_utc']})"
done
```

### 0.2 Sumar graneros pre_f15

```bash
for f in $(find /mnt/tektron/_archivo/corpus_pre_f15_20260814 -name "chunks.jsonl"); do
  printf "%8d  %s\n" $(wc -l < "$f") "$f"
done | sort -rn
echo "─── TOTAL ───"
find /mnt/tektron/_archivo/corpus_pre_f15_20260814 -name "chunks.jsonl" -exec cat {} + | wc -l
```

### 0.3 Bytes y documentos fuente

```bash
du -sh /mnt/tektron/corpus /mnt/tektron/_clacso_archivo /mnt/tektron/_archivo /mnt/tektron/index_l1
find /mnt/tektron/corpus -type f \( -iname "*.pdf" -o -iname "*.txt" -o -iname "*.md" -o -iname "*.epub" \) | wc -l
find /mnt/tektron/_clacso_archivo -type f -iname "*.pdf" | wc -l
```

### 0.4 Hallar otros índices

```bash
find /mnt/tektron -name "chunks.jsonl" -o -name "faiss.idx" -o -name "*unificado*" 2>/dev/null | head -80
```

### 0.5 Emitir reporte (obligatorio)

Escribir `CORPUS_CONNECTIVITY_REPORT.json`:

```json
{
  "index_l1_n_chunks": null,
  "precuracion_n_chunks": null,
  "pre_f15_total_chunks": null,
  "fase3_reclamado": 60652,
  "delta_explicado": false,
  "bytes_corpus_gb": null,
  "bytes_clacso_gb": null,
  "docs_corpus": null,
  "docs_clacso": null,
  "fuentes_en_indice": null,
  "hipotesis": "DESCONECTADO | DELGADO | CIFRA_ERRONEA",
  "siguiente_fase": "0b_reconectar | 1_probes | STOP"
}
```

**Stop-ship** si `|reclamado − medido| / reclamado > 0.05` y `delta_explicado == false`.

### 0.6 Rama según hipótesis

| Hipótesis | Acción |
|-----------|--------|
| DESCONECTADO | Fase 0b: reconectar material ENTRA → índice (antes de curar) |
| DELGADO | Fase 0b: plan de población por ancla (no más purga) |
| CIFRA_ERRONEA | Corregir Arquitectura/Acta; continuar con medido como verdad |

---

## FASE 0b — Reconexión / población (BLOQUEANTE si DESCONECTADO o DELGADO)

**Objetivo:** maximizar densidad dual. Orden: **poblar → etiquetar → luego FUERA**.

### 0b.1 Prioridad de ingestión

1. Textos MCC y conceptos propios (grieta generativa, certeza sin sustancia, soberanía cognitiva, árbol de espejos, MCC 4 capas).
2. CLACSO / Epistemologías del Sur → polo SIT + `ancla_id`.
3. Marcos normativos faltantes por ancla (Ley Minera, Convenio 169, Nagoya, CPEUM, …) → HEG.
4. Pares extractivismo/resistencia linkeados por `ancla_id`.
5. TEC: NOMs / Siemens / Modbus como Procedure Cards (SOPRAG), con version pin.

### 0b.2 Regla de ancla

No indexar un documento HEG o SIT “suelto” si el mapa exige espejo: crear o registrar el hueco como `FALTA_POLO` en `dual_density_por_ancla.tsv`.

### 0b.3 Criterio de salida de 0b

- Probes MCC ≥ 1 hit cada uno **o** archivo fuente MCC indexado verificable.
- Al menos N anclas del mapa (definir N en acta; mínimo las de Gate G1–G5 + extractivismo + Quijano) con plan HEG+SIT (presente o `FALTA_POLO` explícito).

---

## FASE 1 — Probes MCC y mapa ENTRA (BLOQUEANTE)

```bash
for term in "grieta generativa" "certeza sin sustancia" "soberanía cognitiva" "árbol de espejos" "descentramiento" "calibración contextual"; do
  echo -n "$term: "
  grep -ci "$term" /mnt/tektron/index_l1/chunks.jsonl || true
done
```

Emitir `mcc_probe_hits.json`. Si alguno crítico = 0 → volver a 0b. **No** clasificar como N0 en Gate.

Inventario de fuentes por polo (509 o el número actual) → `inventario_polos_v8.tsv`.

---

## FASE 2 — Curación equilibrada (ENTRA + NO ENTRA)

**Objetivo:** filtrar basura **y** corregir polos **sin reducir** cobertura de anclas.

### 2.1 Acciones permitidas

| Acción | Cuándo |
|--------|--------|
| KEEP | Cumple punto 5 ENTRA |
| REETIQUETAR | Polo invertido (ej. Quijano HEG → SIT) |
| FUERA | Basura metadatos, 404, enciclopedia genérica sin disputa |
| FALTA_POLO | Ancla del mapa sin contraparte — **no borrar el polo existente** |
| REVISION_MANUAL | No clasificable — humano decide |

### 2.2 Prohibiciones

- No eliminar FUERA masivo sin revisión de impacto en anclas del Gate.
- No reetiquetar por keyword débil (`comunidad`→SIT, `ley`→HEG) sin muestra humana.
- No declarar Fase 2 OK si solo se ejecutó la mitad NO ENTRA.

### 2.3 Salida

- `curacion_asignacion_v8.csv`
- Nuevo `index_l1` con backup + manifest SHA-256
- `meta.json` actualizado con `n_chunks, n_heg, n_sit, n_tec` **reales**

---

## FASE 3 — Índice como verdad operativa

1. Rebuild FAISS + BM25 desde `chunks.jsonl` curado.
2. Swap atómico con rollback (`index_l1_precuracion_*` intacto).
3. Actualizar Arquitectura: Fase 3 = número **medido**, nunca 60 652 heredado sin traza.
4. Hash SHA-256 de `chunks.jsonl` + `faiss.idx` → `manifest_index_l1.json`.

---

## FASE 4 — Gate de capacidad (NO de silencio)

### 4.1 Función de score

```
J = α·TreeCoverage + β·DualPoleDensity + γ·TensionFaithfulness
  + δ·HonestMono + ε·EvidenceIntegrity
  − λ·FalseN0 − μ·Synthesis − ν·PoloMislabel
```

Constraint: `TrueN0 ≥ floor` (no entra en J como premio).

### 4.2 Separabilidad N0

Canales **separados y normalizados** (z-score o percentil):

- `s_dense`, `s_bm25_z`, `s_concept` (lexicón MCC/ENTRA), `s_pole`

N0 solo si: todos bajo umbral **y** top-k irrelevante **y** no es probe ENTRA.  
Si probe ENTRA = 0 → `INDEX_GAP`.

### 4.3 Batería mínima (capacidad)

| ID | Consulta | Éxito = |
|----|----------|---------|
| G1 | Ley Minera / consulta previa | DUAL: HEG+SIT, tensión, MCC, SHA |
| G2 | Quijano / colonialidad | MONO_SIT o DUAL si hay HEG real; Quijano ≠ HEG |
| G3 | Siemens S7 bloque de datos | TEC exacto, sin dualidad |
| G4 | ¿Qué es el MCC? | Análisis grounded; **fallo si INDEX_GAP o 0 fuentes** |
| G5 | ¿Quién descubrió América? | DUAL (HEG Colón vs SIT pueblos) o MONO honesto; no síntesis |
| G6–G8 | Negativas OOD (pozole, ajedrez, clima Oslo) | N0 correcto (solo floor) |
| G9 | Probe `grieta generativa` | hit>0 + uso en análisis |
| G10 | Polo trap Quijano | PoloMislabel = 0 |

### 4.4 Criterio de aprobación

- TreeCoverage medio en DUAL ≥ umbral acordado (ej. ≥ 0.8 en slots `{HEG,SIT,TENSION,MCC,SHA}`).
- `FalseN0Rate ≤ ε` (G1–G5, G9 no pueden ser N0).
- `TrueN0Rate ≥ floor` en G6–G8.
- `PoloMislabel = 0` en traps.
- `SynthesisRate = 0`.
- **No** se aprueba por “alta abstención” ni “baja alucinación” solos.

### 4.5 Dashboard obligatorio

`resultados_gate_v8.json`: TreeCoverage, DualPoleDensity, FalseN0, TrueN0, INDEX_GAP, PoloMislabel, SynthesisRate, por-query kind.

---

## FASE 5 — Interfaz honesta (MCC en backend)

### 5.1 Modos de salida (excluyentes)

```json
{
  "modo": "DUAL | MONO_HEG | MONO_SIT | TECNICO | N0 | INDEX_GAP",
  "tesis": "...",
  "antitesis": "...",
  "tension": "...",
  "ausencia_polo": null,
  "preguntas_criticas": ["...", "..."],
  "evidencia_trazable": ["sha256:..."],
  "abstenido": false,
  "index_gap": false
}
```

### 5.2 MCC (4 capas)

1. Descentramiento — sesgos de forma y supuestos.
2. Contexto encarnado — variables del mundo real.
3. Verificación contra-intuitiva — escenarios de borde.
4. Resíntesis autónoma — **preguntas**, no soluciones ni síntesis de polos.

### 5.3 Smoke

`/analizar` para G1–G5 produce JSON válido; N0 solo en G6–G8; G4 no INDEX_GAP.

---

## FASE 6 — Acta de cierre

```json
{
  "proyecto": "TEKTRON v8.0",
  "fecha": "",
  "arquitecta": "Dolores Méndez Valdez",
  "funcion_objetivo": "MAX MirrorCoverage (N0=piso)",
  "fase_0_conectividad": {},
  "fase_0b_poblacion": {},
  "fase_1_probes_mcc": {},
  "fase_2_curacion": {},
  "fase_3_indice": {"n_chunks": null, "hash": null},
  "fase_4_gate": {"status": "OK|FAIL", "FalseN0": null, "TreeCoverage": null},
  "fase_5_interfaz": "OK|FAIL",
  "estado": "CERRADO|PENDIENTE",
  "prohibido_como_exito": ["abstencion_alta", "solo_NO_ENTRA", "60k_sin_traza"]
}
```

Firma solo si C1–C7.

---

## Orden estricto de ejecución

```
−1 Inventario TOTAL Jetson (INVENTARIO_CORPUS_JETSON.md)
→ 0 Índices / conectividad → 0b Reindexar o descargar ENTRA
→ 1 Probes MCC → 2 Curación equilibrada → 3 Índice+manifest
→ 4 Gate capacidad → 5 Interfaz MCC → 6 Acta
```

No saltar. No Gate antes de inventario de corpus. No Acta con cifras no medidas.

---

## Anti-patrones (lista de rechazo inmediato)

| Si aparece | Hacer |
|------------|--------|
| “Gate OK porque se abstuvo en negativas” | Rechazar; medir FalseN0 en positivas |
| Solo script FUERA sin población | Rechazar Fase 2 |
| “¿Qué es MCC?” → N0 como éxito | Marcar INDEX_GAP / FalseN0 |
| Umbral único sobre score BM25 mezclado | Recalibrar canales |
| Árbol vacío = árbol completo | Rechazar; TreeCoverage |
| 60 652 en acta sin archivo que sume eso | Corregir a medido |
| Síntesis / “ambos se complementan” | Hard fail SynthesisRate |

---

## Métricas tomadas de papers (adaptadas)

| Pieza | Uso en v8 |
|-------|-----------|
| Sufficient Context | Gate de suficiencia por (Q,C) |
| SABER 4-celdas + Score | Decisión DUAL/MONO/N0; no premiar silencio |
| ERA Overall F1 / anti-IDK | Constraint anti-sobre-abstención |
| RefusalBench FRR/CRS | Diagnóstico over-refusal (eval, no train objective) |
| GRACE Balanced Acc | Balance answerable/unanswerable |
| Curriculum-Aware metadata boost | Retrieval paralelo por polo |
| SOPRAG | Polo TEC |
| RGB / TRACe / FactScore | TreeCoverage + TensionFaithfulness |
| IslamicLegalBench pluralismo | Evaluar coherencia **dentro** de cada polo, no una gold única |

---

**Fin del protocolo v8.** Cierra cuando produce Árboles; calla solo cuando debe.
