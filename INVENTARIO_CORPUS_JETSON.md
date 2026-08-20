# INVENTARIO TOTAL DEL CORPUS — Jetson TEKTRON

**Cuándo:** ANTES del Gate y como núcleo del cierre. Sin este inventario no hay Acta válida.  
**Dónde ejecutar:** en la Jetson, como usuario `tektron`, desde `/mnt/tektron`.  
**Principio:** el corpus fuente y el índice son capas distintas. Si “el otro sistema nunca tocó el corpus”, los PDF/ZIM/txt siguen en disco; lo que está mal es el *puente* corpus→chunks→FAISS.

---

## 0. Preparación (una sola vez)

```bash
cd /mnt/tektron
mkdir -p /mnt/tektron/workspace/inventario_$(date +%Y%m%d)
INV=/mnt/tektron/workspace/inventario_$(date +%Y%m%d)
echo "INV=$INV" | tee "$INV/00_env.txt"
df -h /mnt/tektron | tee -a "$INV/00_env.txt"
uname -a | tee -a "$INV/00_env.txt"
```

Todo lo que sigue escribe en `$INV`. Si reinicias la shell:

```bash
cd /mnt/tektron
INV=$(ls -d /mnt/tektron/workspace/inventario_* | sort | tail -1)
echo "$INV"
```

---

## 1. Mapa de disco (qué pesa y dónde)

```bash
# Árbol de primer nivel
du -sh /mnt/tektron/*/ 2>/dev/null | sort -rh | tee "$INV/01_du_top.txt"

# Segundo nivel de los pesados
for d in corpus _clacso_archivo _archivo _snapshots index_l1 index_l1_precuracion_20260819 models; do
  echo "════ /$d ════"
  du -sh /mnt/tektron/$d/*/ 2>/dev/null | sort -rh | head -30
done | tee "$INV/01_du_detail.txt"
```

---

## 2. Hallar TODO documento fuente (no índices)

```bash
# Conteos por extensión en todo /mnt/tektron (puede tardar)
find /mnt/tektron -type f \( \
  -iname "*.pdf" -o -iname "*.txt" -o -iname "*.md" -o -iname "*.epub" \
  -o -iname "*.html" -o -iname "*.jsonl" -o -iname "*.json" \
  -o -iname "*.zim" -o -iname "*.xml" -o -iname "*.xml.bz2" \
  -o -iname "*.warc" -o -iname "*.parquet" -o -iname "*.arrow" \
  -o -iname "*.faiss" -o -iname "*.idx" -o -iname "*.pkl" -o -iname "*.bin" \
\) 2>/dev/null \
| sed 's/.*\.//' | tr 'A-Z' 'a-z' | sort | uniq -c | sort -rn \
| tee "$INV/02_ext_counts.txt"
```

```bash
# Inventario de documentos “legibles” con ruta + tamaño + mtime
find /mnt/tektron/corpus /mnt/tektron/_clacso_archivo /mnt/tektron/_archivo \
  /mnt/tektron/staging /mnt/tektron/workspace \
  -type f \( -iname "*.pdf" -o -iname "*.txt" -o -iname "*.md" -o -iname "*.epub" \
            -o -iname "*.zim" -o -iname "*.xml.bz2" -o -iname "*.html" \) \
  -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null \
| sort -k3 | tee "$INV/02_docs_mtime.tsv"

wc -l "$INV/02_docs_mtime.tsv"
# bytes totales de esos docs
awk '{s+=$1} END {printf "bytes=%.2f GB\n", s/1024/1024/1024}' "$INV/02_docs_mtime.tsv"
```

```bash
# Solo corpus/ y CLACSO (los ENTRA candidatos)
find /mnt/tektron/corpus -type f \( -iname "*.pdf" -o -iname "*.txt" -o -iname "*.md" -o -iname "*.epub" \) \
  -printf '%s\t%p\n' 2>/dev/null | tee "$INV/02_corpus_docs.tsv"
find /mnt/tektron/_clacso_archivo -type f -iname "*.pdf" -printf '%s\t%p\n' 2>/dev/null \
  | tee "$INV/02_clacso_docs.tsv"
echo "corpus docs: $(wc -l < "$INV/02_corpus_docs.tsv")"
echo "clacso docs: $(wc -l < "$INV/02_clacso_docs.tsv")"
```

