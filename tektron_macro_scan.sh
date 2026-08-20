#!/usr/bin/env bash
# =============================================================================
# TEKTRON — mirada MACRO de la Jetson + SSD (SOLO LECTURA)
# =============================================================================
# Uso en la Jetson:
#   bash tektron_macro_scan.sh
#   # o:
#   chmod +x tektron_macro_scan.sh && ./tektron_macro_scan.sh
#
# Salida:
#   /mnt/tektron/workspace/macro_YYYYMMDD_HHMMSS/MACRO_REPORT.txt  (humano)
#   /mnt/tektron/workspace/macro_YYYYMMDD_HHMMSS/MACRO_REPORT.json (máquina)
#   + archivos auxiliares en el mismo directorio
#
# Al terminar: pega aquí MACRO_REPORT.txt (o súbelo) para revisar errores.
# No modifica corpus, índices ni configuración.
# =============================================================================

set -u
set -o pipefail

ROOT="${TEKTRON_ROOT:-/mnt/tektron}"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="${ROOT}/workspace/macro_${TS}"
mkdir -p "$OUT" 2>/dev/null || OUT="/tmp/tektron_macro_${TS}" && mkdir -p "$OUT"
REPORT="$OUT/MACRO_REPORT.txt"
JSON="$OUT/MACRO_REPORT.json"
PY="${ROOT}/venv_tektron/bin/python3"
command -v "$PY" >/dev/null 2>&1 || PY="$(command -v python3)"

log()  { printf '%s\n' "$*" | tee -a "$REPORT"; }
sep()  { log ""; log "════════════════════════════════════════════════════════════"; log "$*"; log "════════════════════════════════════════════════════════════"; }
run()  {
  # run "titulo" -- comando...
  local title="$1"; shift
  log ""
  log "── $title ──"
  if "$@" >>"$REPORT" 2>>"$OUT/errors.log"; then
    :
  else
    log "(aviso: comando falló o vacío; ver errors.log)"
  fi
}

: >"$REPORT"
: >"$OUT/errors.log"

sep "TEKTRON MACRO SCAN — $TS"
log "host: $(hostname 2>/dev/null || echo ?)"
log "user: $(whoami 2>/dev/null || echo ?)"
log "root: $ROOT"
log "out:  $OUT"
log "py:   $PY"
log "fecha: $(date -Is 2>/dev/null || date)"

# -----------------------------------------------------------------------------
sep "1. DISCO / SSD / MONTAJES"
# -----------------------------------------------------------------------------
{
  echo "=== df -h ==="
  df -h 2>/dev/null || true
  echo
  echo "=== df -h $ROOT ==="
  df -h "$ROOT" 2>/dev/null || true
  echo
  echo "=== mount | grep -E 'mnt|ssd|nvme|mmc' ==="
  mount 2>/dev/null | grep -Ei 'mnt|ssd|nvme|mmc|tektron' || true
  echo
  echo "=== lsblk ==="
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,LABEL,UUID 2>/dev/null || true
  echo
  echo "=== /proc/mounts (tektron/mnt) ==="
  grep -E 'tektron|/mnt' /proc/mounts 2>/dev/null || true
} | tee -a "$REPORT" >"$OUT/01_disk.txt"

