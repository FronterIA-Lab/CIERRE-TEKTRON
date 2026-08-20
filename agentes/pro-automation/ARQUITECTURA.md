# Arquitectura — Agente Pro-Automation

## Objetivo de la demo

Asistir a un **gerente de producción** en una empresa de automatización industrial con:

- Diagnóstico operativo (OEE, paros, calidad, capacidad)
- Lenguaje de automatización / celdas / MES sin vender humo I4.0
- Honestidad: sin datos de planta → marco + qué medir, no cifras inventadas

## Capas (separadas a propósito)

```
┌─────────────────────────────────────────────┐
│  UI demo (demo.html / CLI)                  │
├─────────────────────────────────────────────┤
│  Agente Pro-Automation                      │
│  · system prompt (gerente producción)       │
│  · pack knowledge/ (OEE, TPM, Lean, MES)    │
│  · reglas: no inventar datos de planta      │
├─────────────────────────────────────────────┤
│  Sesión usuario (futuro)                    │
│  · PDFs/KPIs que envíe el gerente            │
│  · NUNCA se mezcla con andamiaje TEKTRON    │
├─────────────────────────────────────────────┤
│  Opcional más adelante: TEKTRON              │
│  · solo si hay disputa HEG↔SIT / MCC        │
│  · no requerido para la demo de producción  │
└─────────────────────────────────────────────┘
```

## Qué NO hace este agente

- No toca `index_l1`, FAISS, Zenodo ni scripts de cierre TEKTRON.  
- No asume layout, scrap u OEE de Pro-Automation sin evidencia.  
- No sustituye PLC/MES/SCADA; asesora y estructura decisiones.

## Polo de conocimiento

Todo el pack es **TÉCNICO / operacional** (exactitud de métodos industriales).  
No relativizar fórmulas de OEE ni normas de seguridad.

## Flujo de conversación

1. Clasificar intención: diagnóstico | KPI | automatización | CAPEX | gente/cambio | fuera de dominio.  
2. Recuperar 1–3 fichas de `knowledge/`.  
3. Responder con: marco → checklist → datos que faltan → siguiente paso.  
4. Si pide “datos de *mi* planta” sin archivo → declarar insuficiencia (equivalente N0 operativo).

## Enganche futuro a TEKTRON (opcional)

Solo cuando el cierre Jetson esté estable:

- Endpoint TEKTRON `/analizar` para tensiones (p. ej. “automatizar toda la línea” vs “capacidad real del equipo”).  
- Este agente sigue siendo el front de producción; TEKTRON no es el chatbot de OEE.
