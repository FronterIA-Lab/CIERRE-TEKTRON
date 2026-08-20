#!/usr/bin/env bash
# =============================================================================
# TEKTRON — script de CORRECCIÓN de cierre (plan completo)
# =============================================================================
# Objetivo del sistema (README / ANALISIS):
#   MAXIMIZAR capacidad de analista situado:
#   Árboles de Espejos (HEG↔SIT, sin síntesis) + preguntas MCC + SHA-256.
#   N0 = piso anti-confabulación, no meta.
#
# Arquitectura (README — piezas):
#   1. Corpus Base (Andamiaje) → index_l1   ← aquí viven los papers propios
#   2. Memoria del Usuario (externa)        ← este script NUNCA la toca
#   3. MCC / N0 / frontend-backend
#
# Los papers de la arquitecta SON andamiaje del sistema final (granero 00_Core),
# parte de TEKTRON — no un anexo paralelo.
#
# Orden (prioridad del plan — NO invertir):
#   FASE 1  Cuarentena scrapes / dups / ruido
#   FASE 2  Expulsar contaminación de index_l1 + rebuild
#   FASE 3  Instalar papers en Corpus_Tektron_F12/00_Core
#   FASE 4  Indexar andamiaje (MCC primero) en index_l1
#   FASE 5  Probes MCC / INDEX_GAP
#
# Host: tektron@192.168.100.84 · ROOT=/mnt/tektron
#
# Desde iMac (flags scp ANTES de los archivos; macOS OpenSSH):
#   cd ~/Downloads/CIERRE-TEKTRON
#   scp tektron_correccion_cierre.sh tektron_indexar_andamiaje_l1.py \
#       tektron@192.168.100.84:/mnt/tektron/workspace/
#   scp -r corpus/andamiaje_propio \
#       tektron@192.168.100.84:/mnt/tektron/workspace/
#   ssh tektron@192.168.100.84 \
#     'bash /mnt/tektron/workspace/tektron_correccion_cierre.sh --dry-run'
#   ssh tektron@192.168.100.84 \
#     'bash /mnt/tektron/workspace/tektron_correccion_cierre.sh --fase all'
#
# Fases sueltas:
#   --fase 1|2|3|4|5|all
#   --hasta 3          # ejecuta 1..3
#   --dry-run
# =============================================================================

set -euo pipefail

ROOT="${TEKTRON_ROOT:-/mnt/tektron}"
HOST_HINT="tektron@192.168.100.84"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="${ROOT}/workspace/correccion_${TS}"
CQ="${ROOT}/_archivo/cuarentena_20260820"
F12="${ROOT}/corpus/Corpus_Tektron_F12"
CORE="${F12}/00_Core"
L1="${ROOT}/index_l1"
PY="${ROOT}/venv_tektron/bin/python3"
command -v "$PY" >/dev/null 2>&1 || PY="$(command -v python3)"

DRY=0
FASE="all"
HASTA=""
ANDAMIAJE_SRC="${ANDAMIAJE_SRC:-}"
# Resolver andamiaje: env, workspace/andamiaje_propio (scp -r), o repo clone
if [[ -z "$ANDAMIAJE_SRC" ]]; then
  for cand in \
    "${SCRIPT_DIR}/andamiaje_propio" \
    "${SCRIPT_DIR}/corpus/andamiaje_propio" \
    "${ROOT}/workspace/andamiaje_propio" \
    "${ROOT}/corpus/andamiaje_propio"
  do
    if [[ -d "$cand/zenodo" ]]; then ANDAMIAJE_SRC="$cand"; break; fi
  done
  ANDAMIAJE_SRC="${ANDAMIAJE_SRC:-$SCRIPT_DIR/andamiaje_propio}"
fi

usage() { sed -n '2,45p' "$0" | sed 's/^# \?//'; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --fase) FASE="$2"; shift 2 ;;
    --hasta) HASTA="$2"; shift 2 ;;
    --andamiaje) ANDAMIAJE_SRC="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT" 2>/dev/null || { OUT="/tmp/tektron_correccion_${TS}"; mkdir -p "$OUT"; }
REPORT="$OUT/CORRECCION_REPORT.txt"
log() { printf '%s\n' "$*" | tee -a "$REPORT"; }
run() {
  if [[ "$DRY" -eq 1 ]]; then
    log "DRY> $*"
  else
    log "RUN> $*"
    eval "$@"
  fi
}

should_run() {
  local n="$1"
  if [[ -n "$HASTA" ]]; then
    [[ "$n" -le "$HASTA" ]] && return 0 || return 1
  fi
  case "$FASE" in
    all) return 0 ;;
    "$n") return 0 ;;
    *) return 1 ;;
  esac
}