```bash
# Estructura de carpetas del corpus (graneros / namespaces)
find /mnt/tektron/corpus -maxdepth 3 -type d 2>/dev/null | sort | tee "$INV/02_corpus_dirs.txt"
find /mnt/tektron/_clacso_archivo -maxdepth 3 -type d 2>/dev/null | sort | tee "$INV/02_clacso_dirs.txt"
```

---

## 3. Buscar la “Wikipedia / conocimiento general” (GitHub / ZIM / dumps)

Candidatos típicos: Kiwix `.zim`, dump `enwiki`/`eswiki`, `wiki-rag` (RoyRin/HF FAISS), `zim-llm`, carpetas `wikipedia`, `wiki`, `kiwix`, `conocimiento_general`.

```bash
# Por nombre de ruta
find /mnt/tektron /home /opt /var /media /mnt -iname '*wiki*' 2>/dev/null \
  | grep -vE 'venv|site-packages|__pycache__|\.git/' \
  | head -200 | tee "$INV/03_paths_wiki.txt"

find /mnt/tektron /home /opt /var /media /mnt -iname '*kiwix*' 2>/dev/null \
  | head -100 | tee -a "$INV/03_paths_wiki.txt"

find /mnt/tektron /home /opt /var /media /mnt -iname '*zim*' 2>/dev/null \
  | grep -vE 'venv|site-packages' | head -100 | tee -a "$INV/03_paths_wiki.txt"
```

```bash
# Archivos ZIM / dumps Wikipedia (el “tipo Wikipedia” offline)
find /mnt/tektron /home /opt /var /media /mnt -type f \( \
  -iname "*.zim" -o -iname "*wiki*.xml*" -o -iname "*enwiki*" -o -iname "*eswiki*" \
  -o -iname "*wikipedia*" -o -iname "*pageviews*" \
\) 2>/dev/null | tee "$INV/03_wiki_files.txt"

# Si hay ZIM, tamaño
xargs -a "$INV/03_wiki_files.txt" -r ls -lh 2>/dev/null | tee "$INV/03_wiki_files_ls.txt"
```

```bash
# Índices FAISS / HF tipo wiki-rag (conocimiento general preconstruido)
find /mnt/tektron /home /opt /var /media /mnt -type d \( \
  -iname '*wiki*rag*' -o -iname '*wiki_index*' -o -iname '*wiki-rag*' \
  -o -iname '*conocimiento*' -o -iname '*general*know*' -o -iname '*hf*wiki*' \
\) 2>/dev/null | tee "$INV/03_wiki_index_dirs.txt"

find /mnt/tektron -type f \( -iname '*wiki*.idx' -o -iname '*wiki*.faiss' \
  -o -iname 'faiss_unificado*' -o -iname '*minilm*' \) 2>/dev/null \
  | tee "$INV/03_wiki_faiss.txt"
```

```bash
# Rastrear origen GitHub / HuggingFace en el disco
grep -RIl -E 'github\.com|huggingface\.co|kiwix|wikimedia|wiki-rag|zim-llm|karpathy|llm-wiki' \
  /mnt/tektron --include='*.md' --include='*.txt' --include='*.json' --include='*.py' \
  --include='*.yml' --include='*.yaml' --include='*.sh' --include='*.log' \
  2>/dev/null | grep -vE 'venv|_archivo/venv|site-packages' \
  | head -80 | tee "$INV/03_origin_refs.txt"

# Historial de descargas en shell
grep -hE 'wiki|kiwix|zim|huggingface|git clone|wget|aria2|hf_hub' \
  /home/tektron/.bash_history /root/.bash_history 2>/dev/null \
  | sort -u | tee "$INV/03_shell_history_downloads.txt"
```

