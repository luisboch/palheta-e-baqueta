#!/usr/bin/env bash
# Prepara o Palheta & Baqueta para o modo jogo: confere o que o jogo precisa e cria o atalho
# (~/.local/share/applications/palheta-e-baqueta.desktop), que aparece com caixa de marcar no
# diálogo "Adicionar jogo não-Steam" do Steam. Pode rodar de novo sem problema.
set -euo pipefail

export PATH="$HOME/.local/bin:/home/linuxbrew/.linuxbrew/bin:$PATH"
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
cd "$ROOT"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; exit 1; }

echo "O que o jogo precisa"
GODOT="$(scripts/godot.sh)" && ok "Godot: $GODOT" || fail "Godot não encontrado (veja scripts/versions.env)"
[ -x .venv/bin/pbq ] && ok "backend instalado (.venv)" || fail "backend não instalado: rode scripts/setup.sh"
.venv/bin/python -c "import demucs" 2>/dev/null && ok "modelos de IA (extra ai)" \
    || warn "sem os modelos de IA: as músicas não serão processadas (uv sync --extra dev --extra ai)"
ffmpeg -hide_banner -encoders 2>/dev/null | grep -q libvorbis && ok "ffmpeg com libvorbis ($(command -v ffmpeg))" \
    || warn "ffmpeg sem libvorbis: a etapa package não consegue gravar os OGGs"

echo "Ícone e atalho"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
APP_DIR="$HOME/.local/share/applications"
mkdir -p "$ICON_DIR" "$APP_DIR"
cp scripts/steamdeck/icon.png "$ICON_DIR/palheta-e-baqueta.png"
cat > "$APP_DIR/palheta-e-baqueta.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Palheta & Baqueta
Comment=Cordas, baixo e bateria das suas músicas
Exec=$ROOT/scripts/steamdeck/palheta.sh
Path=$ROOT
Icon=palheta-e-baqueta
Terminal=false
Categories=Game;AudioVideo;
DESKTOP
chmod +x scripts/steamdeck/palheta.sh
ok "$APP_DIR/palheta-e-baqueta.desktop"

cat <<'NEXT'

Próximo passo (modo desktop): Steam → Jogos → "Adicionar jogo não-Steam à biblioteca"
→ marque "Palheta & Baqueta" → "Adicionar programas selecionados". No modo jogo, o controle
já vem no layout de gamepad: A B Y X LB tocam, Start pausa.
NEXT