# --- Hard guards: memoria_usuario fuera de alcance ---
assert_no_memoria_usuario() {
  local p
  for p in "$@"; do
    if [[ "$p" == *memoria_usuario* ]]; then
      log "ABORT: ruta toca memoria_usuario (fuera de alcance de este script): $p"
      exit 3
    fi
  done
}
assert_no_memoria_usuario "$CORE" "$L1" "$CQ" "$ANDAMIAJE_SRC" "$OUT"

log "=== TEKTRON corrección de cierre ==="
log "fecha:   $(date -Is)"
log "host:    $(hostname 2>/dev/null || echo '?')  (esperado Jetson $HOST_HINT)"
log "root:    $ROOT"
log "fase:    $FASE  hasta=${HASTA:-—}  dry=$DRY"
log "objetivo: MAX Árboles de Espejos + MCC + SHA; N0=piso"
log "andamiaje papers → Corpus Base / granero 00_Core → index_l1"
log "salida:  $OUT"
log ""

# =============================================================================
# FASE 0 — Preflight arquitectura
# =============================================================================
fase0() {
  log "── FASE 0 · Preflight ──"
  local ok=1
  for p in "$ROOT" "$F12" "$L1"; do
    if [[ -e "$p" ]]; then log "  OK path $p"
    else log "  FALTA $p"; ok=0; fi
  done
  if [[ -f "$L1/chunks.jsonl" ]]; then
    local n; n=$(wc -l < "$L1/chunks.jsonl" | tr -d ' ')
    log "  index_l1 chunks: $n"
  else
    log "  AVISO: no hay $L1/chunks.jsonl"
  fi
  if [[ -d "$ANDAMIAJE_SRC/zenodo" ]]; then
    local np; np=$(find "$ANDAMIAJE_SRC/zenodo" -name '*.pdf' | wc -l | tr -d ' ')
    log "  andamiaje PDFs en src: $np"
  else
    log "  AVISO: no está $ANDAMIAJE_SRC/zenodo (fase 3 fallará sin sync previo)"
  fi
  # Nunca listar/editar memoria_usuario
  if [[ -e "$ROOT/memoria_usuario.json" ]]; then
    log "  (memoria_usuario.json existe — se deja intacta; fuera de alcance)"
  fi
  [[ "$ok" -eq 1 ]] || log "  Preflight con rutas faltantes — continúa con lo disponible"
  log ""
}
fase0

# =============================================================================
# FASE 1 — Cuarentena (plan A/B)
# =============================================================================
if should_run 1; then
  log "── FASE 1 · Cuarentena scrapes / dups / ruido ──"
  run "mkdir -p '$CQ'/{scrapes_fallidos,dup_regla,fastapi_ruido,venvs_viejos,facebook,misc}"

  # Scrapes conocidos + patrones HTTP error en markdown F12
  if [[ "$DRY" -eq 1 ]]; then
    log "DRY> find scrapes Cloudflare/404/Just a moment → $CQ/scrapes_fallidos"
    find "$F12" -type f \( \
      -iname '*LandPortal_Despojo*' -o -iname '*Elsevier_Declaracion*' \
      -o -iname '*GSMA_Closing*' -o -iname '*GSMA_Rural*' \
    \) 2>/dev/null | head -50 | tee -a "$OUT/fase1_scrapes_candidatos.txt" || true
  else
    find "$F12" -type f \( \
      -iname '*LandPortal_Despojo*' -o -iname '*Elsevier_Declaracion*' \
      -o -iname '*GSMA_Closing*' -o -iname '*GSMA_Rural*' \
    \) -exec mv -n {} "$CQ/scrapes_fallidos/" \; 2>/dev/null || true
  fi

  # Contenido Cloudflare / Just a moment en markdown (solo archivos pequeños texto)
  "$PY" - "$F12" "$CQ" "$DRY" "$OUT" <<'PY' || true
import os, shutil, sys
from pathlib import Path
f12, cq, dry, out = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]=="1", Path(sys.argv[4])
dest = cq / "scrapes_fallidos"
dest.mkdir(parents=True, exist_ok=True)
needles = ("Just a moment", "Attention Required", "Página no encontrada", "cf-browser-verification")
moved = []
for p in f12.rglob("*"):
    if not p.is_file():
        continue
    if p.suffix.lower() not in {".md", ".txt", ".html"}:
        continue
    if p.stat().st_size > 200_000:
        continue
    try:
        t = p.read_text(encoding="utf-8", errors="ignore")[:4000]
    except Exception:
        continue
    if any(n in t for n in needles):
        moved.append(str(p))
        if not dry:
            shutil.move(str(p), str(dest / p.name))
