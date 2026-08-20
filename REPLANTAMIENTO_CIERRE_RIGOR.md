# REPLANTAMIENTO DEL CIERRE — rigor (2026-08-20)

## Veredicto

El cierre **no** falló por “el bridge caído” ni por “faltan chunks MCC”.
Falló porque se mutó `index_l1` **sin el contrato de runtime** (`retrieve_l1.IndexL1`),
y luego se intentó silenciar el síntoma (`AssertionError n_sit`) con parches.

**Congelado a partir de ahora:** no correr reconcile / align-meta / rebuild FAISS /
restart systemd “para ver” / indexar de nuevo, hasta completar el Gate G0.

---

## 1. Qué sí sabemos (evidencia)

### Arquitectura viva

```
chunks.jsonl  +  meta.json  +  faiss.idx
        ↓
 retrieve_l1.IndexL1   ← auditor de invariantes (Jetson, NO está en este repo)
        ↓
 tektron_bridge_l1.py :8000  →  tektron_backend :8001
```

### Hecho medido en Jetson (reconcile dry-run / apply)

| Dato | Valor |
|------|-------|
| `chunks.jsonl` | 12273 |
| FAISS | ntotal=12273 dim=768 **sync OK** |
| Polos crudos | HEGEMONICO 3096, TECNICO 1117, SITUADO 7373, **SIT 687** |
| meta antes | n_sit=8062 n_heg=3098 n_tec=1167 |
| meta tras Counter(SITUADO…) | n_sit=8060 n_heg=3096 n_tec=1117 |
| Smoke IndexL1 | **sigue AssertionError** en `len(set_sit)==meta["n_sit"]` |

### Conclusión lógica (sin inventar el predicado)

Si tras normalizar a `SITUADO|HEGEMONICO|TECNICO` y escribir meta = Counter(…),
el assert **sigue** fallando, entonces:

> **`IndexL1.set_sit` NO es `count(tipo_epistemico == "SITUADO")`.**

Eso invalida como “solución” cualquier script que asuma ese Counter
(`tektron_reconcile_index_l1.py`, rebuild meta, align-meta).

### Errores de diseño que cometimos

1. **Andamiaje con token `SIT`** (frontmatter Zenodo) en un L1 histórico que usa `SITUADO`.
2. **`n_sit += 687`** en meta (acumulador) en vez de censo con el predicado de IndexL1.
3. **Parches en cascada** (restart → FAISS → reconcile → align) sin leer `retrieve_l1.py`.
4. **Reconcile reescribió 12273 filas** (`cambiar 12273`) sin saber si IndexL1 lee
   `tipo_epistemico`, `polo`, ambos, u otro campo/archivo.
5. Tratar “bridge up + curl MCC” como cierre, cuando PROTOCOLO v8 exige fases 1→6.

### Qué sí era correcto (dirección)

- Poblar andamiaje MCC (`zenodo_17728016`, `21500800`, …) en Corpus Base / `00_Core`.
- FAISS alineado a mpnet-768 si eso es el `MODEL_EMBED` del retrieve vivo.
- No confundir Zenodo (host de papers) con “memoria de usuario”.

---

## 2. Qué NO sabemos (bloquea cualquier escritura)

| # | Desconocido | Por qué importa |
|---|-------------|-----------------|
| U1 | Predicado exacto de `set_sit` / `set_heg` / `set_tec` en `retrieve_l1.py` | Sin esto, meta y labels son adivinanza |
| U2 | Qué campos lee IndexL1 (`tipo_epistemico` vs `polo` vs otros) | El rewrite masivo puede haber tocado lo irrelevante u omitido lo crítico |
| U3 | Si hay más asserts (heg/tec/n_chunks/dim) | El primer assert oculta los demás |
| U4 | Contrato de `construir_index_curado.py` | Es el builder canónico; lo saltamos |
| U5 | Estado de backups `_bak_reconcile_*` vs pre_correccion | Define restore vs repair |
| U6 | Si `tektron_bridge_l1.py` duplica lógica o solo importa IndexL1 | Saber qué proceso audita |

