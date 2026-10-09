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
cp assets/kenney_fantasy-ui-borders/License.txt "$OUT/License.txt"
ls "$OUT"
