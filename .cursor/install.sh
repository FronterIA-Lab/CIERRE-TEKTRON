#!/usr/bin/env bash
#
# Idempotent environment bootstrap for CIERRE-TEKTRON.
#
# Creates a Python virtualenv under .venv and installs the dependencies that
# the tektron_*.py maintenance / diagnostic scripts import (numpy, faiss-cpu,
# sentence-transformers, rank-bm25, requests). CPU-only PyTorch is installed
# from the official PyTorch CPU wheel index so the large CUDA build is skipped.
#
# Safe to run repeatedly: existing venv and already-installed packages are
# reused, and pip only downloads what is missing.
set -euo pipefail

# Resolve repo root (this script lives in <root>/.cursor/).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# The default image may ship a Python without venv/ensurepip support.
if ! python3 -c 'import ensurepip' >/dev/null 2>&1; then
  echo "[install] python venv support missing; installing python3-venv"
  sudo apt-get update -qq
  sudo apt-get install -y python3-venv
fi

# Create the virtualenv if it does not already exist.
if [ ! -x .venv/bin/python ]; then
  echo "[install] creating virtualenv at .venv"
  python3 -m venv .venv
fi

.venv/bin/python -m pip install --upgrade pip

# CPU-only PyTorch (no CUDA) — must be installed before the requirements file
# so pip resolves torch against the CPU wheel index.
echo "[install] installing CPU-only torch"
.venv/bin/python -m pip install torch --index-url https://download.pytorch.org/whl/cpu

echo "[install] installing project requirements"
.venv/bin/python -m pip install -r requirements.txt

echo "[install] done. Activate with: source .venv/bin/activate"
