#!/usr/bin/env bash
# Todos os testes rápidos: Python (com o limiar de cobertura) e GDScript (GdUnit4, headless).
#   scripts/test.sh            os dois
#   scripts/test.sh python     só Python      (argumentos extras vão para o pytest)
#   scripts/test.sh godot      só GDScript
#   scripts/test.sh coverage   cobertura do GDScript (tools/gd_coverage.py), limiar de 80%
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/godot.sh
what=${1:-all}
[[ $# -gt 0 ]] && shift

if [[ $what == all || $what == python ]]; then
    uv run pytest "$@"
fi
if [[ $what == coverage ]]; then
    exec uv run python -m tools.gd_coverage --fail-under 80
fi
if [[ $what == all || $what == godot ]]; then
    GODOT=$(find_godot)
    cd godot
    # Classes novas (class_name) só entram no cache global depois de uma importação.
    "$GODOT" --headless --path . --import >/dev/null 2>&1
    # -a: pasta de testes; --ignoreHeadlessMode: os testes de lógica pura não precisam de janela.
    "$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
        res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode -c
fi