**Hasta U1–U3 no hay “fix” legítimo.**

---

## 3. Freeze — reglas

| Acción | Estado |
|--------|--------|
| `tektron_align_meta_to_indexl1.py` | **PROHIBIDO** (invierte SoT: meta ← sets) |
| `tektron_reconcile_index_l1.py --apply` | **PROHIBIDO** hasta G0 |
| `systemctl restart tektron-bridge` | **PROHIBIDO** como “fix” (solo `stop` anti crash-loop) |
| Rebuild FAISS | **PROHIBIDO** “por si acaso” |
| Append andamiaje / correccion | **PROHIBIDO** hasta G2 |

Permitido: **solo lectura** (comandos de la §4).

---

## 4. Gate G0 — recolectar el contrato (OBLIGATORIO)

Pegar en la Jetson **exactamente** esto y devolver la salida completa.
No editar archivos.

```bash
sudo systemctl stop tektron-bridge.service 2>/dev/null || true

echo '======== FILES ========'
ls -la /mnt/tektron/retrieve_l1.py \
       /mnt/tektron/tektron_bridge_l1.py \
       /mnt/tektron/construir_index_curado.py
md5sum /mnt/tektron/retrieve_l1.py \
       /mnt/tektron/tektron_bridge_l1.py \
       /mnt/tektron/construir_index_curado.py

echo '======== retrieve_l1.py FULL (o hasta línea 250) ========'
sed -n '1,250p' /mnt/tektron/retrieve_l1.py

echo '======== grep contrato ========'
grep -nE 'set_sit|set_heg|set_tec|n_sit|n_heg|n_tec|tipo_epistemico|polo|assert|MODEL_EMBED|SentenceTransformer|class IndexL1' \
  /mnt/tektron/retrieve_l1.py

echo '======== bridge lifespan IndexL1 ========'
grep -nE 'IndexL1|retrieve_l1|INDEX_L1|lifespan|8000' /mnt/tektron/tektron_bridge_l1.py
sed -n '250,300p' /mnt/tektron/tektron_bridge_l1.py

echo '======== construir_index_curado (cabeza) ========'
sed -n '1,200p' /mnt/tektron/construir_index_curado.py
grep -nE 'from-chunks|ntotal|meta|n_sit|tipo_epistemico|abort|faiss|polo' \
  /mnt/tektron/construir_index_curado.py

echo '======== L1 + backups (no write) ========'
ls -la /mnt/tektron/index_l1/ | head -40
ls -lad /mnt/tektron/index_l1/_bak_* 2>/dev/null
ls -lad /mnt/tektron/_snapshots/pre_correccion_l1_* 2>/dev/null
wc -l /mnt/tektron/index_l1/chunks.jsonl

echo '======== censo read-only ========'
/mnt/tektron/venv_tektron/bin/python3 - <<'PY'
import json
from collections import Counter
from pathlib import Path
import faiss
l1 = Path("/mnt/tektron/index_l1")
rows = [json.loads(l) for l in l1.joinpath("chunks.jsonl").open(encoding="utf-8", errors="ignore") if l.strip()]
meta = json.loads((l1/"meta.json").read_text()) if (l1/"meta.json").exists() else {}
idx = faiss.read_index(str(l1/"faiss.idx"))
def raw(r):
    return (
        str(r.get("tipo_epistemico")),
        str(r.get("polo")),
    )
c_tipo = Counter(str(r.get("tipo_epistemico") or "?").upper() for r in rows)
c_polo = Counter(str(r.get("polo") or "?").upper() for r in rows)
print("n", len(rows), "faiss", idx.ntotal, "dim", idx.d, "sync", idx.ntotal == len(rows))
print("meta", {k: meta.get(k) for k in ("n_chunks","n_sit","n_heg","n_tec","faiss_model","reconcile_utc","align_utc")})
print("tipo_epistemico", dict(c_tipo))
print("polo", dict(c_polo))
print("has_tipo", sum(1 for r in rows if "tipo_epistemico" in r))
print("has_polo", sum(1 for r in rows if "polo" in r))
print("tipo!=polo", sum(1 for r in rows if r.get("tipo_epistemico") != r.get("polo")))
print("zenodo", sum(1 for r in rows if str(r.get("fuente","")).startswith("zenodo_")))
# muestra 3 SIT residuales si quedan
sit = [r for r in rows if str(r.get("tipo_epistemico") or r.get("polo") or "").upper() == "SIT"]
print("residual_SIT", len(sit))
if sit:
    print("sample_SIT", {k: sit[0].get(k) for k in ("fuente","tipo_epistemico","polo","granero","canon_id")})
PY
```

