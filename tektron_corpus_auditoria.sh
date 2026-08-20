#!/usr/bin/env bash
# =============================================================================
# TEKTRON — AUDITORÍA PROFUNDA DE ARCHIVOS (SOLO LECTURA)
# =============================================================================
# Host: tektron@192.168.100.84 · SSD: /mnt/tektron
#
# Desde la iMac:
#   scp ~/Downloads/tektron_corpus_auditoria.sh tektron@192.168.100.84:/mnt/tektron/workspace/
#   ssh tektron@192.168.100.84 'bash /mnt/tektron/workspace/tektron_corpus_auditoria.sh'
#   LATEST=$(ssh tektron@192.168.100.84 'ls -td /mnt/tektron/workspace/audit_* | head -1')
#   scp -r "tektron@192.168.100.84:${LATEST}" ~/Downloads/
#
# Qué hace:
#   - Inventaria PDF/MD/TXT/EPUB/HTML/JSONL en corpus, clacso, archivo, staging
#   - Detecta duplicados por nombre (*_dup1*) y por tamaño+basename
#   - Escanea basura: facebook, url:, 404, anti-bot, metadatos rotos, OpenGraph
#   - Marca candidatos KEEP / REVISION / BORRAR_CANDIDATO (no borra nada)
#   - Separa ZIM / índices / venvs / limpiezas (desparramado)
#
# Salida: AUDIT_REPORT.md + CSVs en workspace/audit_TIMESTAMP/
# =============================================================================

set -u
set -o pipefail

ROOT="${TEKTRON_ROOT:-/mnt/tektron}"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="${ROOT}/workspace/audit_${TS}"
mkdir -p "$OUT" 2>/dev/null || { OUT="/tmp/tektron_audit_${TS}"; mkdir -p "$OUT"; }
PY="${ROOT}/venv_tektron/bin/python3"
command -v "$PY" >/dev/null 2>&1 || PY="$(command -v python3)"
REPORT="$OUT/AUDIT_REPORT.md"
export OUT ROOT

echo "OUT=$OUT"
echo "PY=$PY"
echo "Inicio $(date -Is)"

# -----------------------------------------------------------------------------
# 1. Inventario plano de documentos
# -----------------------------------------------------------------------------
echo "[1/6] Inventario de documentos..."
find "$ROOT/corpus" "$ROOT/_clacso_archivo" "$ROOT/_archivo" "$ROOT/staging" \
  -type f \( \
    -iname '*.pdf' -o -iname '*.md' -o -iname '*.txt' -o -iname '*.epub' \
    -o -iname '*.html' -o -iname '*.htm' -o -iname '*.jsonl' \
  \) -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null \
  | sort -k3 >"$OUT/01_all_docs.tsv"

wc -l "$OUT/01_all_docs.tsv" | tee "$OUT/01_count.txt"

# Por árbol
"$PY" << 'PY'
import os
from pathlib import Path
from collections import Counter, defaultdict
out = Path(os.environ["OUT"])
rows = []
for line in (out/"01_all_docs.tsv").read_text(errors="ignore").splitlines():
    if not line.strip(): continue
    parts = line.split("\t", 2)
    if len(parts)<3: continue
    size, date, path = parts
    rows.append((int(size), date, path))

def tree(p):
    if "/corpus/zim" in p: return "corpus_zim"
    if "/corpus/Corpus_Tektron_F12" in p: return "corpus_F12"
    if "/corpus/" in p: return "corpus_otro"
    if "/_clacso_archivo/" in p: return "clacso"
    if "/_archivo/corpus_pre_f15" in p: return "archivo_pre_f15"
    if "/_archivo/limpieza" in p: return "archivo_limpieza"
    if "/_archivo/index_unificado" in p: return "archivo_unificado"
    if "/_archivo/" in p: return "archivo_otro"
    if "/staging/" in p: return "staging"
    return "otro"

by = Counter(); bytes_by = Counter(); ext = Counter()
for size, date, path in rows:
    t = tree(path)
    by[t]+=1; bytes_by[t]+=size
    ext[Path(path).suffix.lower()] += 1

lines = ["# Conteos por árbol", ""]
for t,n in by.most_common():
    lines.append(f"- **{t}**: {n} archivos · {bytes_by[t]/1024/1024:.1f} MB")
lines += ["", "# Extensiones", ""]
for e,n in ext.most_common():
    lines.append(f"- `{e or '(sin ext)'}`: {n}")