(out/"fase1_http_error_moved.txt").write_text("\n".join(moved)+"\n", encoding="utf-8")
print(f"http_error_candidates={len(moved)}")
PY

  # Duplicados *_dup1*
  if [[ "$DRY" -eq 1 ]]; then
    find "$F12" -type f -iname '*_dup1*' 2>/dev/null | head -80 | tee "$OUT/fase1_dup_candidatos.txt" || true
  else
    find "$F12" -type f -iname '*_dup1*' -exec mv -n {} "$CQ/dup_regla/" \; 2>/dev/null || true
  fi

  log "  Cuarentena: $CQ"
  log "  Lista HTTP errors: $OUT/fase1_http_error_moved.txt"
  log ""
fi

# =============================================================================
# FASE 2 — Curar index_l1 (expulsar contaminación)
# =============================================================================
if should_run 2; then
  log "── FASE 2 · Expulsar contaminación de index_l1 ──"
  if [[ ! -f "$L1/chunks.jsonl" ]]; then
    log "  SKIP: no hay chunks.jsonl"
  else
    SNAP="${ROOT}/_snapshots/pre_correccion_l1_${TS}"
    run "mkdir -p '$SNAP' && cp -a '$L1/chunks.jsonl' '$SNAP/' && cp -a '$L1/meta.json' '$SNAP/' 2>/dev/null || true"

    "$PY" - "$L1" "$OUT" "$DRY" <<'PY'
import json, re, sys
from pathlib import Path
from collections import Counter
l1, out, dry = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]=="1"
chunks = l1/"chunks.jsonl"
pat = re.compile(
    r"FastAPI|Tutorial_de_|Just a moment|Attention Required|Página no encontrada|"
    r"cf-browser-verification|Изучаем_FastAPI|Tutorial_de_peticiones",
    re.I,
)
# also drop obvious url-stub fuentes if text starts with url: only
keep, drop = [], Counter()
for line in chunks.read_text(encoding="utf-8", errors="ignore").splitlines():
    if not line.strip():
        continue
    try:
        d = json.loads(line)
    except Exception:
        keep.append(line)
        continue
    fuente = str(d.get("fuente") or d.get("source") or "")
    text = str(d.get("text") or d.get("contenido") or "")[:500]
    bad = bool(pat.search(fuente) or pat.search(text))
    if text.strip().startswith("url:") and len(text) < 400:
        bad = True
    if bad:
        drop[fuente or "?"] += 1
    else:
        keep.append(json.dumps(d, ensure_ascii=False))

(out/"fase2_fuentes_expulsadas.tsv").write_text(
    "count\tfuente\n" + "\n".join(f"{v}\t{k}" for k,v in drop.most_common()) + "\n",
    encoding="utf-8",
)
print(f"keep={len(keep)} drop_chunks={sum(drop.values())} drop_fuentes={len(drop)}")
if not dry:
    bak = chunks.with_suffix(".jsonl.bak_correccion")
    chunks.replace(bak)
    chunks.write_text("\n".join(keep) + ("\n" if keep else ""), encoding="utf-8")
    print(f"wrote {chunks} (bak={bak})")
PY

    # Rebuild FAISS/BM25 si existe el constructor local
    if [[ -f "$ROOT/construir_index_curado.py" ]]; then
      run "cd '$ROOT' && '$PY' construir_index_curado.py --from-chunks '$L1/chunks.jsonl' --out '$L1' 2>&1 | tee '$OUT/fase2_rebuild.log' || true"
      # Si abortó por desfase faiss≠jsonl, rebuild total:
      REBUILD="$SCRIPT_DIR/tektron_rebuild_faiss_from_chunks.py"
      [[ -f "$REBUILD" ]] || REBUILD="$ROOT/workspace/tektron_rebuild_faiss_from_chunks.py"
      if [[ -f "$REBUILD" ]]; then
        log "  Intentando rebuild FAISS desde jsonl…"
        run "'$PY' '$REBUILD' --root '$ROOT' 2>&1 | tee '$OUT/fase2_faiss_rebuild.log' || true"
      fi
    else
      log "  AVISO: no hay construir_index_curado.py — usar tektron_rebuild_faiss_from_chunks.py"
    fi
  fi
  log ""
fi

