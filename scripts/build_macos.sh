#!/usr/bin/env bash
# Full build + test for macOS (Apple Silicon and Intel).
# Run from the repo root: bash scripts/build_macos.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PRESET="${1:-dev}"
VENV="${GEODE_VENV:-.venv}"

# --- Dependencies ---
BREW_PKGS=(cmake gmp open-mesh libpng libjpeg)
MISSING=()
for pkg in "${BREW_PKGS[@]}"; do
  brew list "$pkg" &>/dev/null || MISSING+=("$pkg")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Installing missing packages: ${MISSING[*]}"
  brew install "${MISSING[@]}"
fi

# --- Python venv ---
if [[ ! -f "$VENV/bin/python3" ]]; then
  echo "Creating venv at $VENV"
  python3 -m venv "$VENV"
fi
source "$VENV/bin/activate"
pip install --upgrade pip --quiet
pip install --quiet numpy pytest pytest-forked scipy

# --- Configure + Build ---
echo "Configuring preset: $PRESET"
cmake --preset "$PRESET"
echo "Building..."
cmake --build --preset "$PRESET" --clean-first

# --- Test ---
echo "Running tests..."
cd "build/$PRESET"
python3 -m pytest --forked --tb=short

echo "Done."
