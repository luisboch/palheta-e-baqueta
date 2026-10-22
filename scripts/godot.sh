#!/usr/bin/env bash
# Acha o binário do Godot na versão fixada: $GODOT_BIN, ~/Applications (Steam Deck) ou o PATH.
set -euo pipefail
source "$(dirname "$0")/versions.env"

find_godot() {
    local candidates=(
        "${GODOT_BIN:-}"
        "$HOME/Applications/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
        "$(command -v godot 2>/dev/null || true)"
        "$(command -v godot4 2>/dev/null || true)"
    )
    for c in "${candidates[@]}"; do
        if [[ -n "$c" && -x "$c" ]] && "$c" --version 2>/dev/null | grep -q "^${GODOT_VERSION}\."; then
            echo "$c"
            return 0
        fi
    done
    echo "Godot ${GODOT_VERSION} não encontrado: defina GODOT_BIN=/caminho/do/godot" >&2
    return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    find_godot
fi
