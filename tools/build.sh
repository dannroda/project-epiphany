#!/usr/bin/env bash
# Exporta los builds para playtesters: ./tools/build.sh [--debug]
# Release: sin escenarios de debug ni tests, partidas cifradas. Debug: con escenarios y partidas en texto (plain_saves).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
BUILD="$(git rev-list --count HEAD)"
COMMIT="$(git rev-parse --short HEAD)"
DIRTY=false
[[ -n "$(git status --porcelain)" ]] && DIRTY=true
GODOT_VERSION="$("$GODOT" --version | cut -d. -f1-3)"
TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}"
MODE="release"
[[ "${1:-}" == "--debug" ]] && MODE="debug"

fail() { echo "build: $*" >&2; exit 1; }

[[ -d "$TEMPLATES" ]] || fail "faltan las plantillas de export de Godot ${GODOT_VERSION} en ${TEMPLATES} (Editor › Gestionar plantillas de exportación)."
if [[ "$MODE" == "release" ]]; then
	for lib in addons/limboai/bin/liblimboai.linux.template_release.x86_64.so addons/limboai/bin/liblimboai.windows.template_release.x86_64.dll addons/limboai/bin/liblimboai.macos.template_release.framework; do
		[[ -e "$lib" ]] || fail "falta ${lib}: copiarlo del gdextension oficial de LimboAI 1.8.1 (el editor usa el build parchado)."
	done
fi

printf '[build]\nnumber=%s\ncommit="%s"\ndirty=%s\n' "$BUILD" "$COMMIT" "$DIRTY" > build_info.cfg
trap 'rm -f build_info.cfg' EXIT

export_one() {
	local preset="$1" output="$2"
	mkdir -p "$(dirname "$output")"
	echo "build: ${preset} → ${output} (${VERSION}.${BUILD})"
	"$GODOT" --headless --path . "--export-${MODE}" "$preset" "$output"
}

if [[ "$MODE" == "release" ]]; then
	export_one "Linux" "builds/linux/project-epiphany.x86_64"
	export_one "Windows" "builds/windows/project-epiphany.exe"
	export_one "macOS" "builds/macos/project-epiphany.zip"
else
	export_one "Linux (debug)" "builds/linux-debug/project-epiphany.x86_64"
	export_one "Windows (debug)" "builds/windows-debug/project-epiphany.exe"
fi
echo "${VERSION}.${BUILD} (${COMMIT}$([[ $DIRTY == true ]] && echo '*'))" > "builds/VERSION"
echo "build: listo ($(cat builds/VERSION))"
