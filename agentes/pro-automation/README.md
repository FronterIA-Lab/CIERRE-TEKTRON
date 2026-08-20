# Agente Pro-Automation (demo gerente de producción)

**Esto NO es el cierre de TEKTRON.**  
Paquete aparte: agente dedicado para muestra ante un gerente de producción de una empresa de automatización industrial (**Pro-Automation**).

| TEKTRON (otra rama / otro plan) | Este agente |
|--------------------------------|-------------|
| Analista situado HEG↔SIT + MCC | Experto en **piso de producción / automatización** |
| Corpus andamiaje + FAISS Jetson | Pack de conocimiento industrial **estándar** (OEE, TPM, Lean, MES…) |
| Cierre de índice en curso | Demo independiente; opcionalmente *después* puede llamar a TEKTRON |

Sin documentos de la planta: el agente **no inventa** OEE ni scrap de Pro-Automation. Usa marco experto + pregunta qué datos faltan.

## Arranque rápido (demo local)

```bash
cd agentes/pro-automation
python3 app/cli.py
# o
python3 app/cli.py --pregunta "¿Cómo descompongo un OEE del 65%?"
```

UI estática (abrir en navegador):

```bash
open demo.html   # macOS
# o: python3 -m http.server 8765  → http://127.0.0.1:8765/demo.html
```

## Contenido

- `ARQUITECTURA.md` — capas, límites, relación opcional con TEKTRON  
- `CONOCIMIENTO_REQUERIDO.md` — qué debe saber un gerente de producción (sector)  
- `prompts/system.md` — persona y reglas del agente  
- `knowledge/*.md` — pack TEC de referencia (público/estándar)  
- `app/cli.py` — CLI sin depender del bridge Jetson  

## Para tu hermano (gerente)

1. Demo con preguntas de marco (OEE, paros, CAPEX de celda).  
2. Cuando envíe PDFs/KPIs de planta → capa **sesión / memoria de usuario** (no corpus TEKTRON).  
3. Si quieren análisis dual crítico (automatizar vs capacidad social/técnica) → enganche opcional a TEKTRON **después** del cierre.