(out/"01_por_arbol.md").write_text("\n".join(lines), encoding="utf-8")
print("\n".join(lines))
PY

# -----------------------------------------------------------------------------
# 2. Duplicados y nombres sospechosos
# -----------------------------------------------------------------------------
echo "[2/6] Duplicados / nombres basura..."
"$PY" << 'PY'
import os
from pathlib import Path
from collections import defaultdict
out = Path(os.environ["OUT"])
rows = []
for line in (out/"01_all_docs.tsv").read_text(errors="ignore").splitlines():
    if not line.strip(): continue
    size, date, path = line.split("\t", 2)
    name = Path(path).name
    rows.append((int(size), date, path, name.lower()))

dup_patterns = []
by_name = defaultdict(list)
by_size_name = defaultdict(list)
for size, date, path, nlow in rows:
    by_name[nlow].append(path)
    stem = Path(nlow).stem
    by_size_name[(size, stem.replace("_dup1","").replace("_dup2",""))].append(path)
    flags = []
    if "_dup1" in nlow or "_dup2" in nlow or " copy" in nlow or "(1)" in nlow:
        flags.append("DUP_SUFFIX")
    if nlow.startswith(".") or "untitled" in nlow or nlow in ("document.pdf","download.pdf"):
        flags.append("NOMBRE_GENERICO")
    if any(x in nlow for x in ["facebook", "fbcdn", "instagram", "whatsapp", "meta.com"]):
        flags.append("NOMBRE_SOCIAL")
    if any(x in nlow for x in ["captcha", "403", "404", "access_denied", "just_a_moment"]):
        flags.append("NOMBRE_ERROR_HTTP")
    if flags:
        dup_patterns.append((",".join(flags), size, path))

# mismos basename >1
multi = {k:v for k,v in by_name.items() if len(v)>1}
# mismos tamaño+stem limpio >1
near = {k:v for k,v in by_size_name.items() if len(v)>1}

with (out/"02_nombres_sospechosos.tsv").open("w") as f:
    f.write("flags\tsize\tpath\n")
    for flags, size, path in sorted(dup_patterns, key=lambda x: x[1], reverse=True):
        f.write(f"{flags}\t{size}\t{path}\n")

with (out/"02_duplicados_basename.tsv").open("w") as f:
    f.write("basename\tcount\tpaths\n")
    for k,v in sorted(multi.items(), key=lambda kv: -len(kv[1]))[:500]:
        f.write(f"{k}\t{len(v)}\t{' | '.join(v)}\n")

with (out/"02_duplicados_size_stem.tsv").open("w") as f:
    f.write("size\tstem\tcount\tpaths\n")
    for (size, stem), v in sorted(near.items(), key=lambda kv: -len(kv[1]))[:500]:
        f.write(f"{size}\t{stem}\t{len(v)}\t{' | '.join(v)}\n")

print(f"sospechosos={len(dup_patterns)} basename_multi={len(multi)} size_stem_multi={len(near)}")
PY

# -----------------------------------------------------------------------------
# 3. Escaneo de contenido / metadatos basura (muestra + patrones)
# -----------------------------------------------------------------------------
echo "[3/6] Escaneo basura en texto/metadatos (pdf/md/txt/html)..."
"$PY" << 'PY'
import os, re, subprocess, json
from pathlib import Path
out = Path(os.environ["OUT"])
root = Path(os.environ["ROOT"])

# Patrones de corrupción / scrape fallido / social / metadatos basura
PATTERNS = [
    ("FACEBOOK", re.compile(r"facebook\.com|fbcdn\.net|fb_dtsg|og:url.*facebook|meta property=\"og:", re.I)),
    ("SOCIAL", re.compile(r"instagram\.com|twitter\.com|x\.com/|tiktok\.com|whatsapp|t\.co/", re.I)),
    ("URL_META", re.compile(r"^url:\s*\S+|^\s*title:\s*$|url:\s*https?://", re.I|re.M)),
    ("HTTP_ERROR", re.compile(r"\b404\b|not found|access denied|just a moment|cf-browser-verification|anti-?bot|captcha|enable javascript|robot check", re.I)),
    ("SCRAPE_BASURA", re.compile(r"cookie consent|accept all cookies|sign in to continue|subscribe to read|paywall", re.I)),
    ("VACIO_CORTO", None),  # handled by length
]

