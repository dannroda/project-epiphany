#!/usr/bin/env bash
# Graba las tomas del teaser (10.31) desde cada uno de sus ángulos con Movie Maker (60 fps fijos, 1920x1080, en el
# monitor secundario sin robar el foco). Cada una queda en debug/tmp/teaser/NN_<toma>-<ángulo>.mp4 con el sonido del
# juego (sin la música, que pone edit.sh).
#   tools/teaser/record.sh                     todas las tomas y ángulos, con los pasos guionados
#   tools/teaser/record.sh Hub Mano            solo esas tomas (todos sus ángulos)
#   tools/teaser/record.sh Hub-Orbita          solo ese ángulo
#   tools/teaser/record.sh --tomas [tomas…]    las que Daniel jugó con play.sh repiten sus inputs (takes/<toma>.json)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/godot/versions/4.8-beta1/godot}
OUT=debug/tmp/teaser
mkdir -p "$OUT"
takes=0
[[ ${1:-} == --tomas ]] && { takes=1; shift; }
[[ -e override.cfg ]] && { echo "Ya hay un override.cfg: no lo piso" >&2; exit 1; }
trap 'rm -f override.cfg' EXIT
cat > override.cfg <<'CFG'
[display]
window/size/no_focus=true
window/size/viewport_width=1920
window/size/viewport_height=1080
[editor]
movie_writer/mjpeg_quality=0.95
[autoload]
TeaserDirector="*res://tools/teaser/teaser.tscn"
CFG

mapfile -t combos < <(bwrap --dev-bind / / --tmpfs /dev/input "$GODOT" --headless --path . -- --teaser-list 2>/dev/null | sed -n 's/^TEASER //p')
shots=($(printf '%s\n' "${combos[@]}" | cut -d' ' -f1 | uniq))
for combo in "${combos[@]}"; do
	read -r shot angle <<< "$combo"
	if [[ $# -gt 0 ]]; then
		wanted=0
		for arg in "$@"; do [[ $arg == "$shot" || $arg == "$shot-$angle" ]] && wanted=1; done
		[[ $wanted == 1 ]] || continue
	fi
	mode=script
	[[ $takes == 1 && -f tools/teaser/takes/$shot.json ]] && mode=replay
	name="$shot-$angle"
	n=$(printf '%02d' "$(printf '%s\n' "${shots[@]}" | grep -nx "$shot" | cut -d: -f1)")
	echo "== $name ($mode)"
	rm -f "$OUT/$name.txt"
	bwrap --dev-bind / / --tmpfs /dev/input --die-with-parent "$GODOT" --path . --display-driver x11 --screen 1 \
		--resolution 1920x1080 --write-movie "$OUT/raw_$name.avi" --fixed-fps 60 \
		-- --shot="$shot" --angle="$angle" --teaser-mode="$mode" --teaser-out="$PWD/$OUT" > "$OUT/$name.log" 2>&1 || true
	[[ -f "$OUT/$name.txt" ]] || { echo "   no terminó: ver $OUT/$name.log" >&2; continue; }
	read -r start length < "$OUT/$name.txt"
	suffix=""
	[[ $mode == replay ]] && suffix="-jugada"
	ffmpeg -loglevel error -y -ss "$start" -i "$OUT/raw_$name.avi" -t "$length" -c:v libx264 -crf 14 -preset slow \
		-pix_fmt yuv420p -r 60 -c:a aac -b:a 192k "$OUT/${n}_$name$suffix.mp4"
	rm -f "$OUT/raw_$name.avi"
done
echo "Tomas en $OUT"