### Criterio G0 PASS

Se tiene en mano, pegado en el chat:

1. Cuerpo de `class IndexL1` (construcción de `set_*` + asserts).
2. `MODEL_EMBED` (o equivalente).
3. Lista de `_bak_*` / snapshots.
4. Censo actual (salida del Python read-only).

**Sin eso → no hay G1.**

---

## 5. Gates siguientes (solo después de G0)

### G1 — Estado post-mutación entendido

Comparar live vs:

- `_bak_reconcile_*` (pre-rewrite de labels)
- `_snapshots/pre_correccion_l1_*` o `index_l1_precuracion_20260819`

Pregunta: ¿el rewrite de 12273 dañó algo que IndexL1 usa?

### G2 — Elegir estrategia (una)

| Caso (según U1) | Acción |
|-----------------|--------|
| A. Solo meta desfasada; predicado claro; labels OK | Regenerar **solo meta** con el **mismo predicado** del source (no Counter inventado) |
| B. Andamiaje mal etiquetado; resto OK | Migrar **solo** filas `zenodo_*` / `origen=andamiaje_*`; meta con predicado del source |
| C. Rewrite masivo sospechoso / smoke imposible | **Restore** chunks(+meta) desde `_bak_reconcile_*` o snapshot pre_correccion; re-append andamiaje con tokens del contrato; rebuild derivados **una vez** vía `construir_index_curado` si es viable |
| D. FAISS dim ≠ MODEL_EMBED | Rebuild FAISS **una vez** con ese modelo; no antes |

**Prohibido:** `meta[n_sit] = len(set_sit)` sin migrar labels (esconde chunks fuera del dual-pole).

### G3 — Smoke de contrato

```text
IndexL1(L1) carga sin assert
len(set_*) == meta[n_*]  (todas las que el source asserta)
faiss.ntotal == len(chunks)
Top-8 “¿Qué es el MCC?” incluye zenodo_21500800 / 17728016  (en disco, sin bridge)
```

Luego **un** arranque de bridge → `/retrieve`.

### G4 — Volver al PROTOCOLO v8 (cierre real)

No declarar cerrado por un curl.

1. Fase 1: probes MCC en disco + retrieve  
2. Fase 0b resto (CLACSO / gaps del DIAGNOSTICO) si aplican  
3. Fase 2 equilibrada (no solo NO ENTRA)  
4. Fase 3: manifest SHA chunks+faiss  
5. Fase 4–6: Gate capacidad + acta  

---

## 6. Relación con PROTOCOLO v8

El atajo `tektron_correccion_cierre.sh` (cuarentena → expulsar → andamiaje → probes jsonl)
**no sustituye** Fases 0→6. Fue un correctivo táctico que rompió el invariante
meta/set al indexar con vocabulario incorrecto.

Cierre correcto = **contrato IndexL1 conocido** + L1 consistente + Gate de **capacidad**
(Árboles de Espejos + MCC + SHA), no “N0 silencioso” ni “servicio arriba”.

---

## 7. Próximo mensaje útil

Solo la salida de la §4 (G0).  
Con eso se elige A/B/C/D en G2.  
Sin eso, cualquier comando de escritura es repetición del ciclo.
