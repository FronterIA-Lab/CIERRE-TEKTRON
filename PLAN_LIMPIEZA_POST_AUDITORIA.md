# PLAN DE LIMPIEZA — post-auditoría 20260819_180138

**Host:** tektron@192.168.100.84  
**Regla:** cuarentenar primero (`mv`), nunca `rm -rf` a ciegas. Reindexar L1 después.

---

## Qué reveló la auditoría

| Señal | Cantidad | Lectura correcta |
|-------|----------|------------------|
| KEEP | 1869 | Base útil |
| BORRAR_CANDIDATO | 688 | **Mezcla** basura real + falsos positivos |
| REVISION | 116 | Casi todos `*_dup1_dup1*` en `_archivo/regla_*` |
| URL_META en disco | 196 | Scrapes web con frontmatter `url:` |
| HTTP_ERROR | 21 | Cloudflare / 404 / “Just a moment…” |
| FACEBOOK | 2 disco / 7 chunks L1 | Contaminación puntual |
| Contaminación L1 | ~53 URL_META + 56 HTTP_ERROR chunks | Ya está **dentro** del índice vivo |

### Falso positivo importante: `VACIO_CORTO`

Muchos PDF grandes (Galeano, Quijano, Fanon, CAMIMEX, Atrato, Sahagún, CLACSO) salieron como “vacío” porque el extractor no lee bien PDF escaneado/imagen. **No borrar esos PDF.** Solo cuarentenar si `pdftotext` + apertura manual confirman basura.

---

## Anatomía del desparramado (F12)

Cada granero vive en **3 capas** que se mezclaron:

```
Corpus_Tektron_F12/<granero>/
  raw/              ← PDF/fuentes (KEEP prioritario)
  markdown/         ← conversión; a menudo scrape con url:
  _archivo/
    regla_a_*/      ← copias *_dup1_dup1* (cuarentena)
    regla_c_*/      ← scrapes txt/md con url: + Cloudflare (basura)
```

Además: `pre_f15` ≈ espejo de F12; CLACSO duplica leyes (LGEEPA, LMin, Convenio169…).

---

## Capas de decisión

### A — BORRAR / CUARENTENA SEGURA (basura inequívoca)

1. **Scrapes fallidos** (Cloudflare, 404, Just a moment), ej.:
   - `LandPortal_Despojo_Territorial*` (“Just a moment…”)
   - `Elsevier_Declaracion_Americana*` (“Página no encontrada”)
   - `GSMA_*` (“Attention Required! | Cloudflare”)
2. **Tutoriales / ruido técnico en L1** (NO ENTRA):
   - `aaf9dabd2f0b3530_Home_-_FastAPI_Tutorial`
   - `84edc4bf69dee6e4_Изучаем_FastAPI…`
   - `13f1874490baba92_Tutorial_de_FastAPI…`
   - `3991f6135f641310_Tutorial_de_peticiones_HTTP…`
3. **Venvs / limpieza archivada** (solo espacio; no afectan L1):
   - `_archivo/limpieza_20260812/` (~16G con t3/t5)
   - `_archivo/venv_tektron_pre_f21_20260815/` (~5G)
4. **Facebook explícito** (si el archivo es solo meta social):
   - `_archivo/.../InformecriminalizacionFin.md` (flag FACEBOOK)

Destino: `/mnt/tektron/_archivo/cuarentena_20260820/`

### B — CUARENTENA DE DUPLICADOS (no borrar hasta confirmar original)

Todo bajo:

- `Corpus_Tektron_F12/_archivo/regla_a_*/*_dup1_dup1*`
- `Corpus_Tektron_F12/_archivo/regla_c_*/*_dup1_dup1*`

Si el mismo documento existe en `raw/` o `markdown/` limpio → el dup va a cuarentena.

### C — SACAR DEL ÍNDICE (aunque el PDF se conserve)

Fuentes en `04_index_l1_fuentes_contaminadas.tsv` que sean:

- stubs `url:` / Cloudflare
- FastAPI / tutorials HTTP
- home pages vacías (`OCMAL_Home` si solo es landing)

Acción: filtrar esas `fuente` de `chunks.jsonl` y reconstruir FAISS/BM25 (como `construir_index_curado.py`), **sin** re-embedder todo el corpus.

### D — NO TOCAR

