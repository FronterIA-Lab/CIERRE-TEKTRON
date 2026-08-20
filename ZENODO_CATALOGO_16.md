# Catálogo Zenodo autoritativo TEKTRON (16)

Fuente canónica: **Zenodo** (no CLACSO). Autora: Dolores Méndez Valdez / FronterIA-Lab.

Inventariado 2026-08-20 vía API Zenodo a partir de los DOIs que enviaste + expansión por `related_identifiers` y búsquedas (TEKTRON, Tonalli, IVAES, contrainsurgencia, etc.).

## Los 16

| # | Fecha | DOI | Título | Archivo principal |
|---|-------|-----|--------|-------------------|
| 1 | 2025-11-12 | [10.5281/zenodo.17587819](https://doi.org/10.5281/zenodo.17587819) | La Colonización de la Gramática y el Olvido Estructural… | PDF |
| 2 | 2025-11-25 | [10.5281/zenodo.17705442](https://doi.org/10.5281/zenodo.17705442) | MANUAL PARA LA SOBERANÍA COGNITIVA | PDF |
| 3 | 2025-11-26 | [10.5281/zenodo.17728016](https://doi.org/10.5281/zenodo.17728016) | El Método de Calibración Contextual como Práctica de Soberanía Cognitiva… | PDF |
| 4 | 2026-01-21 | [10.5281/zenodo.18324469](https://doi.org/10.5281/zenodo.18324469) | Código Fuente del Sexto Sol: Cibernética del Tonalli… | PDF |
| 5 | 2026-02-05 | [10.5281/zenodo.18492979](https://doi.org/10.5281/zenodo.18492979) | IA de Borde como Insurgencia Epistemológica… (Tonalli / Industria 4.0) | PDF |
| 6 | 2026-02-09 | [10.5281/zenodo.18529874](https://doi.org/10.5281/zenodo.18529874) | LA GEOMETRÍA DEL DESPOJO… | PDF |
| 7 | 2026-02-15 | [10.5281/zenodo.18652576](https://doi.org/10.5281/zenodo.18652576) | Auditoría de Integridad: ¿Es BlackRock el "Dueño" de México… | PDF |
| 8 | 2026-02-16 | [10.5281/zenodo.18655577](https://doi.org/10.5281/zenodo.18655577) | TEKTRON IA de Borde como Insurgencia Epistemológica | PDF *(versión nueva de 18492979)* |
| 9 | 2026-02-16 | [10.5281/zenodo.18655897](https://doi.org/10.5281/zenodo.18655897) | La ofensiva del nombre: Anáhuac… | PDF |
| 10 | 2026-02-20 | [10.5281/zenodo.18707186](https://doi.org/10.5281/zenodo.18707186) | Indio Yori – Teroyokori – Negro… | **solo .pages** (sin PDF) |
| 11 | 2026-02-27 | [10.5281/zenodo.18800211](https://doi.org/10.5281/zenodo.18800211) | La Grieta Generativa… | PDF |
| 12 | 2026-04-18 | [10.5281/zenodo.19639576](https://doi.org/10.5281/zenodo.19639576) | El fetiche y la herida… | PDF |
| 13 | 2026-04-30 | [10.5281/zenodo.19932561](https://doi.org/10.5281/zenodo.19932561) | Certeza sin sustancia… | PDF |
| 14 | 2026-05-27 | [10.5281/zenodo.20404028](https://doi.org/10.5281/zenodo.20404028) | TEKTRON v4.0… | PDF + tar.gz código (~1.1 GB, **omitido** por defecto) |
| 15 | 2026-07-22 | [10.5281/zenodo.21500800](https://doi.org/10.5281/zenodo.21500800) | MCC — Protocolo de Calibración Contextual para la Gramática Computacional | PDF |
| 16 | 2026-07-23 | [10.5281/zenodo.21500777](https://doi.org/10.5281/zenodo.21500777) | El Grafo de la Aniquilación… | PDF |

## Los 5 que enviaste

| DOI | Qué es |
|-----|--------|
| 21500800 | **MCC protocolo** (4 capas / 16 glifos; certeza sin sustancia, optimización silenciosa, sesgo de contexto) |
| 21500777 | **Grafo de la Aniquilación** (Palantir, extractivismo Sierra, RAG-edge) |
| 20404028 | **TEKTRON v4.0** (reporte + artefactos) |
| 19932561 | **Certeza sin sustancia** (IVAES / sesgo de confirmación) |
| 18800211 | **Grieta generativa** (colonialidad / sujeto no contemplado) |

## Script a ejecutar

```bash
# iMac → Jetson
scp ~/Downloads/tektron_zenodo_ingest.sh ~/Downloads/zenodo_dois.txt \
  tektron@192.168.100.84:/mnt/tektron/workspace/

# Jetson: primero solo inventario (seguro)
ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_zenodo_ingest.sh --scan-only'

# Jetson: descargar PDFs faltantes a 00_Core/raw/zenodo/
ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_zenodo_ingest.sh'

# Traer el reporte
LATEST=$(ssh tektron@192.168.100.84 \
  'ls -td /mnt/tektron/workspace/zenodo_ingest_* | head -1')
scp "tektron@192.168.100.84:${LATEST}/ZENODO_INGEST_REPORT.txt" ~/Downloads/
```

Destino por defecto: `/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/raw/zenodo/<record_id>/`

**No** indexa L1 todavía. Después: markdown → rebuild L1 → probes MCC.