```bash
# ¿Aparece Wikipedia DENTRO del índice vivo? (si sí, contaminó andamiaje)
grep -ci -E 'wikipedia|wiktionary|wiki\.org' /mnt/tektron/index_l1/chunks.jsonl 2>/dev/null \
  | tee "$INV/03_wiki_in_index_l1.txt"
# Muestra de fuentes
grep -i -E 'wikipedia|wiktionary' /mnt/tektron/index_l1/chunks.jsonl 2>/dev/null \
  | /mnt/tektron/venv_tektron/bin/python3 -c '
import sys,json
from collections import Counter
c=Counter()
for line in sys.stdin:
  try: d=json.loads(line); c[d.get("fuente","?")]+=1
  except: pass
for k,v in c.most_common(30): print(v, k)
' | tee "$INV/03_wiki_fuentes_en_l1.txt"
```

**Política TEKTRON (Arquitectura punto 5):** Wikipedia / enciclopedia genérica **sin estructura de disputa** es `NO ENTRA` al andamiaje `index_l1` (HEG/SIT). Si existe en disco, debe vivir como **capa separada** (`conocimiento_general/` o índice propio), no mezclada con Árboles. Encontrarla ≠ meterla en L1.

---

## 4. Inventario de TODOS los índices (lo que “tocó” el corpus)

```bash
# Todos los chunks.jsonl / faiss / bm25 / meta
find /mnt/tektron -type f \( \
  -name 'chunks.jsonl' -o -name 'faiss.idx' -o -name '*.faiss' \
  -o -name 'bm25*.pkl' -o -name 'meta.json' -o -name '*unificado*' \
\) 2>/dev/null | grep -vE 'venv|site-packages' | sort | tee "$INV/04_all_indexes.txt"
```

```bash
# Por cada chunks.jsonl: líneas + tamaño + fecha
while IFS= read -r f; do
  [[ "$f" == *chunks.jsonl ]] || continue
  printf '%8d  %10s  %s  %s\n' \
    "$(wc -l < "$f")" \
    "$(du -h "$f" | cut -f1)" \
    "$(date -r "$f" +%Y-%m-%d 2>/dev/null || stat -c %y "$f" | cut -d' ' -f1)" \
    "$f"
done < "$INV/04_all_indexes.txt" | sort -rn | tee "$INV/04_chunks_inventory.txt"

echo "─── SUMA LÍNEAS ───"
awk '{s+=$1} END{print s}' "$INV/04_chunks_inventory.txt"
```

```bash
# meta.json de cada índice
for m in $(find /mnt/tektron -name meta.json 2>/dev/null | grep -vE 'venv|site-packages'); do
  echo "════ $m ════"
  /mnt/tektron/venv_tektron/bin/python3 -c "
import json
d=json.load(open('$m'))
keys=['n_chunks','n_sit','n_heg','n_tec','dim','created_utc','model','embedding','fuente']
print({k:d.get(k) for k in keys})
print('keys:', sorted(d.keys())[:40])
"
done 2>/dev/null | tee "$INV/04_meta_dump.txt"
```

```bash
# Índice unificado (segunda indexación)
ls -la /mnt/tektron/_archivo/index_unificado_minilm_20260818/ 2>/dev/null | tee "$INV/04_unificado_ls.txt"
wc -l /mnt/tektron/_archivo/index_unificado_minilm_20260818/chunks_unificados.jsonl 2>/dev/null
head -1 /mnt/tektron/indexar_unificado.py 2>/dev/null
sed -n '1,120p' /mnt/tektron/indexar_unificado.py 2>/dev/null | tee "$INV/04_indexar_unificado_head.py"
```

---

## 5. ¿El índice refleja el corpus? (prueba de desconexión)

```bash
# Fuentes únicas en index_l1 vivo
/mnt/tektron/venv_tektron/bin/python3 << 'PY' | tee "$INV/05_fuentes_index_l1.txt"
import json
from collections import Counter, defaultdict
fuentes=Counter(); polos=Counter(); graneros=Counter()
n=0
with open("/mnt/tektron/index_l1/chunks.jsonl") as f:
    for line in f:
        d=json.loads(line); n+=1
        fuentes[d.get("fuente","?")] += 1
        polos[d.get("tipo_epistemico","?")] += 1
        graneros[d.get("canon_id","?")] += 1
print("chunks", n)
print("fuentes_unicas", len(fuentes))
print("polos", dict(polos))
print("graneros top20:")
for k,v in graneros.most_common(20): print(f"  {v}\t{k}")
print("fuentes top30:")
for k,v in fuentes.most_common(30): print(f"  {v}\t{k}")
open("/mnt/tektron/workspace/inventario_tmp_fuentes.txt","w").write("\n".join(sorted(fuentes)))
PY
# mover si INV ya definido
cp /mnt/tektron/workspace/inventario_tmp_fuentes.txt "$INV/05_fuentes_list.txt" 2>/dev/null || true
```

