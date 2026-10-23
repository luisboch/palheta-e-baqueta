#!/usr/bin/env bash
# Monta o .deb (ADR 0018): jogo exportado + código do backend + uv, em /opt/palheta-e-baqueta.
#   scripts/package_deb.sh [versão]      versão padrão: a do pyproject.toml
# Precisa do Godot e dos templates de exportação da versão de scripts/versions.env, e do dpkg-deb.
# Saída: build/palheta-e-baqueta_<versão>_amd64.deb
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/versions.env
source scripts/godot.sh
GODOT=$(find_godot)
VERSION=${1:-$(sed -n 's/^version = "\(.*\)"/\1/p' pyproject.toml)}
NAME=palheta-e-baqueta
ROOT=build/deb
APP=$ROOT/opt/$NAME
rm -rf "$ROOT"
mkdir -p "$APP/backend" "$ROOT/usr/bin" "$ROOT/DEBIAN" \
    "$ROOT/usr/share/applications" "$ROOT/usr/share/icons/hicolor/256x256/apps"

echo "== Jogo (exportação Linux)"
"$GODOT" --headless --path godot --import >/dev/null 2>&1 || true
"$GODOT" --headless --path godot --export-release Linux "$PWD/$APP/$NAME.x86_64"
test -x "$APP/$NAME.x86_64"

echo "== Backend (código; o .venv é criado na máquina do jogador)"
cp -r pbq pyproject.toml uv.lock .python-version README.md config.example.toml "$APP/backend/"
find "$APP/backend" -name __pycache__ -prune -exec rm -rf {} +
echo "$VERSION" >"$APP/VERSION"

echo "== uv $UV_VERSION"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/uv.tar.gz" \
    "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz"
echo "${UV_SHA256}  $tmp/uv.tar.gz" | sha256sum -c --quiet
tar xzf "$tmp/uv.tar.gz" -C "$tmp"
install -m 755 "$tmp/uv-x86_64-unknown-linux-gnu/uv" "$APP/uv"

echo "== Lançador, atalho e ícone"
install -m 755 scripts/deb/$NAME "$ROOT/usr/bin/$NAME"
cp scripts/steamdeck/icon.png "$ROOT/usr/share/icons/hicolor/256x256/apps/$NAME.png"
cat >"$ROOT/usr/share/applications/$NAME.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Palheta & Baqueta
Comment=Cordas, baixo e bateria das suas músicas
Exec=$NAME
Icon=$NAME
Terminal=false
Categories=Game;AudioVideo;
DESKTOP

cat >"$ROOT/DEBIAN/control" <<CONTROL
Package: $NAME
Version: $VERSION
Architecture: amd64
Maintainer: Luis Boch <luis.c.boch@gmail.com>
Depends: ffmpeg, coreutils (>= 8.28)
Recommends: zenity
Installed-Size: $(du -sk "$ROOT" | cut -f1)
Section: games
Priority: optional
Homepage: https://github.com/luisboch/palheta-e-baqueta
Description: Jogo de ritmo com as suas músicas: Cordas, baixo e bateria
 Transforma MP3s em músicas jogáveis (stems separados por IA, charts em 4
 dificuldades) para até 2 jogadores. Na primeira execução instala o backend
 de IA (alguns GB) em ~/.local/share/palheta-e-baqueta.
CONTROL

mkdir -p build
dpkg-deb --root-owner-group --build "$ROOT" "build/${NAME}_${VERSION}_amd64.deb"
echo "Pronto: build/${NAME}_${VERSION}_amd64.deb"
