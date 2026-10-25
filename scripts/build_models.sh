#!/usr/bin/env bash
# Refaz os modelos 3D (art/build_models.py) em godot/game/models/, com o Blender da versão fixada.
#   scripts/build_models.sh            todos
#   scripts/build_models.sh stage      só os nomeados
# Blender: $BLENDER_BIN, o do PATH ou o flatpak (org.blender.Blender).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/versions.env

if [[ -n "${BLENDER_BIN:-}" ]]; then
    blender=("$BLENDER_BIN")
elif command -v blender >/dev/null; then
    blender=(blender)
elif flatpak info org.blender.Blender >/dev/null 2>&1; then
    blender=(flatpak run org.blender.Blender)
else
    echo "Blender ${BLENDER_VERSION} não encontrado: defina BLENDER_BIN=/caminho/do/blender" >&2
    exit 1
fi
version=$("${blender[@]}" --version 2>/dev/null | head -1)
if [[ $version != "Blender ${BLENDER_VERSION}"* ]]; then
    echo "Esperado Blender ${BLENDER_VERSION}, achado: ${version}" >&2
    exit 1
fi
"${blender[@]}" -b --factory-startup --python "$PWD/art/build_models.py" -- "$PWD/godot/game/models" "$@"
