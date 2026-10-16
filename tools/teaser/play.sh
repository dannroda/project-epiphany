#!/usr/bin/env bash
# Daniel juega una toma del teaser (10.31): se arma igual que la guionada (escenario, Inicio, semilla, fase del jefe)
# con la cámara del juego, a 60 fps fijos; cuando arranca la grabación el player se puede mover y al terminar quedan
# sus inputs en tools/teaser/takes/<toma>.json. Después: tools/teaser/record.sh --tomas <toma> la graba desde todos
# los ángulos.
#   tools/teaser/play.sh Hub
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/godot/versions/4.8-beta1/godot}
[[ $# -eq 1 ]] || { echo "Uso: $0 <toma>" >&2; exit 1; }
[[ -e override.cfg ]] && { echo "Ya hay un override.cfg: no lo piso" >&2; exit 1; }
trap 'rm -f override.cfg' EXIT
cat > override.cfg <<'CFG'
[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
[autoload]
TeaserDirector="*res://tools/teaser/teaser.tscn"
CFG
"$GODOT" --path . --fixed-fps 60 -- --shot="$1" --teaser-mode=play 2>&1 | grep --line-buffered "TEASER"