# =============================================================================
# FASE 3 — Instalar papers en Corpus Base (00_Core)
# =============================================================================
if should_run 3; then
  log "── FASE 3 · Instalar andamiaje propio en 00_Core ──"
  assert_no_memoria_usuario "$CORE/raw/zenodo" "$CORE/markdown/zenodo"
  if [[ ! -d "$ANDAMIAJE_SRC/zenodo" ]]; then
    log "  ERROR: falta $ANDAMIAJE_SRC/zenodo"
    log "  Desde iMac (en ~/Downloads/CIERRE-TEKTRON):"
    log "    scp -r corpus/andamiaje_propio tektron@192.168.100.84:/mnt/tektron/workspace/"
    log "  Debe quedar: /mnt/tektron/workspace/andamiaje_propio/zenodo/"
    exit 4
  fi
  run "mkdir -p '$CORE/raw/zenodo' '$CORE/markdown/zenodo'"
  if command -v rsync >/dev/null 2>&1; then
    run "rsync -a '$ANDAMIAJE_SRC/zenodo/' '$CORE/raw/zenodo/'"
    [[ -d "$ANDAMIAJE_SRC/markdown" ]] && run "rsync -a '$ANDAMIAJE_SRC/markdown/' '$CORE/markdown/zenodo/'"
  else
    run "cp -a '$ANDAMIAJE_SRC/zenodo/.' '$CORE/raw/zenodo/'"
    [[ -d "$ANDAMIAJE_SRC/markdown" ]] && run "cp -a '$ANDAMIAJE_SRC/markdown/.' '$CORE/markdown/zenodo/'"
  fi
  # Manifest de instalación
  find "$CORE/raw/zenodo" -name '*.pdf' 2>/dev/null | sort | tee "$OUT/fase3_pdfs_instalados.txt" | wc -l | tee -a "$REPORT"
  find "$CORE/markdown/zenodo" -name '*.md' 2>/dev/null | sort | tee "$OUT/fase3_mds_instalados.txt" | wc -l | tee -a "$REPORT"
  log "  Destino andamiaje: $CORE/raw|markdown/zenodo/"
  log ""
fi

# =============================================================================
# FASE 4 — Indexar andamiaje en L1 (MCC primero)
# =============================================================================
if should_run 4; then
  log "── FASE 4 · Indexar andamiaje en index_l1 (MCC primero) ──"
  INDEXER="$SCRIPT_DIR/tektron_indexar_andamiaje_l1.py"
  [[ -f "$INDEXER" ]] || INDEXER="$ROOT/workspace/tektron_indexar_andamiaje_l1.py"
  if [[ ! -f "$INDEXER" ]]; then
    log "  ERROR: falta tektron_indexar_andamiaje_l1.py junto al script"
    exit 5
  fi
  EXTRA=()
  [[ "$DRY" -eq 1 ]] && EXTRA+=(--dry-run)
  run "'$PY' '$INDEXER' --root '$ROOT' --core '$CORE' --out-report '$OUT/fase4_index.json' ${EXTRA[*]:-}"
  log ""
fi

# =============================================================================
# FASE 5 — Probes (INDEX_GAP vs hits)
# =============================================================================
if should_run 5; then
  log "── FASE 5 · Probes MCC / conceptos ──"
  "$PY" - "$L1" "$OUT" <<'PY'
import json, re, sys
from pathlib import Path
l1, out = Path(sys.argv[1]), Path(sys.argv[2])
chunks = l1/"chunks.jsonl"
text = chunks.read_text(encoding="utf-8", errors="ignore") if chunks.exists() else ""
probes = [
    ("mcc", r"m[ée]todo de calibraci[oó]n contextual|calibraci[oó]n contextual"),
    ("certeza_sin_sustancia", r"certeza sin sustancia"),
    ("grieta_generativa", r"grieta generativa"),
    ("soberania_cognitiva", r"soberan[ií]a cognitiva"),
    ("arbol_de_espejos", r"[aá]rbol(?:es)? de espejos"),
    ("neuroderechos", r"neuroderechos"),
    ("zenodo_17728016", r"17728016"),
    ("zenodo_21500800", r"21500800"),
]
rows = []
for name, pat in probes:
    n = len(re.findall(pat, text, flags=re.I))
    rows.append({"probe": name, "hits": n, "status": "OK" if n > 0 else "INDEX_GAP"})
(out/"fase5_probes.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
for r in rows:
    print(f"{r['status']:10} {r['hits']:5}  {r['probe']}")
PY
  log "  Ver $OUT/fase5_probes.json"
  log ""
fi

log "=== FIN corrección ==="
log "Report: $REPORT"
log "Siguiente tras probes en verde: Gate v8 (capacidad, no silencio)."
log "Recordatorio: memoria_usuario no fue ni debe ser modificada."
