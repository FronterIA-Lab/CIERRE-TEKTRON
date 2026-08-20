#!/usr/bin/env bash
# =============================================================================
# TEKTRON — inventario + descarga canónica desde Zenodo (16 papers)
# =============================================================================
# Host: tektron@192.168.100.84 · SSD: /mnt/tektron
#
# Desde la iMac:
#   scp ~/Downloads/tektron_zenodo_ingest.sh ~/Downloads/zenodo_dois.txt \
#       tektron@192.168.100.84:/mnt/tektron/workspace/
#   ssh tektron@192.168.100.84 \
#     'bash /mnt/tektron/workspace/tektron_zenodo_ingest.sh'
#   LATEST=$(ssh tektron@192.168.100.84 \
#     'ls -td /mnt/tektron/workspace/zenodo_ingest_* | head -1')
#   scp "tektron@192.168.100.84:${LATEST}/ZENODO_INGEST_REPORT.txt" ~/Downloads/
#
# En la Jetson:
#   bash tektron_zenodo_ingest.sh
#   bash tektron_zenodo_ingest.sh --scan-only
#   bash tektron_zenodo_ingest.sh --with-artifacts   # incluye tar.gz >50MB
#
# Qué hace:
#   1) Lee zenodo_dois.txt (junto al script o en TEKTRON_ROOT/workspace/)
#   2) Consulta API Zenodo por cada DOI/record
#   3) Busca copias ya en disco (DOI / título)
#   4) Descarga PDFs (y .pages si no hay PDF) a:
#        /mnt/tektron/corpus/Corpus_Tektron_F12/00_Core/raw/zenodo/<record_id>/
#   5) Escribe MANIFEST.tsv + ZENODO_INGEST_REPORT.txt
#
# NO indexa L1 (eso es el paso siguiente). NO borra nada.
# Por defecto OMITÉ artefactos > MAX_BYTES (código v4 ~1.1GB).
# =============================================================================

set -u
set -o pipefail

ROOT="${TEKTRON_ROOT:-/mnt/tektron}"
DEST_DEFAULT="${ROOT}/corpus/Corpus_Tektron_F12/00_Core/raw/zenodo"
DEST="${TEKTRON_ZENODO_DEST:-$DEST_DEFAULT}"
MAX_BYTES="${TEKTRON_ZENODO_MAX_BYTES:-52428800}"  # 50 MiB
SCAN_ONLY=0
WITH_ARTIFACTS=0
DOI_FILE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  sed -n '2,35p' "$0" | sed 's/^# \?//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scan-only) SCAN_ONLY=1; shift ;;
    --with-artifacts) WITH_ARTIFACTS=1; MAX_BYTES=0; shift ;;
    --dest) DEST="$2"; shift 2 ;;
    --dois) DOI_FILE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
  esac
done

TS="$(date +%Y%m%d_%H%M%S)"
OUT="${ROOT}/workspace/zenodo_ingest_${TS}"
mkdir -p "$OUT" 2>/dev/null || OUT="/tmp/tektron_zenodo_ingest_${TS}" && mkdir -p "$OUT"
REPORT="$OUT/ZENODO_INGEST_REPORT.txt"
MANIFEST="$OUT/MANIFEST.tsv"
META_DIR="$OUT/meta"
mkdir -p "$META_DIR"

if [[ -z "$DOI_FILE" ]]; then
  for cand in \
    "${SCRIPT_DIR}/zenodo_dois.txt" \
    "${ROOT}/workspace/zenodo_dois.txt" \
    "./zenodo_dois.txt"
  do
    if [[ -f "$cand" ]]; then DOI_FILE="$cand"; break; fi
  done
fi

if [[ -z "$DOI_FILE" || ! -f "$DOI_FILE" ]]; then
  echo "ERROR: no encuentro zenodo_dois.txt (pásalo con --dois PATH)" >&2
  exit 1
fi