def extract_text(path: Path, limit=8000) -> str:
    suf = path.suffix.lower()
    try:
        if suf in {".md", ".txt", ".html", ".htm", ".jsonl", ".csv"}:
            return path.read_text(encoding="utf-8", errors="ignore")[:limit]
        if suf == ".pdf":
            # pdftotext si existe; si no, strings
            try:
                r = subprocess.run(
                    ["pdftotext", "-l", "2", "-q", str(path), "-"],
                    capture_output=True, timeout=20
                )
                if r.returncode == 0 and r.stdout:
                    return r.stdout.decode("utf-8", "ignore")[:limit]
            except Exception:
                pass
            try:
                r = subprocess.run(["strings", "-n", "8", str(path)], capture_output=True, timeout=15)
                return r.stdout.decode("utf-8", "ignore")[:limit]
            except Exception:
                return ""
    except Exception:
        return ""
    return ""

# Priorizar F12 + clacso + pre_f15; limitar archivo_limpieza a sample
candidates = []
for line in (out/"01_all_docs.tsv").read_text(errors="ignore").splitlines():
    if not line.strip(): continue
    size, date, path = line.split("\t", 2)
    size = int(size)
    p = Path(path)
    if p.suffix.lower() not in {".pdf", ".md", ".txt", ".html", ".htm"}:
        continue
    # skip huge dumps in limpieza venv noise already filtered by find roots
    if "/limpieza_20260812/" in path and "/venv" in path:
        continue
    if "/llama.cpp/" in path:
        continue
    priority = 0
    if "/Corpus_Tektron_F12/" in path: priority = 3
    elif "/_clacso_archivo/" in path: priority = 3
    elif "/corpus_pre_f15" in path: priority = 2
    elif "/corpus/" in path: priority = 2
    else: priority = 1
    candidates.append((priority, -size, path, size))

candidates.sort(reverse=True)
# Cap para no tardar eternamente en Jetson
MAX = 2500
candidates = candidates[:MAX]

hits = []
stats = {k:0 for k,_ in PATTERNS}
stats["VACIO_CORTO"] = 0
stats["OK_LIMPIO"] = 0
stats["SCANNED"] = 0

for i, (_, __, path, size) in enumerate(candidates):
    stats["SCANNED"] += 1
    text = extract_text(Path(path))
    flags = []
    if len(text.strip()) < 80 and size > 500:
        flags.append("VACIO_CORTO")
        stats["VACIO_CORTO"] += 1
    for name, rx in PATTERNS:
        if rx is None: continue
        if text and rx.search(text):
            flags.append(name)
            stats[name] += 1
    if not flags:
        stats["OK_LIMPIO"] += 1
        continue
    # snippet
    snip = re.sub(r"\s+", " ", text[:180])
    hits.append((",".join(flags), size, path, snip))
    if (i+1) % 200 == 0:
        print(f"  scanned {i+1}/{len(candidates)} hits={len(hits)}")

with (out/"03_basura_contenido.tsv").open("w", encoding="utf-8") as f:
    f.write("flags\tsize\tpath\tsnippet\n")
    for flags, size, path, snip in hits:
        snip = snip.replace("\t"," ").replace("\n"," ")
        f.write(f"{flags}\t{size}\t{path}\t{snip}\n")

(out/"03_basura_stats.json").write_text(json.dumps(stats, indent=2), encoding="utf-8")
print(json.dumps(stats, indent=2))
print(f"hits_basura={len(hits)} de scanned={stats['SCANNED']}")
PY

# -----------------------------------------------------------------------------
# 4. También escanear chunks del índice vivo (contaminación ya indexada)
# -----------------------------------------------------------------------------
echo "[4/6] Contaminación dentro de index_l1 chunks..."
"$PY" << 'PY'
import os, json, re
from collections import Counter
from pathlib import Path
out = Path(os.environ["OUT"])
chunks = Path(os.environ["ROOT"])/"index_l1"/"chunks.jsonl"
if not chunks.exists():
    print("sin index_l1")
    raise SystemExit