```bash
# Basenames de PDFs en corpus/ vs menciones en fuentes del índice
find /mnt/tektron/corpus -type f -iname "*.pdf" -printf '%f\n' 2>/dev/null \
  | sort -u > "$INV/05_pdf_basenames_corpus.txt"
find /mnt/tektron/_clacso_archivo -type f -iname "*.pdf" -printf '%f\n' 2>/dev/null \
  | sort -u > "$INV/05_pdf_basenames_clacso.txt"

# ¿Cuántos PDFs del corpus aparecen (substring) en alguna fuente indexada?
/mnt/tektron/venv_tektron/bin/python3 << PY
from pathlib import Path
inv = Path("$INV")
fuentes = (inv/"05_fuentes_list.txt").read_text(errors="ignore").lower().splitlines()
fuentes_blob = "\n".join(fuentes)
for label in ["corpus", "clacso"]:
    pdfs = (inv/f"05_pdf_basenames_{label}.txt").read_text(errors="ignore").splitlines()
    hit=miss=0
    misses=[]
    for p in pdfs:
        stem = p.rsplit(".",1)[0][:60].lower()
        if stem and stem in fuentes_blob:
            hit += 1
        else:
            miss += 1
            if len(misses)<30: misses.append(p)
    print(f"{label}: pdfs={len(pdfs)} hit_approx={hit} miss_approx={miss}")
    print("  miss sample:", misses[:10])
PY
```

Si `miss_approx` ≈ total de PDFs → **el corpus nunca entró al índice vivo** (confirmación de tu hipótesis).

---

## 6. Graneros pre_f15 vs index_l1 vs unificado (tres generaciones)

```bash
echo "=== pre_f15 por granero ===" | tee "$INV/06_generaciones.txt"
for f in $(find /mnt/tektron/_archivo/corpus_pre_f15_20260814 -name "chunks.jsonl"); do
  printf "%8d  %s\n" $(wc -l < "$f") "$f"
done | sort -rn | tee -a "$INV/06_generaciones.txt"

echo "=== index_l1 vivo ===" | tee -a "$INV/06_generaciones.txt"
wc -l /mnt/tektron/index_l1/chunks.jsonl | tee -a "$INV/06_generaciones.txt"

echo "=== precuracion ===" | tee -a "$INV/06_generaciones.txt"
wc -l /mnt/tektron/index_l1_precuracion_20260819/chunks.jsonl 2>/dev/null | tee -a "$INV/06_generaciones.txt"

echo "=== unificado ===" | tee -a "$INV/06_generaciones.txt"
wc -l /mnt/tektron/_archivo/index_unificado_minilm_20260818/chunks_unificados.jsonl 2>/dev/null | tee -a "$INV/06_generaciones.txt"
```

```bash
# Schema de un chunk de cada generación (campos)
for f in \
  /mnt/tektron/index_l1/chunks.jsonl \
  /mnt/tektron/index_l1_precuracion_20260819/chunks.jsonl \
  /mnt/tektron/_archivo/index_unificado_minilm_20260818/chunks_unificados.jsonl \
  $(find /mnt/tektron/_archivo/corpus_pre_f15_20260814 -name chunks.jsonl | head -1)
do
  echo "════ $f ════"
  /mnt/tektron/venv_tektron/bin/python3 -c "
import json,sys
d=json.loads(open('$f').readline())
print(sorted(d.keys()))
print({k:d.get(k) for k in ['fuente','tipo_epistemico','canon_id','polo','source','title','path'] if k in d or True})
print((d.get('text') or d.get('contenido') or '')[:200])
" 2>/dev/null
done | tee "$INV/06_schema_chunks.txt"
```

