#!/usr/bin/env bash
# Full build + test for Ubuntu/Debian x86_64 and aarch64.
# Run from the repo root: bash scripts/build_ubuntu.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PRESET="${1:-dev}"
VENV="${GEODE_VENV:-.venv}"

# --- Dependencies ---
PKGS=(cmake libgmp-dev libopenmesh-dev libpng-dev libjpeg-dev python3-pip python3-venv)
MISSING=()
for pkg in "${PKGS[@]}"; do
  dpkg -s "$pkg" &>/dev/null || MISSING+=("$pkg")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Installing missing packages: ${MISSING[*]}"
  sudo apt-get update -qq
  sudo apt-get install -y -qq "${MISSING[@]}"
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
