#!/usr/bin/env bash
# Prepara o ambiente de desenvolvimento do zero (pode rodar de novo quando quiser).
#   - backend Python com uv (Python fixado em .python-version, dependências no uv.lock)
#   - GdUnit4 na versão fixada (scripts/versions.env), conferido por sha256
#   - importação inicial do projeto Godot (gera godot/.godot/, que não é versionado)
#   - hooks do pre-commit
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/versions.env
source scripts/godot.sh

need() { command -v "$1" >/dev/null || { echo "falta '$1': $2" >&2; exit 1; }; }
need uv "curl -LsSf https://astral.sh/uv/install.sh | sh"
need ffmpeg "instale o ffmpeg (com libvorbis)"
need git "instale o git"
GODOT=$(find_godot)

echo "== Python (uv sync)"
uv sync --frozen --extra dev

echo "== GdUnit4 ${GDUNIT4_VERSION}"
addon=godot/addons/gdUnit4
if ! grep -qs "version=\"${GDUNIT4_VERSION}\"" "$addon/plugin.cfg"; then
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/gdunit.tar.gz" \
        "https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v${GDUNIT4_VERSION}.tar.gz"
    echo "${GDUNIT4_SHA256}  $tmp/gdunit.tar.gz" | sha256sum -c --quiet
    tar xzf "$tmp/gdunit.tar.gz" -C "$tmp"
    rm -rf "$addon"
    mkdir -p godot/addons
    mv "$tmp/gdUnit4-${GDUNIT4_VERSION}/addons/gdUnit4" "$addon"
fi

echo "== Godot: importação inicial ($GODOT)"
"$GODOT" --headless --path godot --import >/dev/null 2>&1 || true

if [[ -d .git ]]; then
    echo "== pre-commit"
    uv run pre-commit install
fi
echo "Pronto. Testes: scripts/test.sh"