---

## 7. Scripts de indexación (qué path leyeron)

```bash
ls -la /mnt/tektron/*.py /mnt/tektron/src/*.py /mnt/tektron/tools/*.py 2>/dev/null \
  | tee "$INV/07_scripts.txt"

grep -RIn -E 'corpus/|_clacso|chunks\.jsonl|faiss|index_l1|unificado|wikipedia|zim|granero' \
  /mnt/tektron --include='*.py' --include='*.sh' \
  2>/dev/null | grep -vE 'venv|_archivo/venv|site-packages' \
  | tee "$INV/07_scripts_refs.txt"
```

```bash
# Logs de indexación / curación
find /mnt/tektron/logs /mnt/tektron -maxdepth 2 -type f \( -iname '*index*' -o -iname '*cura*' -o -iname '*build*' \) \
  2>/dev/null | head -50 | tee "$INV/07_logs.txt"
ls -lt /mnt/tektron/logs 2>/dev/null | head -40
```

---

## 8. Depuración: clasificar ENTRA / NO ENTRA / GENERAL / HUÉRFANO

```bash
/mnt/tektron/venv_tektron/bin/python3 << 'PY' | tee "$INV/08_clasificacion_preliminar.txt"
"""Clasificación PRELIMINAR por path — no borra nada."""
from pathlib import Path
import re

ROOT = Path("/mnt/tektron")
rules = [
  ("ENTRA_SIT", re.compile(r"clacso|epistemolog|quijano|dussel|mignolo|rivera|santos|extractiv|territorio|soberan", re.I)),
  ("ENTRA_HEG", re.compile(r"legal|ley_|convenio|constituc|dof|tratado|nagoya|minera|cpeum|scjn", re.I)),
  ("ENTRA_TEC", re.compile(r"siemens|modbus|plc|nom-|opc-?ua|manual_tecn", re.I)),
  ("ENTRA_MCC", re.compile(r"mcc|grieta|calibracion_contextual|arbol_de_espejos", re.I)),
  ("GENERAL_WIKI", re.compile(r"wiki|kiwix|\.zim$|enwiki|eswiki|wiktionary|openstax", re.I)),
  ("INDICE", re.compile(r"chunks\.jsonl|faiss|\.idx$|bm25|index_l1|unificado", re.I)),
  ("BASURA", re.compile(r"404|anti-bot|url:|captcha", re.I)),
]

buckets = {k: [] for k,_ in rules}
buckets["OTRO"] = []

roots = [ROOT/"corpus", ROOT/"_clacso_archivo", ROOT/"_archivo", ROOT/"staging"]
for root in roots:
  if not root.exists(): continue
  for p in root.rglob("*"):
    if not p.is_file(): continue
    if p.suffix.lower() not in {".pdf",".txt",".md",".epub",".zim",".jsonl",".html"}: continue
    s = str(p)
    hit = None
    for name, rx in rules:
      if rx.search(s):
        hit = name; break
    buckets[hit or "OTRO"].append(s)

for k,v in buckets.items():
  print(f"{k}: {len(v)}")
  for x in v[:8]:
    print(f"  {x}")
  if len(v)>8: print(f"  ... +{len(v)-8}")
PY
```

**No borrar en este paso.** Solo generar listas. La limpieza se hace con asignación revisada (KEEP / FUERA / GENERAL_NS / REINDEX).

---

## 9. Probes de cobertura ENTRA (qué falta descargar)

```bash
# En disco (paths)
for term in Quijano "Convenio 169" "Ley Minera" Nagoya MCC "grieta generativa" \
  Modbus Siemens CLACSO "Via Campesina" OCMAL wikipedia kiwix; do
  echo -n "PATH $term: "
  find /mnt/tektron/corpus /mnt/tektron/_clacso_archivo -iname "*${term}*" 2>/dev/null | wc -l
done | tee "$INV/09_probes_path.txt"

# En índice vivo (texto)
for term in Quijano "Convenio 169" "Ley Minera" Nagoya "grieta generativa" \
  "certeza sin sustancia" "soberanía cognitiva" "árbol de espejos" Modbus; do
  echo -n "INDEX $term: "
  grep -ci "$term" /mnt/tektron/index_l1/chunks.jsonl 2>/dev/null || echo 0
done | tee "$INV/09_probes_index.txt"
```