rxs = {
  "FACEBOOK": re.compile(r"facebook\.com|fbcdn", re.I),
  "URL_META": re.compile(r"url:\s*https?://|^\s*url:", re.I|re.M),
  "HTTP_ERROR": re.compile(r"\b404\b|anti-?bot|captcha|just a moment", re.I),
  "SOCIAL": re.compile(r"instagram\.com|twitter\.com|tiktok", re.I),
}
c = Counter(); examples = {k:[] for k in rxs}
n=0
with chunks.open() as f:
    for line in f:
        n+=1
        d=json.loads(line)
        t=d.get("text") or ""
        fuente=d.get("fuente") or "?"
        for k,rx in rxs.items():
            if rx.search(t) or rx.search(fuente):
                c[k]+=1
                if len(examples[k])<8:
                    examples[k].append(fuente)
print("chunks", n)
print(dict(c))
Path(out/"04_index_l1_contaminacion.json").write_text(
    json.dumps({"n":n, "counts":dict(c), "examples":examples}, indent=2, ensure_ascii=False),
    encoding="utf-8"
)
# fuentes únicas contaminadas
fuentes=Counter()
with chunks.open() as f:
    for line in f:
        d=json.loads(line)
        t=d.get("text") or ""; fuente=d.get("fuente") or "?"
        if any(rx.search(t) or rx.search(fuente) for rx in rxs.values()):
            fuentes[fuente]+=1
with (out/"04_index_l1_fuentes_contaminadas.tsv").open("w") as f:
    f.write("n\tfuente\n")
    for k,v in fuentes.most_common(200):
        f.write(f"{v}\t{k}\n")
print("fuentes_contaminadas", len(fuentes))
PY

# -----------------------------------------------------------------------------
# 5. Clasificación preliminar KEEP / REVISION / BORRAR_CANDIDATO
# -----------------------------------------------------------------------------
echo "[5/6] Clasificación preliminar..."
"$PY" << 'PY'
import os, json, csv
from pathlib import Path
from collections import Counter
out = Path(os.environ["OUT"])

# load basura hits
basura = {}
p = out/"03_basura_contenido.tsv"
if p.exists():
    for i,line in enumerate(p.read_text(errors="ignore").splitlines()):
        if i==0: continue
        parts=line.split("\t", 3)
        if len(parts)<3: continue
        flags, size, path = parts[0], parts[1], parts[2]
        basura[path]=flags

# load dup suffix
dup = set()
p = out/"02_nombres_sospechosos.tsv"
if p.exists():
    for i,line in enumerate(p.read_text(errors="ignore").splitlines()):
        if i==0: continue
        parts=line.split("\t", 2)
        if len(parts)<3: continue
        flags, path = parts[0], parts[2]
        if "DUP_SUFFIX" in flags or "NOMBRE_SOCIAL" in flags or "NOMBRE_ERROR_HTTP" in flags:
            dup.add(path)

rows_out = []
counts = Counter()
for line in (out/"01_all_docs.tsv").read_text(errors="ignore").splitlines():
    if not line.strip(): continue
    size, date, path = line.split("\t", 2)
    size=int(size)
    accion = "KEEP"
    razones = []

    # basura estructural / desparramado
    if "/_archivo/limpieza_" in path or "/venv" in path or "/site-packages" in path:
        accion = "BORRAR_CANDIDATO"; razones.append("limpieza_o_venv_archivado")
    elif "/llama.cpp/" in path and path.endswith((".cpp",".h",".o",".cu")):
        continue  # skip code noise if any slipped
    elif path in basura:
        flags = basura[path]
        if any(x in flags for x in ["FACEBOOK","HTTP_ERROR","SCRAPE_BASURA","VACIO_CORTO","URL_META"]):
            accion = "BORRAR_CANDIDATO"; razones.append("contenido:"+flags)
        elif "SOCIAL" in flags:
            accion = "REVISION"; razones.append("contenido:"+flags)
    if path in dup:
        if accion == "KEEP":
            accion = "REVISION"
        razones.append("nombre_dup_o_social")

    # ZIM = capa general, no borrar
    if "/corpus/zim/" in path:
        accion = "KEEP"; razones = ["capa_GENERAL_zim"]

    # CLACSO MCC-like always revision if marked delete by mistake? prefer KEEP for pdf in corpora
    if "/TEKTRON_EVALUACION_CLACSO/corpora" in path and accion == "BORRAR_CANDIDATO" and "contenido:VACIO" not in ",".join(razones):
        # only keep delete if facebook/http error
        if not any(x in ",".join(razones) for x in ["FACEBOOK","HTTP_ERROR","SCRAPE"]):
            accion = "REVISION"; razones.append("clacso_corpora_proteger")

    # F12 raw pdfs default KEEP unless basura fuerte
    if "/Corpus_Tektron_F12/" in path and accion == "REVISION" and "contenido:" not in ",".join(razones):
        pass

    counts[accion]+=1
    rows_out.append({
        "accion": accion,
        "size": size,
        "date": date,
        "razones": "|".join(razones) if razones else "",
        "path": path,
    })