PY="$(command -v python3 || true)"
CURL="$(command -v curl || true)"
if [[ -z "$PY" || -z "$CURL" ]]; then
  echo "ERROR: se necesitan python3 y curl" >&2
  exit 1
fi

log() { printf '%s\n' "$*" | tee -a "$REPORT"; }

log "=== TEKTRON Zenodo ingest ==="
log "fecha:     $(date -Is)"
log "host:      $(hostname 2>/dev/null || echo '?')"
log "root:      $ROOT"
log "dest:      $DEST"
log "dois:      $DOI_FILE"
log "scan_only: $SCAN_ONLY"
log "max_bytes: $MAX_BYTES  (0 = sin límite)"
log "salida:    $OUT"
log ""

# ---- parse DOI list ----
mapfile -t RAW_LINES < <(grep -vE '^\s*(#|$)' "$DOI_FILE" || true)
RECORDS=()
for line in "${RAW_LINES[@]}"; do
  line="$(echo "$line" | tr -d '[:space:]')"
  [[ -z "$line" ]] && continue
  if [[ "$line" =~ ([0-9]{6,}) ]]; then
    RECORDS+=("${BASH_REMATCH[1]}")
  else
    log "AVISO: línea no parseable: $line"
  fi
done

# dedupe preserving order
DEDUPED=()
declare -A SEEN_REC=()
for r in "${RECORDS[@]}"; do
  [[ -n "${SEEN_REC[$r]:-}" ]] && continue
  SEEN_REC[$r]=1
  DEDUPED+=("$r")
done
RECORDS=("${DEDUPED[@]}")
log "registros en lista: ${#RECORDS[@]}"
log ""

printf 'record_id\tdoi\ttitle\tpub_date\tfile_key\tsize\tchecksum\tstatus\tlocal_path\tdisk_hits\n' > "$MANIFEST"

mkdir -p "$DEST"

# ---- per-record: fetch meta, scan disk, download ----
"$PY" - "$OUT" "$DEST" "$SCAN_ONLY" "$MAX_BYTES" "$REPORT" "$MANIFEST" "$META_DIR" "${RECORDS[@]}" <<'PY'
import hashlib, json, os, re, subprocess, sys, time, urllib.parse, urllib.request
from pathlib import Path

out, dest, scan_only, max_bytes, report, manifest, meta_dir = sys.argv[1:8]
records = sys.argv[8:]
scan_only = scan_only == "1"
max_bytes = int(max_bytes)
dest = Path(dest)
meta_dir = Path(meta_dir)
root = Path(os.environ.get("TEKTRON_ROOT", "/mnt/tektron"))

UA = "TEKTRON-zenodo-ingest/1.0 (+local; corpus curation)"

def log(msg: str) -> None:
    with open(report, "a", encoding="utf-8") as f:
        f.write(msg + "\n")
    print(msg, flush=True)

def api_get(url: str, retries: int = 4):
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:
            last = e
            time.sleep(2 ** i)
    raise last

def safe_name(name: str) -> str:
    name = name.replace("/", "_").replace("\0", "")
    name = re.sub(r"\s+", " ", name).strip()
    if len(name) > 180:
        stem, ext = os.path.splitext(name)
        name = stem[:160] + ext
    return name or "file.bin"

def title_tokens(title: str):
    t = (title or "").lower()
    t = re.sub(r"[^a-záéíóúñü0-9\s]", " ", t, flags=re.I)
    toks = [w for w in t.split() if len(w) >= 5]
    # keep distinctive
    stop = {"hacia", "sobre", "como", "para", "desde", "entre", "desde", "modelo", "inteligencia", "artificial"}
    return [w for w in toks if w not in stop][:6]