| Qué | Por qué |
|-----|---------|
| `corpus/zim/` (17G) | Capa GENERAL |
| PDFs MCC en CLACSO corpora | Hay que **indexarlos**, no borrarlos |
| `raw/` de F12 con libros/leyes | Andamiaje |
| `index_unificado` 60 652 | Auditar después; no swap |
| Snapshots `_snapshots/` | Rollback |

### E — Andamiaje propio en Corpus Base (`00_Core`)

Los papers de la arquitecta **son** Corpus Base (Andamiaje), pieza 1 de TEKTRON: granero `00_Core` → `index_l1`.

Lote: `corpus/andamiaje_propio/`. Catálogo: `ZENODO_CATALOGO_16.md`.

| Prioridad | DOI | Rol |
|-----------|-----|-----|
| 1 | 17728016 | Núcleo MCC — marco |
| 1 | 21500800 | Núcleo MCC — protocolo |
| 2 | 19932561 / 18800211 | Satélites (certeza / grieta) |
| 3 | resto + 18491987 | Andamiaje TEKTRON |

Pendientes de archivo: `18652576`, `20404028`.

---

## Orden de ejecución (no invertir)

```
1. Cuarentena scrapes/dups/ruido
2. Expulsar contaminación de index_l1 + rebuild
3. Instalar papers en Corpus_Tektron_F12/00_Core
4. Indexar andamiaje en index_l1 (MCC primero)
5. Probes MCC / INDEX_GAP
6. Gate v8 (capacidad)
```

### Script maestro

```bash
scp tektron_correccion_cierre.sh tektron_indexar_andamiaje_l1.py \
    -r corpus/andamiaje_propio \
    tektron@192.168.100.84:/mnt/tektron/workspace/

ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_correccion_cierre.sh --dry-run'

ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_correccion_cierre.sh --fase all'
```

`--fase 1` … `--fase 5` o `--hasta 3` para cortar. `--dry-run` no mueve ni indexa.
---

## Comandos de cuarentena (solo mv; reversibles)

```bash
ssh tektron@192.168.100.84
cd /mnt/tektron
CQ=_archivo/cuarentena_20260820
mkdir -p "$CQ"/{scrapes_fallidos,dup_regla,fastapi_ruido,venvs_viejos,facebook}

# 1) Scrapes Cloudflare / Just a moment (ejemplos; ampliar con grep)
mkdir -p "$CQ/scrapes_fallidos"
find corpus/Corpus_Tektron_F12 -type f \( \
  -iname '*LandPortal_Despojo*' -o -iname '*Elsevier_Declaracion*' \
  -o -iname '*GSMA_Closing*' -o -iname '*GSMA_Rural*' \
\) -exec mv -n {} "$CQ/scrapes_fallidos/" \;

# 2) Duplicados regla_a / regla_c
mkdir -p "$CQ/dup_regla"
find corpus/Corpus_Tektron_F12/_archivo -type f -iname '*_dup1*' \
  -exec mv -n {} "$CQ/dup_regla/" \;

# 3) Venvs archivados (libera ~10–15G; opcional)
# mv _archivo/limpieza_20260812 "$CQ/venvs_viejos/"
# mv _archivo/venv_tektron_pre_f21_20260815 "$CQ/venvs_viejos/"
```

**Antes de tocar L1**, generar lista exacta de fuentes a expulsar:

```bash
# En la Jetson — fuentes FastAPI / tutoriales / stubs en index
grep -E 'FastAPI|Tutorial_de_|Just a moment|Attention Required|Página no encontrada|url: https' \
  index_l1/chunks.jsonl | \
  /mnt/tektron/venv_tektron/bin/python3 -c '
import sys,json
from collections import Counter
c=Counter()
for line in sys.stdin:
  try: d=json.loads(line); c[d.get("fuente","?")]+=1
  except: pass
for k,v in c.most_common(80): print(f"{v}\t{k}")
' | tee workspace/fuentes_a_expulsar_l1.tsv
```

Pegar aquí `fuentes_a_expulsar_l1.tsv` antes del filtrado del índice.

---

## Resumen ejecutivo

El problema no es “falta de archivos”: es **triple copia** (F12 + pre_f15 + CLACSO) + **capa de scrapes** (`url:` / Cloudflare) que **sí entró a L1**, más **MCC en CLACSO sin indexar**.

Limpieza = cuarentena de scrapes/dups + expulsar ruido de L1 + indexar MCC. Eso sí desbloquea el cierre orientado a Árboles.