with (out/"05_clasificacion.csv").open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=["accion","size","date","razones","path"])
    w.writeheader(); w.writerows(rows_out)

# listas separadas
for accion in ["BORRAR_CANDIDATO","REVISION","KEEP"]:
    subset = [r for r in rows_out if r["accion"]==accion]
    with (out/f"05_{accion.lower()}.tsv").open("w", encoding="utf-8") as f:
        f.write("size\tdate\trazones\tpath\n")
        for r in sorted(subset, key=lambda x: -x["size"])[:2000]:
            f.write(f"{r['size']}\t{r['date']}\t{r['razones']}\t{r['path']}\n")

print(dict(counts))
print("total_clasificados", len(rows_out))
PY

# -----------------------------------------------------------------------------
# 6. Reporte humano
# -----------------------------------------------------------------------------
echo "[6/6] Escribiendo AUDIT_REPORT.md..."
"$PY" << 'PY'
import os, json
from pathlib import Path
out = Path(os.environ["OUT"])
parts = []
parts.append("# AUDITORÍA PROFUNDA TEKTRON\n")
parts.append(f"Directorio: `{out}`\n")
parts.append("**Nada se borró.** Las acciones son candidatas para revisión humana.\n")

p = out/"01_por_arbol.md"
if p.exists(): parts.append(p.read_text())

parts.append("\n## Basura en contenido (muestra escaneada)\n")
p = out/"03_basura_stats.json"
if p.exists():
    parts.append("```json\n"+p.read_text()+"\n```\n")

parts.append("\n## Contaminación ya dentro de index_l1\n")
p = out/"04_index_l1_contaminacion.json"
if p.exists():
    parts.append("```json\n"+p.read_text()+"\n```\n")

parts.append("\n## Clasificación preliminar\n")
p = out/"05_clasificacion.csv"
if p.exists():
    from collections import Counter
    c=Counter()
    for i,line in enumerate(p.read_text().splitlines()):
        if i==0: continue
        c[line.split(",",1)[0]] += 1
    for k,v in c.most_common():
        parts.append(f"- **{k}**: {v}")

parts.append("\n## Archivos clave para revisar\n")
parts.append("- `05_borrar_candidato.tsv` — candidatos a borrar (facebook/404/dup/venv)\n")
parts.append("- `05_revision.tsv` — revisar a mano\n")
parts.append("- `05_keep.tsv` — muestra keep\n")
parts.append("- `03_basura_contenido.tsv` — evidencia de corrupción\n")
parts.append("- `02_duplicados_*.tsv` — desparramado / duplicados\n")
parts.append("- `04_index_l1_fuentes_contaminadas.tsv` — ya indexado y tóxico\n")

parts.append("\n## Orden sugerido de limpieza (después de revisar TSVs)\n")
parts.append("1. Quitar de **index_l1** las fuentes contaminadas (reindex/curación), no solo borrar PDF.\n")
parts.append("2. Borrar o aislar `*_dup1_dup1*` tras confirmar que el original existe.\n")
parts.append("3. Mover basura facebook/404 a `_archivo/cuarentena_fecha/` (no rm -rf a ciegas).\n")
parts.append("4. No tocar `corpus/zim/` ni PDFs MCC en CLACSO corpora.\n")
parts.append("5. `_archivo/limpieza_*` y venvs viejos: candidatos a borrar solo si necesitas espacio.\n")

(out/"AUDIT_REPORT.md").write_text("\n".join(parts), encoding="utf-8")
print((out/"AUDIT_REPORT.md").read_text()[:2500])
PY

echo
echo "=============================================="
echo "LISTO. Revisa y trae a la iMac:"
echo "  $OUT/AUDIT_REPORT.md"
echo "  $OUT/05_borrar_candidato.tsv"
echo "  $OUT/03_basura_contenido.tsv"
echo "  $OUT/04_index_l1_fuentes_contaminadas.tsv"
echo "=============================================="
echo "$OUT" >"$OUT/OUT_DIR.txt"
