# Andamiaje propio TEKTRON (granero 00_Core)

Parte del **Corpus Base (Andamiaje)** — pieza 1 de la arquitectura fija.  
Integran el sistema final: MCC, soberanía cognitiva, borde, conceptos satélite.

Destino en Jetson:

```
/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/raw/zenodo/
/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/markdown/zenodo/
→ index_l1
```

## Contenido (15 PDFs + markdown)

Ver `zenodo/MANIFEST.tsv`.

### Núcleo MCC (definen el método)
| DOI | Paper |
|-----|-------|
| 10.5281/zenodo.17728016 | El Método de Calibración Contextual… |
| 10.5281/zenodo.21500800 | MCC — Protocolo… Gramática Computacional |

### Satélites + andamiaje TEKTRON
Grieta, certeza, Neuroderechos (`18491987`), grafo, Tonalli, etc.

Pendientes de archivo: BlackRock `18652576`, TEKTRON v4 `20404028`.

## Cómo instalar (prioridad: plan completo)

No usar sync aislado como primer paso. Usar el script maestro:

```bash
# 1) Scripts
scp tektron_correccion_cierre.sh tektron_indexar_andamiaje_l1.py \
    tektron@192.168.100.84:/mnt/tektron/workspace/

# 2) Papers (flag -r ANTES de la carpeta; obligatorio en macOS)
scp -r corpus/andamiaje_propio \
    tektron@192.168.100.84:/mnt/tektron/workspace/

# 3) Dry-run del plan
ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_correccion_cierre.sh --dry-run'

# 4) Ejecutar (fases 1→5)
ssh tektron@192.168.100.84 \
  'bash /mnt/tektron/workspace/tektron_correccion_cierre.sh --fase all'
```

Objetivo: maximizar Árboles de Espejos + MCC + SHA; N0 es piso.