Interpretación:

| PATH | INDEX | Acción |
|------|-------|--------|
| >0 | >0 | OK conectado |
| >0 | 0 | **Reindexar** ese material (corpus intacto, puente roto) |
| 0 | 0 | **Descargar / agregar** (hueco real) |
| 0 | >0 | Índice huérfano / basura — revisar FUERA |

---

## 10. Reporte único de cierre de inventario

```bash
/mnt/tektron/venv_tektron/bin/python3 << PY
import json, datetime
from pathlib import Path
inv = Path("$INV")
report = {
  "fecha": datetime.datetime.now().isoformat(),
  "inv_dir": str(inv),
  "archivos_generados": sorted(p.name for p in inv.iterdir()),
  "hipotesis_corpus": "RELLENAR: DESCONECTADO | DELGADO | WIKI_PERDIDA | WIKI_EN_L1_CONTAMINA | OK",
  "wiki_encontrada": "RELLENAR path o NO",
  "index_l1_chunks": None,
  "unificado_chunks": None,
  "pre_f15_total": None,
  "pdfs_corpus": None,
  "pdfs_clacso": None,
  "siguiente": "depurar listas → reindexar ENTRA → wiki a namespace GENERAL si existe → Gate v8",
}
# auto-fill si existen
try:
  report["index_l1_chunks"] = sum(1 for _ in open("/mnt/tektron/index_l1/chunks.jsonl"))
except: pass
try:
  report["pdfs_corpus"] = sum(1 for _ in open(inv/"02_corpus_docs.tsv"))
  report["pdfs_clacso"] = sum(1 for _ in open(inv/"02_clacso_docs.tsv"))
except: pass
out = inv/"10_CORPUS_INVENTORY_REPORT.json"
out.write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(out)
print(json.dumps(report, indent=2, ensure_ascii=False))
PY
```

---

## 11. Orden operativo después del inventario

1. Leer `$INV/10_CORPUS_INVENTORY_REPORT.json` + `05_*` (desconexión).
2. Si Wikipedia/ZIM/wiki-rag aparece → moverla o indexarla en **namespace `GENERAL`**, nunca mezclar en `index_l1` dual.
3. Todo PATH>0 INDEX=0 ENTRA → cola de **reindexación** (el corpus no se toca; se reconstruye el puente).
4. PATH=0 INDEX=0 en probes del mapa → cola de **descarga**.
5. Solo entonces: curación FUERA, calibración N0, Gate v8.

---

## One-liner: corrida completa (copiar/pegar)

```bash
cd /mnt/tektron && INV=/mnt/tektron/workspace/inventario_$(date +%Y%m%d) && mkdir -p "$INV" && \
du -sh /mnt/tektron/*/ 2>/dev/null | sort -rh | tee "$INV/01_du_top.txt" && \
find /mnt/tektron/corpus /mnt/tektron/_clacso_archivo -type f \( -iname "*.pdf" -o -iname "*.txt" -o -iname "*.md" -o -iname "*.epub" -o -iname "*.zim" \) -printf '%s\t%TY-%Tm-%Td\t%p\n' 2>/dev/null | tee "$INV/02_docs_mtime.tsv" && \
find /mnt/tektron /home /opt -type f \( -iname "*.zim" -o -iname "*wikipedia*" -o -iname "*enwiki*" -o -iname "*eswiki*" -o -iname "*wiki*rag*" \) 2>/dev/null | tee "$INV/03_wiki_files.txt" && \
find /mnt/tektron -type f \( -name 'chunks.jsonl' -o -name 'faiss.idx' -o -name 'meta.json' -o -name '*unificado*' \) 2>/dev/null | grep -vE 'venv|site-packages' | sort | tee "$INV/04_all_indexes.txt" && \
echo "INV listo en $INV — continuar con secciones 5-10 del playbook"
```

Luego ejecuta las secciones **5 → 10** del mismo archivo (prueba de desconexión, generaciones, probes, reporte).
