#!/usr/bin/env bash
# Full build + test for Windows via MSYS2 MINGW64 shell.
# Run from the repo root inside an MSYS2 MINGW64 terminal:
#   bash scripts/build_windows.sh
#
# Required MSYS2 packages (install once with pacman):
#   pacman -S --noconfirm \
#     mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja \
#     mingw-w64-x86_64-gmp mingw-w64-x86_64-libpng mingw-w64-x86_64-libjpeg-turbo \
#     mingw-w64-x86_64-python mingw-w64-x86_64-python-numpy
#
# Note: OpenMesh is not available in MSYS2; build proceeds without it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PRESET="${1:-ci}"
VENV="${GEODE_VENV:-.venv}"

# --- Python venv ---
if [[ ! -f "$VENV/bin/python" ]]; then
  echo "Creating venv at $VENV"
  python -m venv "$VENV"
fi
source "$VENV/bin/activate"
pip install --upgrade pip --quiet
pip install --quiet pytest pytest-forked scipy

# --- Configure + Build ---
echo "Configuring preset: $PRESET"
cmake -G Ninja --preset "$PRESET"
echo "Building..."
cmake --build --preset "$PRESET" --clean-first

# --- Test ---
echo "Running tests..."
cd "build/$PRESET"
python -m pytest --forked --tb=short

echo "Done."
