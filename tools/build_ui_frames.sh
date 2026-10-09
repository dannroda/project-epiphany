#!/usr/bin/env bash
# Tiñe los marcos de Kenney Fantasy UI Borders con la paleta de la UI y los deja en assets/ui/frames/.
# Necesita ImageMagick 7 (magick). Uso: tools/build_ui_frames.sh
set -euo pipefail
cd "$(dirname "$0")/.."
K=assets/kenney_fantasy-ui-borders/PNG
OUT=assets/ui/frames
mkdir -p "$OUT"

# nombre carpeta índice relleno borde
frame() {
	magick \( "$K/$2/Panel/panel-0$3.png" -fill "$4" -colorize 100 \) \
		\( "$K/$2/Border/panel-border-0$3.png" -fill "$5" -colorize 100 \) \
		-compose over -composite "$OUT/$1.png"
}

# nombre índice borde (solo el borde, sin relleno)
outline() {
	magick "$K/Default/Border/panel-border-0$2.png" -fill "$3" -colorize 100 "$OUT/$1.png"
}

frame menu_frame Double 14 '#151920' '#d9a441'
frame stone Double 02 '#2a2c33' '#8f8576'
frame item_get Double 06 '#151920' '#d9a441'
frame card Double 05 '#0f1216' '#3a4250'
frame hud_slot Default 01 '#0f1216' '#6b5a3a'
frame pill Default 13 '#0f1216' '#6b5a3a'
frame chip Default 15 '#1c2029' '#6b5a3a'
frame slot Default 09 '#151920' '#5a5446'
frame slot_focus Default 09 '#1c2029' '#d9a441'
frame button Default 09 '#151920' '#6b5a3a'
frame button_focus Default 09 '#1c2029' '#d9a441'
frame button_disabled Default 09 '#101318' '#3a4250'
outline slot_empty 09 '#5a5446'
outline slot_empty_focus 09 '#d9a441'
magick "$K/Double/Divider Fade/divider-fade-003.png" -fill '#d9a441' -colorize 100 "$OUT/divider.png"
magick "$K/Double/Divider Fade/divider-fade-003.png" -fill '#6b5a3a' -colorize 100 "$OUT/divider_dim.png"
magick "$OUT/divider.png" -flop "$OUT/divider_flipped.png"
# Slider: la doble línea es el riel (bronce, dorado lo lleno); la perilla, un rombo como los radios.
magick "$K/Double/Divider/divider-002.png" -fill '#6b5a3a' -colorize 100 "$OUT/slider_track.png"
magick "$K/Double/Divider/divider-002.png" -fill '#d9a441' -colorize 100 "$OUT/slider_fill.png"
magick -size 22x22 xc:none -fill '#d9a441' -stroke '#0b0d10' -strokewidth 2 -draw 'polygon 11,1 21,11 11,21 1,11' "$OUT/slider_grabber.png"
magick -size 22x22 xc:none -fill '#ffd27a' -stroke '#0b0d10' -strokewidth 2 -draw 'polygon 11,1 21,11 11,21 1,11' "$OUT/slider_grabber_focus.png"

# Casillas, radios y flecha del desplegable, en pixel art como los marcos.
magick -size 16x16 xc:none -fill '#d9a441' -draw 'rectangle 3,3 12,12' "$OUT/check_on.png"
magick -size 16x16 xc:none "$OUT/check_off.png"
magick -size 16x16 xc:none -fill '#d9a441' -draw 'polygon 8,1 15,8 8,15 1,8' "$OUT/radio_on.png"
magick -size 16x16 xc:none -fill none -stroke '#6b5a3a' -strokewidth 2 -draw 'polygon 8,2 14,8 8,14 2,8' "$OUT/radio_off.png"
magick -size 16x16 xc:none -fill '#d9a441' -draw 'polygon 2,5 14,5 8,11' "$OUT/arrow_down.png"
# ▶ de MenuItem: blanco, el tema lo tiñe (invisible sin foco, dorado con foco).
magick -size 12x14 xc:none -fill white -draw 'polygon 1,1 11,7 1,13' "$OUT/menu_arrow.png"

cp assets/kenney_fantasy-ui-borders/License.txt "$OUT/License.txt"
ls "$OUT"
