#!/usr/bin/env python3
"""LEGACY — usar tektron_reconcile_index_l1.py

Este archivo queda como alias fino para no romper comandos viejos.
"""
from __future__ import annotations

import runpy
import sys
from pathlib import Path

print(
    "AVISO: tektron_fix_meta_l1.py está deprecado.\n"
    "Usa: tektron_reconcile_index_l1.py --dry-run | --apply\n",
    file=sys.stderr,
)

target = Path(__file__).resolve().parent / "tektron_reconcile_index_l1.py"
# map old flags
argv = ["tektron_reconcile_index_l1.py"]
if "--apply" in sys.argv:
    argv.append("--apply")
else:
    argv.append("--dry-run")
sys.argv = argv
runpy.run_path(str(target), run_name="__main__")
