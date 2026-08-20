# Andamiaje propio TEKTRON (papers de la arquitecta)

**Sí: estos papers son conocimiento ENTRA del corpus base** (polo SIT / metodología), no memoria de usuario.

Fuente de verdad: Zenodo + copias locales aquí. Destino operativo en Jetson:

`/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/raw/zenodo/`

## Contenido (15 PDFs entregados 2026-08-20)

Ver `zenodo/MANIFEST.tsv` (SHA-256 por archivo).

### Núcleo MCC (2)
| DOI | Paper |
|-----|-------|
| 10.5281/zenodo.17728016 | El Método de Calibración Contextual… |
| 10.5281/zenodo.21500800 | MCC — Protocolo… Gramática Computacional |

### Satélites MCC (2)
| DOI | Paper |
|-----|-------|
| 10.5281/zenodo.19932561 | Certeza sin sustancia |
| 10.5281/zenodo.18800211 | La Grieta Generativa |

### Corpus TEKTRON (11 en este lote)
Incluye **Neuroderechos** (`10.5281/zenodo.18491987`, no estaba en el catálogo previo de 16), Indio Yori en PDF, Colonización, Manual, Sexto Sol, IA de Borde, Geometría del Despojo, Anáhuac, Border IA, fetiche/herida, Grafo.

### Aún no en este lote (sí en `zenodo_dois.txt`)
- `10.5281/zenodo.18652576` — Auditoría BlackRock  
- `10.5281/zenodo.20404028` — TEKTRON v4.0 (reporte)

## Sync a la Jetson

```bash
# desde la máquina donde esté el repo (o zip de corpus/andamiaje_propio)
scp -r corpus/andamiaje_propio/zenodo \
  tektron@192.168.100.84:/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/raw/

# o script:
bash tektron_sync_andamiaje_jetson.sh
```

Luego: markdown → index L1 → probes MCC.
