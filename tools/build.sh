#!/usr/bin/env bash
# Exporta los builds para playtesters: ./tools/build.sh [--debug]
# Release: sin escenarios de debug ni tests, partidas cifradas. Debug: con escenarios y partidas en texto (plain_saves).
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo dev)"
GODOT_VERSION="$("$GODOT" --version | cut -d. -f1-3)"
TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VERSION}"
MODE="release"
[[ "${1:-}" == "--debug" ]] && MODE="debug"

fail() { echo "build: $*" >&2; exit 1; }

[[ -d "$TEMPLATES" ]] || fail "faltan las plantillas de export de Godot ${GODOT_VERSION} en ${TEMPLATES} (Editor › Gestionar plantillas de exportación)."
if [[ "$MODE" == "release" ]]; then
	for lib in addons/limboai/bin/liblimboai.linux.template_release.x86_64.so addons/limboai/bin/liblimboai.windows.template_release.x86_64.dll; do
		[[ -f "$lib" ]] || fail "falta ${lib}: compilar LimboAI con target=template_release (ver addons/limboai)."
	done
fi

export_one() {
	local preset="$1" output="$2"
	mkdir -p "$(dirname "$output")"
	echo "build: ${preset} → ${output} (${VERSION})"
	"$GODOT" --headless --path . "--export-${MODE}" "$preset" "$output"
}

if [[ "$MODE" == "release" ]]; then
	export_one "Linux" "builds/linux/project-epiphany.x86_64"
	export_one "Windows" "builds/windows/project-epiphany.exe"
else
	export_one "Linux (debug)" "builds/linux-debug/project-epiphany.x86_64"
	export_one "Windows (debug)" "builds/windows-debug/project-epiphany.exe"
fi
echo "$VERSION" > "builds/VERSION"
echo "build: listo (${VERSION})"