def find_disk_hits(rec_id: str, title: str) -> list[str]:
    hits = []
    if not root.exists():
        return hits
    # DOI / record id path hits
    try:
        cmd = [
            "find", str(root),
            "(", "-iname", f"*{rec_id}*", "-o", "-path", f"*/zenodo/{rec_id}/*", ")",
            "-type", "f",
            "(", "-iname", "*.pdf", "-o", "-iname", "*.md", "-o", "-iname", "*.pages", "-o", "-iname", "*.txt", ")",
        ]
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        for line in (p.stdout or "").splitlines():
            if any(x in line for x in ("venv", "site-packages", ".git/", "node_modules")):
                continue
            hits.append(line)
    except Exception:
        pass
    # title token search (best-effort, limited)
    toks = title_tokens(title)
    if toks:
        try:
            # use first 2 significant tokens
            pat1 = f"*{toks[0]}*"
            cmd = ["find", str(root), "-type", "f", "-iname", pat1]
            if len(toks) > 1:
                cmd += ["-iname", f"*{toks[1]}*"]
            p = subprocess.run(cmd + ["-o", "-false"], capture_output=True, text=True, timeout=120)
            # find with two -iname without grouping is wrong; redo properly
            cmd = [
                "find", str(root), "-type", "f",
                "(", "-iname", "*.pdf", "-o", "-iname", "*.md", "-o", "-iname", "*.pages", ")",
                "-iname", pat1,
            ]
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
            for line in (p.stdout or "").splitlines()[:30]:
                if any(x in line for x in ("venv", "site-packages", ".git/")):
                    continue
                if line not in hits:
                    hits.append(line)
        except Exception:
            pass
    return hits[:40]

def choose_files(files: list, max_b: int):
    """Prefer PDFs; else text-like; skip huge unless max_b==0."""
    chosen = []
    pdfs = [f for f in files if f.get("key", "").lower().endswith(".pdf")]
    others = [f for f in files if f not in pdfs]
    pool = pdfs if pdfs else others
    for f in pool:
        size = int(f.get("size") or 0)
        if max_b > 0 and size > max_b:
            continue
        chosen.append(f)
    # if no pdf and only huge others skipped, still note pages/md under limit
    if not chosen:
        for f in others:
            size = int(f.get("size") or 0)
            key = f.get("key", "").lower()
            if key.endswith((".pages", ".md", ".txt", ".docx", ".odt")) and (max_b == 0 or size <= max_b):
                chosen.append(f)
    return chosen, [f for f in files if f not in chosen]

def download(url: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".part")
    cmd = [
        "curl", "-fsSL", "--retry", "4", "--retry-delay", "2",
        "-A", UA, "-o", str(tmp), url,
    ]
    subprocess.run(cmd, check=True)
    tmp.rename(path)

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def append_manifest(row: list[str]) -> None:
    with open(manifest, "a", encoding="utf-8") as f:
        f.write("\t".join(row) + "\n")

