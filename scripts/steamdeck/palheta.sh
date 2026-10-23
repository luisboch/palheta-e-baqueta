#!/usr/bin/env bash
# Lançador do Palheta & Baqueta para o modo jogo do Steam Deck.
# O atalho é criado por scripts/steamdeck/install.sh; depois, no modo desktop: Steam → Jogos →
# "Adicionar jogo não-Steam" → marque "Palheta & Baqueta".
#
# No modo jogo o PATH não inclui o Homebrew nem ~/.local/bin: sem isso o worker (iniciado pelo
# jogo) usaria o ffmpeg do sistema. Não há terminal: a saída vai para data/game.log.
set -uo pipefail

export PATH="$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
cd "$ROOT" || exit 1

mkdir -p data
[ -f data/game.log ] && mv -f data/game.log data/game.log.1  # guarda o log da execução anterior
exec >data/game.log 2>&1
echo "Palheta & Baqueta: $(date -Is)"

GODOT="$(scripts/godot.sh)" || exit 1
exec "$GODOT" --path "$ROOT/godot" --fullscreen "$@"
