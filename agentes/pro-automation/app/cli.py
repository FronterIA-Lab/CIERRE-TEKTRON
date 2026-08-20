#!/usr/bin/env python3
"""
CLI demo — Agente Pro-Automation (sin TEKTRON / sin Jetson).

Uso:
  python3 app/cli.py
  python3 app/cli.py --pregunta "¿Cómo mejoro un OEE del 65%?"

Si OPENAI_API_KEY (u otra) no está, responde en modo plantilla + knowledge local.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KNOW = ROOT / "knowledge"
PROMPT = (ROOT / "prompts" / "system.md").read_text(encoding="utf-8")


def load_knowledge() -> list[tuple[str, str]]:
    docs = []
    for p in sorted(KNOW.glob("*.md")):
        docs.append((p.stem, p.read_text(encoding="utf-8")))
    return docs


def retrieve(question: str, docs: list[tuple[str, str]], k: int = 2) -> list[tuple[str, str]]:
    q = question.lower()
    scored = []
    for name, text in docs:
        words = set(re.findall(r"[a-záéíóúñ0-9]{4,}", q))
        blob = text.lower()
        score = sum(1 for w in words if w in blob)
        # boosts
        if "oee" in q and "oee" in blob:
            score += 5
        if any(x in q for x in ("paro", "tpm", "mtbf", "aver")) and "tpm" in blob:
            score += 5
        if any(x in q for x in ("automat", "robot", "capex", "celda")) and "capex" in blob:
            score += 5
        if any(x in q for x in ("lean", "smied", "smed", "5s", "kaizen")) and "lean" in name:
            score += 4
        if any(x in q for x in ("mes", "erp", "sap", "dato")) and "mes" in name:
            score += 4
        scored.append((score, name, text))
    scored.sort(reverse=True)
    return [(n, t) for s, n, t in scored[:k] if s > 0] or [(docs[0][0], docs[0][1])]


def template_answer(question: str, hits: list[tuple[str, str]]) -> str:
    parts = [
        "## Diagnóstico",
        "Trabajo con marco industrial estándar. No tengo aún KPIs ni layout de Pro-Automation; no inventaré cifras de tu planta.",
        "",
        "## Marco (pack local)",
    ]
    for name, text in hits:
        # first meaningful section
        snippet = "\n".join(text.strip().splitlines()[:18])
        parts.append(f"### {name}\n{snippet}\n")
    parts += [
        "## Datos que faltan de tu planta",
        "- OEE descompuesto (D / R / C) o top pérdidas de la semana",
        "- Códigos de paro / MTTR de las 3 fallas principales",
        "- Si hablas de automatizar: baseline + KPI de éxito + restricciones de safety",
        "",
        "## Siguiente paso",
        "1) Elige una línea o celda piloto. 2) Trae 1 semana de paros o un export MES. 3) Priorizamos una sola pérdida medible.",
        "",
        f"_Pregunta recibida:_ {question}",
    ]
    return "\n".join(parts)


def llm_answer(question: str, hits: list[tuple[str, str]]) -> str | None:
    """Opcional: OPENAI_API_KEY. Si falla, None → plantilla."""
    import os

    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        return None
    try:
        import urllib.request
        import json

        ctx = "\n\n".join(f"# {n}\n{t[:3000]}" for n, t in hits)
        body = {
            "model": os.environ.get("PROAUTO_MODEL", "gpt-4o-mini"),
            "messages": [
                {"role": "system", "content": PROMPT},
                {
                    "role": "user",
                    "content": f"Contexto knowledge:\n{ctx}\n\nPregunta del gerente:\n{question}",
                },
            ],
            "temperature": 0.3,
        }
        req = urllib.request.Request(
            "https://api.openai.com/v1/chat/completions",
            data=json.dumps(body).encode(),
            headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=60) as r:
            data = json.loads(r.read().decode())
        return data["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"(LLM no disponible: {e}; uso plantilla local)", file=sys.stderr)
        return None


def main() -> None:
    ap = argparse.ArgumentParser(description="Agente Pro-Automation (demo)")
    ap.add_argument("--pregunta", "-q", default="")
    args = ap.parse_args()
    docs = load_knowledge()
    print("Agente Pro-Automation — demo gerente de producción")
    print("Escribe 'salir' para terminar.\n")

    def one(q: str) -> None:
        hits = retrieve(q, docs)
        ans = llm_answer(q, hits) or template_answer(q, hits)
        print(ans)
        print("\n" + "─" * 60 + "\n")

    if args.pregunta.strip():
        one(args.pregunta.strip())
        return
    while True:
        try:
            q = input("Gerente> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not q or q.lower() in {"salir", "exit", "quit"}:
            break
        one(q)


if __name__ == "__main__":
    main()
