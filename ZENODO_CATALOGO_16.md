# Catálogo Zenodo autoritativo TEKTRON

Fuente canónica: **Zenodo** (no CLACSO). Autora: Dolores Méndez Valdez / FronterIA-Lab.

**Estado 2026-08-20:** 15 PDFs + markdown en `corpus/andamiaje_propio/` → granero **`00_Core`** (Corpus Base / Andamiaje). Son pieza del sistema TEKTRON.

Instalación vía **`tektron_correccion_cierre.sh`** (plan: cuarentena → curar L1 → 00_Core → indexar → probes), no como paso aislado.

## Núcleo MCC (2) — respaldan el método

| Rol | DOI | En lote local |
|-----|-----|---------------|
| MCC marco / praxis | [10.5281/zenodo.17728016](https://doi.org/10.5281/zenodo.17728016) | sí |
| MCC protocolo operativo | [10.5281/zenodo.21500800](https://doi.org/10.5281/zenodo.21500800) | sí |

## Satélites MCC (2)

| DOI | Título | En lote |
|-----|--------|---------|
| [19932561](https://doi.org/10.5281/zenodo.19932561) | Certeza sin sustancia | sí |
| [18800211](https://doi.org/10.5281/zenodo.18800211) | La Grieta Generativa | sí |

## Corpus TEKTRON relacionado

| DOI | Título | En lote |
|-----|--------|---------|
| [17587819](https://doi.org/10.5281/zenodo.17587819) | Colonización de la Gramática / Olvido Estructural | sí |
| [17705442](https://doi.org/10.5281/zenodo.17705442) | MANUAL PARA LA SOBERANÍA COGNITIVA | sí |
| [18324469](https://doi.org/10.5281/zenodo.18324469) | Código Fuente del Sexto Sol / Tonalli | sí |
| [18491987](https://doi.org/10.5281/zenodo.18491987) | **Soberanía Cognitiva y Neuroderechos** | sí *(añadido; no estaba en lista previa)* |
| [18492979](https://doi.org/10.5281/zenodo.18492979) | IA de Borde / Tonalli Industria 4.0 | sí |
| [18529874](https://doi.org/10.5281/zenodo.18529874) | Geometría del Despojo | sí |
| [18652576](https://doi.org/10.5281/zenodo.18652576) | Auditoría BlackRock | **pendiente** (no en lote) |
| [18655577](https://doi.org/10.5281/zenodo.18655577) | TEKTRON IA de Borde… | sí |
| [18655897](https://doi.org/10.5281/zenodo.18655897) | Ofensiva del nombre / Anáhuac | sí |
| [18707186](https://doi.org/10.5281/zenodo.18707186) | Indio Yori… | sí *(PDF; Zenodo tenía .pages)* |
| [19639576](https://doi.org/10.5281/zenodo.19639576) | El fetiche y la herida | sí |
| [20404028](https://doi.org/10.5281/zenodo.20404028) | TEKTRON v4.0 | **pendiente** (no en lote) |
| [21500777](https://doi.org/10.5281/zenodo.21500777) | Grafo de la Aniquilación | sí |

## Layout en repo

```
corpus/andamiaje_propio/
  README.md
  zenodo/<record_id>/*.pdf + *.pdf.json
  zenodo/MANIFEST.tsv
  markdown/<record_id>/<record_id>.md   # texto extraído para indexar
```

## Sync Jetson + index

Usar el script maestro (prioridad al plan completo):

```bash
bash tektron_correccion_cierre.sh --dry-run
bash tektron_correccion_cierre.sh --fase all
```

Prioridad L1: núcleo MCC → satélites → resto.
