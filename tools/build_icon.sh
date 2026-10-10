#!/usr/bin/env bash
# Ícono del juego desde el ojo del jefe: icon.png (512, el de project.godot y los exports) e icon.ico (Windows).
# Necesita blender e ImageMagick (magick). ./tools/build_icon.sh
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=assets/branding
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

blender -b -P tools/blender/render_icon.py -- "$TMP/render.png" >/dev/null
magick -size 512x512 xc:none -fill "#151920" -stroke "#d9a441" -strokewidth 10 \
	-draw "roundrectangle 8,8 503,503 80,80" "$TMP/tile.png"
magick -size 512x512 xc:none -fill white -draw "roundrectangle 13,13 498,498 75,75" "$TMP/mask.png"
magick "$TMP/render.png" -background none -resize 500x500 -gravity center -extent 512x512 "$TMP/eye.png"
magick "$TMP/eye.png" "$TMP/mask.png" -compose DstIn -composite "$TMP/eye_masked.png"
magick "$TMP/tile.png" "$TMP/eye_masked.png" -compose Over -composite \
	\( -size 512x512 xc:none -fill none -stroke "#d9a441" -strokewidth 10 -draw "roundrectangle 8,8 503,503 80,80" \) \
	-compose Over -composite "$OUT/icon.png"
magick "$OUT/icon.png" -define icon:auto-resize=256,128,64,48,32,16 "$OUT/icon.ico"
echo "build_icon: $OUT/icon.png $OUT/icon.ico"
