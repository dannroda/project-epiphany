#!/usr/bin/env bash
# Graba el teaser (10.31) toma por toma con Movie Maker (60 fps fijos, 1920x1080, en el monitor secundario sin robar el
# foco) y arma un corte en bruto. Cada toma queda en debug/tmp/teaser/NN_<toma>.mp4, con el sonido del juego.
#   tools/teaser/record.sh            todas las tomas, en el orden de Shots
#   tools/teaser/record.sh Hub Mano   solo esas (y rehace el corte con lo que haya)
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=${GODOT:-/opt/godot/versions/4.8-beta1/godot}
OUT=debug/tmp/teaser
mkdir -p "$OUT"
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

all=($(grep -oP '^\[node name="\K[^"]+(?=" type="Node3D" parent="Shots"\])' tools/teaser/teaser.tscn))
shots=("$@")
[[ ${#shots[@]} -eq 0 ]] && shots=("${all[@]}")
for shot in "${shots[@]}"; do
	echo "== $shot"
	rm -f "$OUT/$shot.txt"
	bwrap --dev-bind / / --tmpfs /dev/input --die-with-parent "$GODOT" --path . --display-driver x11 --screen 1 \
		--resolution 1920x1080 --write-movie "$OUT/raw_$shot.avi" --fixed-fps 60 \
		-- --shot="$shot" --teaser-out="$PWD/$OUT" > "$OUT/$shot.log" 2>&1 || true
	[[ -f "$OUT/$shot.txt" ]] || { echo "   no terminó: ver $OUT/$shot.log" >&2; continue; }
	read -r start length < "$OUT/$shot.txt"
	n=$(printf '%02d' $(( $(printf '%s\n' "${all[@]}" | grep -nx "$shot" | cut -d: -f1) )))
	ffmpeg -loglevel error -y -ss "$start" -i "$OUT/raw_$shot.avi" -t "$length" -c:v libx264 -crf 14 -preset slow \
		-pix_fmt yuv420p -r 60 -c:a aac -b:a 192k "$OUT/${n}_$shot.mp4"
	rm -f "$OUT/raw_$shot.avi"
done

ls "$OUT"/[0-9][0-9]_*.mp4 | sed "s|^$OUT/|file '|; s|$|'|" > "$OUT/list.txt"
ffmpeg -loglevel error -y -f concat -safe 0 -i "$OUT/list.txt" -c copy "$OUT/teaser_bruto.mp4"
echo "Corte en bruto: $OUT/teaser_bruto.mp4"
