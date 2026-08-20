# Análisis completo TEKTRON — maximizar capacidad de analista situado

**Criterio rector (sin sesgo de origen):** solo importa si una pieza aumenta la producción de Árboles de Espejos (HEG vs SIT en tensión SIN síntesis) + preguntas MCC + evidencia SHA-256. La abstención N0 es piso anti-confabulación, no meta.

**Fuentes:** Arquitectura Fija (README), ERROR CONSTANTE, ERRORES-ERROR-HISTORICO, PROTOCOLO v7.0 mal implementado, 15 papers del repositorio.

---

## 1. Objetivo del sistema (función a maximizar)

```
MAX J = capacidad_analista_situado
      = MirrorCoverage × DualPoleDensity × TensionFaithfulness × EvidenceIntegrity
```

sujeto a:

- `FalseN0 ≤ ε` (no callar cuando hay material)
- `TrueN0 ≥ floor` (no confabular cuando no hay)
- `SynthesisRate = 0` (prohibida la síntesis)
- `PoloMislabel = 0` en traps gold (Quijano ≠ HEG)

**Lo que NO se maximiza:** abstención, precisión corta, EM/F1, “error cero”. Un sistema que se abstiene siempre tiene error cero y valor cero (ERROR CONSTANTE).

### Outputs válidos (punto 2 Arquitectura)

| Caso | Salida | Valor |
|------|--------|-------|
| Contexto suficiente + ambos polos | Árbol completo (TESIS HEG vs ANTÍTESIS SIT) + MCC + SHA | máximo |
| Contexto suficiente + un polo | Análisis del polo + declaración explícita de ausencia del otro + MCC | alto (honesto) |
| Contexto insuficiente real | "No sé" + hash vacío | 0 capacidad; solo cuenta en piso de seguridad |
| Concepto ENTRA ausente del índice | INDEX_GAP (diagnóstico), no N0 exitoso | 0; remediación de corpus |

---

## 2. Diagnóstico del estado real (hechos del nodo)

| Hecho | Implicación para J |
|-------|-------------------|
| `index_l1` sirve 11 640 chunks (post-curación); Fase 3 reclamaba 60 652 | Corpus desconectado o cifra no trazable → densidad dual colapsada |
| `corpus/` 18 GB + `_clacso_archivo/` 5.8 GB vs índice ~114 MB | Material ENTRA no indexado → MirrorCoverage artificialmente baja |
| `pre_f15` graneros suman ~11 313 chunks (no ~60 652) | El 60 652 no es la suma de graneros; hay que hallar origen o corregir el acta |
| Hits MCC (`grieta generativa`, `certeza sin sustancia`, `soberanía cognitiva`, `árbol de espejos`) = 0 | CATEGORÍA ENTRA vacía → "¿Qué es el MCC?" = INDEX_GAP, no N0 correcto |
| Score compuesto no separable (BM25 sin normalizar) | Umbral global N0 inválido entre consultas |
| Curación ejecutó solo NO ENTRA (−1 123 chunks) | Índice más limpio y más pequeño; no pobló polos faltantes |
| Gate v7 midió silencio en negativas como éxito | Función objetivo invertida |

**Conclusión operativa:** el cuello de botella no es “más abstención” ni “más filtros FUERA”. Es **densidad dual por ancla** + **conectividad corpus→índice** + **Gate que premia árboles**.

---

## 3. Evaluación paper por paper (solo utilidad para J)

### 3.1 Abstención, honestidad, suficiencia

| Paper | Veredicto | Qué adoptar para MAXIMIZE |
|-------|-----------|---------------------------|
| **Sufficient Context** (ICLR 2025) | ADAPT | Autorater de suficiencia de (Q,C); curves coverage–accuracy. Advierte que abstener siempre baja rendimiento. N0 solo si ambos polos inviables. |
| **Trust or Abstain / SABER** | ADAPT | Decisión 4-celdas + Score (+1/−1/0) que **no premia callar**. Remapear PK/CK → HEG/SIT; en conflicto productivo emitir DUAL, no elegir uno. |
| **GRACE** | ADAPT | Datos suff/insuff + Balanced Acc (anti-especialización en rechazo). Rechazar path `<llm>` como sustituto de N0. |
| **ERA** | ADAPT | Cuadrantes KG/KN/UG/UN; Overall F1 Answer↔Abstain; preferencias que castigan IDK innecesario. |
| **RefusalBench** | ADAPT (eval) | CRS, FRR, MRR, taxonomía de incertidumbre. **No** como objective de train. Contradiction en TEKTRON → DUAL, no REFUSE. |
| **OCC-RAG** | ADAPT | Trazas citables + Status previo a respuesta. Extender Status a `{N0, HEG-only, SIT-only, DUAL}`. |

### 3.2 Pluralismo, dominio situado, polo técnico

| Paper | Veredicto | Qué adoptar |
|-------|-----------|-------------|
| **IslamicLegalBench** | ADAPT | Pluralismo sin respuesta única; tagging por tradición; false-premise/abstención. Descartar síntesis inter-escuela. |
| **Non-Western Culture Aware RAG** | REJECT | Intención alineada; densidad metodológica nula. |
| **Fair Access Food Data Africa** | ADAPT | Pipeline PDF→KG (ORKG) para ingesta SIT/CLACSO atrapada en PDF. |
| **Curriculum-Aware RAG** (technologies-14) | ADAPT | `Score_f = S_sem + S_metadata`; metadata-gated dual retrieval por polo (no fusión curricular). |
| **SOPRAG** | ADOPT (TEC) | Procedure Cards + expertos Entity/Causal/Flow para polo TÉCNICO sin relatividad. |
| **SayComply** | ADOPT/ADAPT | Jerarquía L1–L3 + compliance-first; tree-routing adaptable a ramas HEG∥SIT. |
| **Agent-Based Defense Maintenance** | ADAPT | Version pin + dual store texto/imagen para TEC. |

