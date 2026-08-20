# Catálogo Zenodo autoritativo TEKTRON (16)

Fuente canónica: **Zenodo** (no CLACSO). Autora: Dolores Méndez Valdez / FronterIA-Lab.

## Núcleo MCC (2) — respaldan el método

Estos dos papers **definen y respaldan el MCC**. Prioridad máxima de ingestión e indexación en L1 (andamiaje metodológico). No confundir con el resto del catálogo TEKTRON.

| Rol | Fecha | DOI | Título |
|-----|-------|-----|--------|
| **MCC — marco / praxis** | 2025-11-26 | [10.5281/zenodo.17728016](https://doi.org/10.5281/zenodo.17728016) | El Método de Calibración Contextual como Práctica de Soberanía Cognitiva: Un Marco para la Resistencia Epistémica Encarnada |
| **MCC — protocolo operativo** | 2026-07-22 | [10.5281/zenodo.21500800](https://doi.org/10.5281/zenodo.21500800) | MCC — Protocolo de Calibración Contextual para la Gramática Computacional |

- **17728016**: fundamento (4 movimientos, soberanía cognitiva, resistencia epistémica encarnada).
- **21500800**: especificación operativa (4 capas, 16 glifos; certeza sin sustancia, optimización silenciosa, sesgo de contexto implícito).

Probes bloqueantes del Gate deben anclarse a estos dos (p. ej. “¿Qué es el MCC?”).

## Corpus TEKTRON relacionado (14)

Los otros registros Zenodo son **andamiaje / contexto TEKTRON** (soberanía, borde, conceptos satélite). Entran al corpus base, pero **no sustituyen** ni “son” el MCC.

| # | Fecha | DOI | Título | Nota |
|---|-------|-----|--------|------|
| 1 | 2025-11-12 | [17587819](https://doi.org/10.5281/zenodo.17587819) | Colonización de la Gramática / Olvido Estructural | Teoría previa |
| 2 | 2025-11-25 | [17705442](https://doi.org/10.5281/zenodo.17705442) | MANUAL PARA LA SOBERANÍA COGNITIVA | Manual |
| 3 | 2026-01-21 | [18324469](https://doi.org/10.5281/zenodo.18324469) | Código Fuente del Sexto Sol / Tonalli | |
| 4 | 2026-02-05 | [18492979](https://doi.org/10.5281/zenodo.18492979) | IA de Borde / Tonalli Industria 4.0 | Ver también 18655577 |
| 5 | 2026-02-09 | [18529874](https://doi.org/10.5281/zenodo.18529874) | Geometría del Despojo | |
| 6 | 2026-02-15 | [18652576](https://doi.org/10.5281/zenodo.18652576) | Auditoría BlackRock | |
| 7 | 2026-02-16 | [18655577](https://doi.org/10.5281/zenodo.18655577) | TEKTRON IA de Borde… | Versión nueva de 18492979 |
| 8 | 2026-02-16 | [18655897](https://doi.org/10.5281/zenodo.18655897) | Ofensiva del nombre / Anáhuac | |
| 9 | 2026-02-20 | [18707186](https://doi.org/10.5281/zenodo.18707186) | Indio Yori… | Solo `.pages` |
| 10 | 2026-02-27 | [18800211](https://doi.org/10.5281/zenodo.18800211) | **Grieta generativa** | Concepto satélite MCC |
| 11 | 2026-04-18 | [19639576](https://doi.org/10.5281/zenodo.19639576) | El fetiche y la herida | |
| 12 | 2026-04-30 | [19932561](https://doi.org/10.5281/zenodo.19932561) | **Certeza sin sustancia** | Concepto satélite MCC |
| 13 | 2026-05-27 | [20404028](https://doi.org/10.5281/zenodo.20404028) | TEKTRON v4.0 | Arquitectura; PDF (+tar.gz omitido) |
| 14 | 2026-07-23 | [21500777](https://doi.org/10.5281/zenodo.21500777) | Grafo de la Aniquilación | Material / contrainsurgencia |

## Orden de ingestión recomendado

1. **Núcleo MCC** → `17728016` + `21500800` (primero; L1 obligatorio).
2. Conceptos satélite → `19932561` (certeza), `18800211` (grieta).
3. Resto del corpus TEKTRON (14−2 satélite = según curación).

## Script

Lista completa: `zenodo_dois.txt` (MCC marcado al inicio).

```bash
scp tektron_zenodo_ingest.sh zenodo_dois.txt \
  tektron@192.168.100.84:/mnt/tektron/workspace/

# Solo núcleo MCC (opcional):
# printf '%s\n' 10.5281/zenodo.17728016 10.5281/zenodo.21500800 > /tmp/mcc_dois.txt
# bash tektron_zenodo_ingest.sh --dois /tmp/mcc_dois.txt

ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_zenodo_ingest.sh --scan-only'
ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_zenodo_ingest.sh'
```

Destino: `/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/raw/zenodo/<record_id>/`
