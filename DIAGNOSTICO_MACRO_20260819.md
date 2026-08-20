# DIAGNÓSTICO MACRO — Jetson tektron@192.168.100.84

**Fuente:** `macro_20260819_174154/MACRO_REPORT.txt`  
**Host:** tektron-desktop · SSD NVMe `TEKTRON_DATA` 916G (61G usados, 7%)

---

## Veredicto en una frase

El corpus **sí está** en el SSD; el sistema vivo sirve solo **11 640** chunks de `index_l1`. Los **60 652** existen en el índice unificado archivado y **nunca alimentan** el bridge. Los PDFs del MCC están en CLACSO y **no entraron** al índice vivo — por eso “¿Qué es el MCC?” falla.

---

## 1. Mapa físico (qué hay)

| Ubicación | Peso | Qué es |
|-----------|------|--------|
| `_archivo/` | 23G | Basura útil: limpiezas, venvs viejos, **índice unificado 60 652**, graneros pre_f15 |
| `corpus/` | 18G | Fuente viva: `Corpus_Tektron_F12/` (~559M útil) + **`zim/` 17G** |
| `_clacso_archivo/` | 5.8G | Zip/tar + `TEKTRON_EVALUACION_CLACSO/corpora` (PDFs MCC/Epistemologías) |
| `venv_tektron/` | 4.8G | Runtime |
| `models/` | 2.4G | Qwen3-4B |
| `index_l1/` | 114M | **Índice vivo** 11 640 |
| `index_l1_precuracion_20260819/` | 213M | Pre-curación 12 763 + retorno |

**Corpus F12 (andamiaje real):** graneros `00_Core` … `14_industrial` + carpetas `raw/` por granero (fuentes, no LLM Wiki).

**ZIM (17G, 4 archivos):** conocimiento general offline (Kiwix). Hay `fallback_zim.py`. **No es** el gist Karpathy. Vive aparte del L1 — correcto si no se mezcla.

---

## 2. Misterio 60 652 — RESUELTO

```
60652  /mnt/tektron/_archivo/index_unificado_minilm_20260818/chunks_unificados.jsonl
```

| Generación | Chunks | Rol |
|------------|--------|-----|
| **unificado MiniLM** (18 ago) | **60 652** | Segunda indexación; archivada; **desconectada del bridge** |
| precuración / snapshots | 12 763 | L1 antes de curar anoche |
| **index_l1 vivo** | **11 640** | Lo que sirve `/retrieve` (puerto 8000) |
| pre_f15 graneros (suma) | ~11 313 | Arquitectura anterior por granero |

Hipótesis confirmada: **DESCONECTADO**, no “delgado inexistente”. El bridge apunta a `index_l1` (11 640), no al unificado.

---

## 3. Desconexión corpus ↔ índice

| Árbol | PDFs | ≈ en índice | ≈ fuera | Nota |
|-------|------|-------------|---------|------|
| `corpus/` | 120 | 44 | 76 (63%) | Muchos `*_dup1_dup1.pdf` (duplicados de nombre) |
| `_clacso_archivo/` | 50 | 12 | 38 (76%) | **Aquí está el MCC en PDF** |

Misses críticos en CLACSO (PATH>0, INDEX=0 para el concepto):

- `Certeza sin sustancia sesgos de confirmación.pdf`
- `El Método de Calibración Contextual como Práctica de Soberanía Cognitiva….pdf`
- Quijano / Buen Vivir / Decolonialidad (parte puede estar bajo otro nombre en L1)

Probes:

| Concepto | PATH | INDEX | Lectura |
|----------|------|-------|---------|
| grieta generativa | 2 | **0** | INDEX_GAP |
| certeza sin sustancia | 2 | **0** | INDEX_GAP |
| soberanía cognitiva | 2 | **0** | INDEX_GAP |
| árbol de espejos | 0 | **0** | Falta fuente o nombre distinto |
| Quijano / Modbus / Siemens / CLACSO | >0 | >0 | Conectados (densidad unequal) |
| Convenio 169 / Ley Minera | 0 path name | >0 index | En índice bajo otro filename |

---

## 4. LLM Wiki (Karpathy)

**No está en el disco.** Sin gist, sin `index.md`/`log.md`/`SCHEMA.md`. Los `…/raw` son carpetas de granero F12/pre_f15, no la wiki compilada del patrón.  
→ Solo referencia externa; re-guardar el gist en `docs/referencia/` si quieres conservarlo. No bloquea el cierre.

---

## 5. Índice vivo (estado)

- chunks: **11 640** · HEG 3098 · SIT 7375 · TEC 1167 · fuentes 474  
- Graneros presentes en L1 (sí hay estructura F12 reflejada).  
- Quijano es la fuente #1 (761 chunks) — riesgo de desbalance / polo.  
- Curación anoche: 12 763 → 11 640 (purga NO ENTRA sin poblar MCC).

Servicios UP: `:8000` bridge_l1 · `:8001` backend · `:8080` llama Qwen3-4B.

---

## 6. Errores a corregir (prioridad para maximizar Árboles)

| # | Error | Acción |
|---|--------|--------|
| 1 | MCC/CLACSO en disco, 0 en L1 | **Indexar** PDFs MCC + Epistemologías de `_clacso_archivo/.../corpora` hacia L1 (polo SIT / TEC-MCC) |
| 2 | Unificado 60 652 desconectado | **No swap ciego.** Auditar calidad del unificado; si es ruido/MiniLM malo, no sustituir L1. Usarlo como *candidato* de chunks ENTRA faltantes, o reindexar desde F12+CLACSO limpio |
| 3 | ZIM 17G | Mantener como capa `GENERAL` vía `fallback_zim.py`; **no** volcar a L1 dual |
| 4 | Duplicados `*_dup1_dup1.pdf` | Deduplicar en corpus; no reindexar basura de nombre |
| 5 | `árbol de espejos` ausente | Crear/ingest documento MCC propio si no existe |
| 6 | Acta “60 652 funcionales” | Corregir: 60 652 = unificado archivado; vivo = 11 640 |

---

## 7. Plan inmediato (orden)

1. **Listar PDFs CLACSO corpora** y marcar ENTRA (MCC, Quijano, Epistemologías).  
2. **Ingestar solo esos** al pipeline de indexación L1 (sin tocar ZIM, sin swap unificado).  
3. Re-probar probes: `certeza sin sustancia`, `grieta generativa`, `soberanía cognitiva`, `¿Qué es el MCC?`.  
4. Auditar 20–50 chunks del unificado (¿basura web? ¿F12?). Decidir si se recupera material o se descarta.  
5. Deduplicar `*_dup1*` en `corpus/`.  
6. Recién entonces: curación equilibrada + Gate v8.

**No hacer ahora:** swap de `index_unificado` → `index_l1`; mezclar ZIM en L1; más purga FUERA sin poblar.