### 3.3 Encuestas de evaluación

| Paper | Veredicto | Qué adoptar |
|-------|-----------|-------------|
| **RAG Evaluation Survey** (Gan et al.) | ADAPT | Coverage/Comprehensiveness, Faithfulness+Citation, RGB (integration/noise/neg/counterfact), TRACe Completeness — redefinidos como slots del Árbol, no EM corto. |
| **Can LLMs Be Trusted…** (Brehme et al.) | ADAPT | Datasets domain-specific + noisy/misleading + **evaluación de indexing** (detecta desconexión 11 640 vs 60 652). |

### 3.4 Métricas estándar **hostiles** a TEKTRON si son objetivo primario

Accuracy/EM/F1 corto · BLEU/ROUGE · Answer Relevance sola · Faithfulness sin Completeness · Precision@K sin coverage de polos · Abstention rate / NegRejection como reward · Hallucination Rate minimizada sin KPR · score BM25+dense mezclado sin normalizar.

Usarlas solo como **constraints**, nunca como J.

---

## 4. Corpus ideal (definición)

### 4.1 Estructura por polo / granero

| Polo | Graneros obligatorios | Unidad | Metadata mínima |
|------|----------------------|--------|-----------------|
| **HEG** | Derecho positivo, tratados, DOF, discurso estatal/corporativo, concesiones | chunk normativo/narrativo | `{polo, fuente, jurisdicción, fecha, acto, ancla_id}` |
| **SIT** | Epistemologías del Sur, CLACSO, MCC, extractivismo/resistencia, saberes territoriales | chunk conceptual/caso | `{polo, tradición, territorio, caso, lengua, ancla_id}` |
| **TEC** | NOMs, Siemens/PLC, Modbus, SOPs | Procedure Card + grafos Entity/Causal/Flow | `{polo, norma, versión, equipo}` — sin dualidad |

### 4.2 Regla dura de dualidad

Toda consulta analítica (no TEC pura) recupera **pares espejo** sobre el mismo `ancla_id`:

- ≥1 evidencia HEG y ≥1 SIT → modo DUAL
- Solo un polo → MONO + declaración de ausencia
- Ninguno / irrelevante → N0
- Concepto ENTRA con 0 hits en índice → INDEX_GAP

**Densidad:** ratio operativo ≥ 1:1 HEG:SIT por ancla activa; profundidades comparables en (a) teórico, (b) casos, (c) vocabulario MCC.

### 4.3 Qué conectar ya (prioridad de indexación)

1. **Probes MCC y metodología propia** (hoy 0 hits) — bloqueante.
2. **`_clacso_archivo/` (5.8 GB)** — Epistemologías del Sur / extractivismo → SIT + `ancla_id` a leyes HEG.
3. **`corpus/` 18 GB** — clasificar HEG|SIT|TEC|ruido; indexar solo lo que alimente anclas o TEC ejecutable.
4. **`pre_f15` graneros** — ontología de anclas y schema; no mezclar HEG/SIT en índice plano sin namespaces.
5. **Pares documentales extractivismo** — concesión/ley ↔ asamblea/territorio/crítica.

### 4.4 Lo que los papers dan vs lo que falta investigar

| Ya aportan | Falta (prioridad) |
|------------|-------------------|
| Pluralismo + abstención tipada | Corpus HEG↔SIT linkeado por ancla con densidades balanceadas |
| Metadata-gated dual retrieval | Ontología ENTRA formal + router anti-síntesis |
| PDF→KG para Sur | Pipeline CLACSO a escala con citas/contra-citas |
| SOPRAG/SayComply para TEC | Corpus TEC MX/LATAM versionado (NOMs, Modbus, Siemens) |
| RGB/TRACe/FactScore adaptables | Benchmark TEKTRON: score = MirrorCoverage + fidelity por polo + FalseN0 |

**Veredicto de investigación:** no hace falta otro paper genérico de “RAG cultural”. Hace falta **construir el corpus espejado** y el **Gate de capacidad**. Los 15 papers bastan como caja de herramientas si se adaptan; el vacío es de datos y de función objetivo, no de literatura.

---

## 5. Combinación técnica óptima (stack)

```
Router de polo
  → retrieval paralelo HEG ∥ SIT (metadata-boost curriculum-aware)
  → (TEC) SOPRAG Entity/Causal/Flow + version pin
  → Gate suficiencia (Sufficient Context + canales normalizados)
  → Decisión 4-celdas remapeada (SABER):
       C00 → N0
       C10 → MONO_HEG
       C01 → MONO_SIT
       C11 / conflicto productivo → DUAL (Árbol, sin síntesis)
  → MCC 4 capas + SHA-256
  → Eval: MirrorCoverage + DualPoleDensity + FRR/CRS (RefusalBench) + Balanced Acc
```

**Anti-silencio en train/eval:** preferencias ERA KG/KN, Score SABER, Balanced Acc GRACE, FRR RefusalBench. Contradiction → DUAL.

---

## 6. Error histórico (para no repetirlo)

1. Convertir N0 en criterio de éxito.
2. Ejecutar solo NO ENTRA (purga sin población).
3. Tratar 60 652 vs 11 640 como nota contable, no como hipótesis bloqueante.
4. Llamar “correcto” a fallo de recuperación de MCC.
5. Permitir salidas cómodas (síntesis vacía, `misma_estructura=false`).

**Corrección:** Gate mide cuántas estructuras del mapa producen árbol completo. Abstención es piso. Corpus se mide por conectividad y densidad dual, no por chunks eliminados.