# -----------------------------------------------------------------------------
sep "2. PESO POR DIRECTORIO (top)"
# -----------------------------------------------------------------------------
{
  echo "=== du -sh $ROOT/*/ ==="
  du -sh "$ROOT"/*/ 2>/dev/null | sort -rh
  echo
  echo "=== du -sh $ROOT (total) ==="
  du -sh "$ROOT" 2>/dev/null || true
  echo
  echo "=== top 40 subdirs más pesados (depth<=3) ==="
  du -h --max-depth=3 "$ROOT" 2>/dev/null | sort -rh | head -40
} | tee -a "$REPORT" >"$OUT/02_du.txt"

# -----------------------------------------------------------------------------
sep "3. MAPA DE PRIMER / SEGUNDO NIVEL"
# -----------------------------------------------------------------------------
{
  echo "=== ls -la $ROOT ==="
  ls -la "$ROOT" 2>/dev/null || true
  echo
  for d in corpus _clacso_archivo _archivo _snapshots index_l1 index_l1_precuracion_20260819 \
           models staging workspace logs config src tools docs referencia wiki raw; do
    if [[ -e "$ROOT/$d" ]]; then
      echo "---- $ROOT/$d ----"
      ls -la "$ROOT/$d" 2>/dev/null | head -40
      echo
    fi
  done
} | tee -a "$REPORT" >"$OUT/03_tree_top.txt"

# -----------------------------------------------------------------------------
sep "4. DOCUMENTOS FUENTE (conteos por extensión y por árbol)"
# -----------------------------------------------------------------------------
{
  echo "=== conteo extensiones bajo corpus + clacso + archivo (puede tardar) ==="
  find "$ROOT/corpus" "$ROOT/_clacso_archivo" "$ROOT/_archivo" "$ROOT/staging" "$ROOT/workspace" \
    -type f 2>/dev/null \
    | sed 's/.*\.//' | tr 'A-Z' 'a-z' | sort | uniq -c | sort -rn | head -40

  echo
  echo "=== PDFs / MD / TXT / EPUB / ZIM por árbol ==="
  for tree in corpus _clacso_archivo _archivo staging workspace; do
    base="$ROOT/$tree"
    [[ -d "$base" ]] || continue
    n_pdf=$(find "$base" -type f -iname '*.pdf' 2>/dev/null | wc -l)
    n_md=$(find "$base" -type f -iname '*.md' 2>/dev/null | wc -l)
    n_txt=$(find "$base" -type f -iname '*.txt' 2>/dev/null | wc -l)
    n_epub=$(find "$base" -type f -iname '*.epub' 2>/dev/null | wc -l)
    n_zim=$(find "$base" -type f -iname '*.zim' 2>/dev/null | wc -l)
    bytes=$(du -sb "$base" 2>/dev/null | awk '{print $1}')
    printf '%-22s pdf=%6s md=%6s txt=%6s epub=%5s zim=%4s  bytes=%s\n' \
      "$tree" "$n_pdf" "$n_md" "$n_txt" "$n_epub" "$n_zim" "$bytes"
  done

  echo
  echo "=== corpus/ subdirs (maxdepth 2) ==="
  find "$ROOT/corpus" -maxdepth 2 -type d 2>/dev/null | sort | head -80

  echo
  echo "=== _clacso_archivo/ subdirs (maxdepth 2) ==="
  find "$ROOT/_clacso_archivo" -maxdepth 2 -type d 2>/dev/null | sort | head -80
} | tee -a "$REPORT" >"$OUT/04_docs.txt"

# Lista compacta de PDFs (basename + path) para cruce posterior
find "$ROOT/corpus" -type f -iname '*.pdf' -printf '%f\t%p\n' 2>/dev/null \
  | sort >"$OUT/04_pdfs_corpus.tsv" || true
find "$ROOT/_clacso_archivo" -type f -iname '*.pdf' -printf '%f\t%p\n' 2>/dev/null \
  | sort >"$OUT/04_pdfs_clacso.tsv" || true

# -----------------------------------------------------------------------------
sep "5. TODOS LOS ÍNDICES (chunks / faiss / meta / unificado)"
# -----------------------------------------------------------------------------
{
  echo "=== find índices ==="
  find "$ROOT" -type f \( \
    -name 'chunks.jsonl' -o -name 'chunks_unificados.jsonl' \
    -o -name 'faiss.idx' -o -name '*.faiss' \
    -o -name 'bm25*.pkl' -o -name 'meta.json' \
    -o -name '*unificado*' \
  \) 2>/dev/null | grep -vE 'venv|site-packages' | sort

  echo
  echo "=== inventario chunks.jsonl (lineas | size | mtime | path) ==="
  find "$ROOT" -type f \( -name 'chunks.jsonl' -o -name 'chunks_unificados.jsonl' \) 2>/dev/null \
    | grep -vE 'venv|site-packages' | while read -r f; do
        printf '%8s  %8s  %s  %s\n' \
          "$(wc -l < "$f" 2>/dev/null | tr -d ' ')" \
          "$(du -h "$f" 2>/dev/null | awk '{print $1}')" \
          "$(date -r "$f" '+%Y-%m-%d' 2>/dev/null || stat -c '%y' "$f" 2>/dev/null | cut -d' ' -f1)" \
          "$f"
      done | sort -rn

  echo
  echo "=== meta.json resumido ==="
  find "$ROOT" -name meta.json 2>/dev/null | grep -vE 'venv|site-packages' | while read -r m; do
    echo "---- $m ----"
    "$PY" -c "
import json
try:
  d=json.load(open('$m'))
  keys=['n_chunks','n_sit','n_heg','n_tec','dim','created_utc','model','embedding']
  print({k:d.get(k) for k in keys})
except Exception as e:
  print('ERR', e)
" 2>/dev/null || echo "(sin python)"
  done
} | tee -a "$REPORT" >"$OUT/05_indexes.txt"

# -----------------------------------------------------------------------------
sep "6. INDEX_L1 VIVO — polos, graneros, fuentes"
# -----------------------------------------------------------------------------
if [[ -f "$ROOT/index_l1/chunks.jsonl" ]]; then
  "$PY" << PY | tee -a "$REPORT" >"$OUT/06_index_l1_stats.txt"
import json
from collections import Counter
from pathlib import Path
p = Path("$ROOT/index_l1/chunks.jsonl")
fuentes, polos, graneros = Counter(), Counter(), Counter()
n = 0
sample_keys = None
with p.open() as f:
    for line in f:
        d = json.loads(line)
        n += 1
        if sample_keys is None:
            sample_keys = sorted(d.keys())
        fuentes[d.get("fuente") or d.get("source") or "?"] += 1
        polos[d.get("tipo_epistemico") or d.get("polo") or "?"] += 1
        graneros[d.get("canon_id") or d.get("granero") or "?"] += 1
print("chunks", n)
print("fuentes_unicas", len(fuentes))
print("polos", dict(polos))
print("keys", sample_keys)
print("graneros_top20:")
for k,v in graneros.most_common(20):
    print(f"  {v}\t{k}")
print("fuentes_top25:")
for k,v in fuentes.most_common(25):
    print(f"  {v}\t{k}")
Path("$OUT/06_fuentes_list.txt").write_text("\n".join(sorted(fuentes)))
PY
else
  log "NO EXISTE $ROOT/index_l1/chunks.jsonl"
fi

# -----------------------------------------------------------------------------
sep "7. DESCONEXIÓN CORPUS ↔ ÍNDICE (aprox por basename)"
# -----------------------------------------------------------------------------
"$PY" << PY | tee -a "$REPORT" >"$OUT/07_disconnect.txt"
from pathlib import Path
out = Path("$OUT")
fuentes_path = out / "06_fuentes_list.txt"
blob = fuentes_path.read_text(errors="ignore").lower() if fuentes_path.exists() else ""
for label in ["corpus", "clacso"]:
    f = out / f"04_pdfs_{label}.tsv"
    if not f.exists():
        print(label, "sin lista pdf")
        continue
    pdfs = [line.split("\t",1)[0] for line in f.read_text(errors="ignore").splitlines() if line.strip()]
    hit = miss = 0
    misses = []
    for name in pdfs:
        stem = name.rsplit(".",1)[0][:50].lower()
        if stem and stem in blob:
            hit += 1
        else:
            miss += 1
            if len(misses) < 15:
                misses.append(name)
    print(f"{label}: pdfs={len(pdfs)} hit_approx={hit} miss_approx={miss} pct_miss={100*miss/max(len(pdfs),1):.1f}%")
    print("  miss_sample:", misses)
if not blob:
    print("AVISO: no hay fuentes de index_l1 para cruzar")
PY

# -----------------------------------------------------------------------------
sep "8. LLM WIKI (Karpathy) — documento e implementación"
# -----------------------------------------------------------------------------
{
  echo "=== por nombre ==="
  find /mnt /home /opt -type f \( \
    -iname '*llm-wiki*' -o -iname '*llm_wiki*' -o -iname '*karpathy*' \
  \) 2>/dev/null | grep -vE 'venv|site-packages|__pycache__|\.git/objects' | head -80

  echo
  echo "=== por contenido del gist ==="
  grep -RIl -E 'persistent, compounding artifact|Obsidian is the IDE|karpathy/442a6bf|Vannevar Bush.s Memex' \
    "$ROOT" /home/tektron 2>/dev/null \
    | grep -vE 'venv|site-packages' | head -40

  echo
  echo "=== señales de implementación (index.md / log.md / schema) ==="
  find "$ROOT" /home/tektron -type f \( \
    -name 'index.md' -o -name 'log.md' -o -name 'CLAUDE.md' -o -name 'AGENTS.md' -o -name 'SCHEMA.md' \
  \) 2>/dev/null | grep -vE 'venv|site-packages|\.git' | head -60

  echo
  echo "=== dirs wiki / raw / entities / concepts ==="
  find "$ROOT" /home/tektron -type d \( \
    -iname 'wiki' -o -iname 'entities' -o -iname 'concepts' -o -name 'raw' \
  \) 2>/dev/null | grep -vE 'venv|site-packages|\.git|node_modules' | head -60

  echo
  echo "=== historial shell (karpathy/llm-wiki) ==="
  grep -hE 'karpathy|llm-wiki|442a6bf' /home/tektron/.bash_history /root/.bash_history 2>/dev/null | sort -u | head -40
} | tee -a "$REPORT" >"$OUT/08_llmwiki.txt"

# -----------------------------------------------------------------------------
sep "9. PROBES ENTRA — path vs index"
# -----------------------------------------------------------------------------
{
  echo "TERM | PATH_hits | INDEX_hits"
  for term in Quijano "Convenio 169" "Ley Minera" Nagoya MCC "grieta generativa" \
    "certeza sin sustancia" "soberanía cognitiva" "árbol de espejos" Modbus Siemens CLACSO; do
    ph=$(find "$ROOT/corpus" "$ROOT/_clacso_archivo" -iname "*${term}*" 2>/dev/null | wc -l)
    if [[ -f "$ROOT/index_l1/chunks.jsonl" ]]; then
      ih=$(grep -ci -- "$term" "$ROOT/index_l1/chunks.jsonl" 2>/dev/null || echo 0)
    else
      ih=0
    fi
    printf '%-28s path=%5s  index=%s\n' "$term" "$ph" "$ih"
  done
} | tee -a "$REPORT" >"$OUT/09_probes.txt"

# -----------------------------------------------------------------------------
sep "10. SCRIPTS DE INDEXACIÓN / CURACIÓN / BACKEND"
# -----------------------------------------------------------------------------
{
  echo "=== py/sh en $ROOT (no venv) ==="
  find "$ROOT" -maxdepth 2 -type f \( -name '*.py' -o -name '*.sh' \) 2>/dev/null | sort
  echo
  ls -la "$ROOT"/*.py "$ROOT"/src/*.py "$ROOT"/tools/*.py 2>/dev/null || true
  echo
  echo "=== refs corpus/index en scripts ==="
  grep -RIn -E 'corpus/|_clacso|index_l1|unificado|chunks\.jsonl|faiss|karpathy|llm-wiki' \
    "$ROOT" --include='*.py' --include='*.sh' 2>/dev/null \
    | grep -vE 'venv|_archivo/venv|site-packages' | head -80
  echo
  echo "=== md5 piezas críticas si existen ==="
  for f in mcc_layer.py calibrar_n0.py tektron_backend.py indexar_unificado.py \
           curar_v9.py curar_v9b.py curar_v9c.py construir_index_curado.py; do
    [[ -f "$ROOT/$f" ]] && md5sum "$ROOT/$f"
  done
} | tee -a "$REPORT" >"$OUT/10_scripts.txt"

# -----------------------------------------------------------------------------
sep "11. SERVICIOS / PROCESOS TEKTRON (si corren)"
# -----------------------------------------------------------------------------
{
  echo "=== puertos 8000/8001/8080 ==="
  ss -lntp 2>/dev/null | grep -E ':8000|:8001|:8080' || netstat -lntp 2>/dev/null | grep -E ':8000|:8001|:8080' || true
  echo
  echo "=== procesos python/llama/tektron ==="
  ps aux 2>/dev/null | grep -Ei 'tektron|llama|uvicorn|retrieve|faiss' | grep -v grep | head -30 || true
} | tee -a "$REPORT" >"$OUT/11_services.txt"

# -----------------------------------------------------------------------------
sep "12. SNAPSHOTS / BACKUPS / PUNTOS DE RETORNO"
# -----------------------------------------------------------------------------
{
  echo "=== _snapshots ==="
  du -sh "$ROOT/_snapshots"/*/ 2>/dev/null | sort -rh
  find "$ROOT/_snapshots" -maxdepth 3 -type f 2>/dev/null | head -40
  echo
  echo "=== *.bak* / retorno / precuracion ==="
  find "$ROOT" -maxdepth 3 \( -name '*bak*' -o -name '*retorno*' -o -name '*precuracion*' -o -name '*pre_cierre*' \) 2>/dev/null \
    | grep -vE 'venv|site-packages' | head -40
} | tee -a "$REPORT" >"$OUT/12_snapshots.txt"

