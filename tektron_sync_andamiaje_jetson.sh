#!/usr/bin/env bash
# =============================================================================
# Sync andamiaje propio (PDFs Zenodo locales) → Jetson 00_Core/raw/zenodo
# =============================================================================
# Uso (desde iMac, en el clone del repo o con CORPUS_SRC apuntando al zip):
#   bash tektron_sync_andamiaje_jetson.sh
#   HOST=tektron@192.168.100.84 bash tektron_sync_andamiaje_jetson.sh
#
# No indexa L1. Solo copia PDFs + MANIFEST + sidecars .json
# =============================================================================
set -euo pipefail

HOST="${HOST:-tektron@192.168.100.84}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${CORPUS_SRC:-$SCRIPT_DIR/corpus/andamiaje_propio/zenodo}"
DEST="${DEST:-/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/raw/zenodo}"

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: no existe $SRC" >&2
  exit 1
fi

MD_SRC="${MD_SRC:-$SCRIPT_DIR/corpus/andamiaje_propio/markdown}"
MD_DEST="${MD_DEST:-/mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/markdown/zenodo}"

echo "Sync PDFs $SRC  →  ${HOST}:${DEST}"
ssh "$HOST" "mkdir -p '$DEST' '$MD_DEST'"
rsync -av --progress "$SRC/" "${HOST}:${DEST}/"
if [[ -d "$MD_SRC" ]]; then
  echo "Sync markdown $MD_SRC  →  ${HOST}:${MD_DEST}"
  rsync -av --progress "$MD_SRC/" "${HOST}:${MD_DEST}/"
fi
echo "OK. Verifica:"
ssh "$HOST" "find '$DEST' -name '*.pdf' | wc -l; find '$MD_DEST' -name '*.md' 2>/dev/null | wc -l; ls '$DEST'/MANIFEST.tsv 2>/dev/null || true"
echo "Siguiente: index L1 (núcleo MCC primero: 17728016 + 21500800)."