ok = skip = fail = already = 0
for rec_id in records:
    log(f"--- record {rec_id} ---")
    try:
        data = api_get(f"https://zenodo.org/api/records/{rec_id}")
    except Exception as e:
        log(f"  FAIL meta: {e}")
        append_manifest([rec_id, "", "", "", "", "", "", f"META_FAIL:{e}", "", ""])
        fail += 1
        continue

    (meta_dir / f"{rec_id}.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    m = data.get("metadata") or {}
    doi = m.get("doi") or f"10.5281/zenodo.{rec_id}"
    title = m.get("title") or ""
    pub = m.get("publication_date") or ""
    files = data.get("files") or []
    log(f"  DOI:   {doi}")
    log(f"  title: {title}")
    log(f"  date:  {pub}")
    log(f"  files: {len(files)}")

    hits = find_disk_hits(rec_id, title)
    if hits:
        log(f"  disk_hits ({len(hits)}):")
        for h in hits[:8]:
            log(f"    - {h}")
        if len(hits) > 8:
            log(f"    … +{len(hits)-8} más")
    else:
        log("  disk_hits: (ninguno obvio)")

    chosen, skipped = choose_files(files, max_bytes)
    for f in skipped:
        key = f.get("key", "")
        size = int(f.get("size") or 0)
        log(f"  SKIP file (size/policy): {key} ({size} bytes)")
        append_manifest([rec_id, doi, title, pub, key, str(size), f.get("checksum", ""), "SKIPPED_POLICY", "", ";".join(hits[:5])])

    if not chosen:
        log("  AVISO: sin archivos elegibles (¿solo .pages/.tar.gz o vacío?)")
        if not files:
            append_manifest([rec_id, doi, title, pub, "", "", "", "NO_FILES", "", ";".join(hits[:5])])
        skip += 1
        time.sleep(0.4)
        continue

    rec_dir = dest / str(rec_id)
    for f in chosen:
        key = f.get("key", "file.bin")
        size = int(f.get("size") or 0)
        checksum = f.get("checksum") or ""
        # content URL
        content = (f.get("links") or {}).get("self") or ""
        if content.endswith("/content") is False:
            # Zenodo file self often ends without /content in older; API uses .../content
            enc = urllib.parse.quote(key)
            content = f"https://zenodo.org/api/records/{rec_id}/files/{enc}/content"
        else:
            # links.self for files may already be .../content
            pass
        # Prefer explicit content link from API
        flink = (f.get("links") or {}).get("self")
        if flink:
            content = flink if flink.endswith("/content") else flink.rstrip("/") + "/content"

        out_name = f"{rec_id}__{safe_name(key)}"
        out_path = rec_dir / out_name

        if out_path.exists() and out_path.stat().st_size > 0:
            status = "ALREADY_LOCAL"
            already += 1
            log(f"  ALREADY: {out_path} ({out_path.stat().st_size} B)")
            append_manifest([rec_id, doi, title, pub, key, str(size), checksum, status, str(out_path), ";".join(hits[:5])])
            continue

        if scan_only:
            status = "WOULD_DOWNLOAD"
            log(f"  WOULD download: {key} -> {out_path}")
            append_manifest([rec_id, doi, title, pub, key, str(size), checksum, status, str(out_path), ";".join(hits[:5])])
            skip += 1
            continue

        try:
            log(f"  DOWNLOADING: {key} ({size} B)")
            download(content, out_path)
            digest = sha256(out_path)
            # sidecar metadata
            side = {
                "doi": doi,
                "record_id": rec_id,
                "title": title,
                "publication_date": pub,
                "file_key": key,
                "zenodo_checksum": checksum,
                "sha256": digest,
                "bytes": out_path.stat().st_size,
                "source": content,
            }
            (out_path.with_suffix(out_path.suffix + ".json")).write_text(
                json.dumps(side, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            status = "DOWNLOADED"
            ok += 1
            log(f"  OK sha256={digest[:16]}… -> {out_path}")
            append_manifest([rec_id, doi, title, pub, key, str(size), checksum, status, str(out_path), ";".join(hits[:5])])
        except Exception as e:
            status = f"DOWNLOAD_FAIL:{e}"
            fail += 1
            log(f"  FAIL download: {e}")
            append_manifest([rec_id, doi, title, pub, key, str(size), checksum, status, str(out_path), ";".join(hits[:5])])

    time.sleep(0.5)

log("")
log("=== RESUMEN ===")
log(f"downloaded: {ok}")
log(f"already:    {already}")
log(f"skipped:    {skip}")
log(f"failed:     {fail}")
log(f"dest:       {dest}")
log(f"manifest:   {manifest}")
log("")
log("Siguiente paso (cuando los PDFs estén en raw/zenodo):")
log("  1) Convertir/extraer texto a markdown en 00_Core/markdown/zenodo/ (pipeline F12 existente)")
log("  2) Re-indexar SOLO esas fuentes en index_l1")
log("  3) Probes: 'certeza sin sustancia' | 'grieta generativa' | 'MCC' | 'soberanía cognitiva'")
log("  Nota: 18707186 trae .pages (no PDF); abrir en iMac o convertir aparte.")
log("  Nota: 18655577 es versión nueva de 18492979 — ambos listados; curar duplicidad al indexar.")
PY

log ""
log "Listo. Report: $REPORT"
log "Manifest: $MANIFEST"
log "Destino corpus: $DEST"