# -----------------------------------------------------------------------------
sep "13. JSON RESUMEN"
# -----------------------------------------------------------------------------
"$PY" << PY | tee -a "$REPORT"
import json, datetime, os
from pathlib import Path
root = Path("$ROOT")
out = Path("$OUT")

def count_lines(p):
    try:
        return sum(1 for _ in open(p, encoding="utf-8", errors="ignore"))
    except Exception:
        return None

def count_pdfs(rel):
    p = root/rel
    if not p.exists(): return None
    return sum(1 for _ in p.rglob("*.pdf"))

report = {
  "ts": "$TS",
  "hostname": os.uname().nodename if hasattr(os, "uname") else None,
  "root": str(root),
  "out_dir": str(out),
  "index_l1_chunks": count_lines(root/"index_l1/chunks.jsonl"),
  "precuracion_chunks": count_lines(root/"index_l1_precuracion_20260819/chunks.jsonl"),
  "unificado_chunks": count_lines(root/"_archivo/index_unificado_minilm_20260818/chunks_unificados.jsonl"),
  "pdfs_corpus": count_pdfs("corpus"),
  "pdfs_clacso": count_pdfs("_clacso_archivo"),
  "du_top": {},
}
# parse disconnect if present
disc = (out/"07_disconnect.txt").read_text(errors="ignore") if (out/"07_disconnect.txt").exists() else ""
report["disconnect_raw"] = disc.strip().splitlines()[:10]
llm = (out/"08_llmwiki.txt").read_text(errors="ignore") if (out/"08_llmwiki.txt").exists() else ""
report["llmwiki_hits_nonempty"] = bool(llm.strip()) and ("=== por nombre ===" in llm)
# crude: any real path lines under by-name
report["llmwiki_name_paths"] = [ln.strip() for ln in llm.splitlines() if ln.startswith("/") ][:20]
probes = (out/"09_probes.txt").read_text(errors="ignore") if (out/"09_probes.txt").exists() else ""
report["probes_sample"] = probes.strip().splitlines()[:20]
(out/"MACRO_REPORT.json").write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(json.dumps(report, indent=2, ensure_ascii=False))
print()
print("JSON:", out/"MACRO_REPORT.json")
PY

# -----------------------------------------------------------------------------
sep "FIN"
# -----------------------------------------------------------------------------
log ""
log "Listo. Archivos en: $OUT"
log "  - MACRO_REPORT.txt   ← pega ESTE en el chat"
log "  - MACRO_REPORT.json"
log "  - 01_disk.txt … 12_snapshots.txt"
log ""
log "Errores de comandos (si hubo): $OUT/errors.log"
log "bytes errors.log: $(wc -c < "$OUT/errors.log" 2>/dev/null || echo 0)"
echo
echo "=========================================="
echo "PEGA EN EL CHAT EL CONTENIDO DE:"
echo "  $REPORT"
echo "=========================================="
echo "$OUT" >"$OUT/OUT_DIR.txt"
