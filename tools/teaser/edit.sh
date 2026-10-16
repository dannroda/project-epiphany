#!/usr/bin/env bash
# Arma el teaser (10.31) con las tomas que grabó record.sh: cortes de CUTS, música del juego por tramos (calma en el
# overworld, capas de mazmorra en el templo, todas en el jefe), el sonido de las tomas abajo y el cierre con el título.
#   tools/teaser/edit.sh   →   debug/tmp/teaser/teaser.mp4
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=debug/tmp/teaser
MUSIC=assets/audio/music
# toma  desde  duración  tramo de música (0 overworld, 1 templo, 2 jefe)
CUTS="
01_Vista      0.0 3.5 0
02_Laguna     0.0 3.0 0
03_Camino     0.5 3.5 0
04_Templo     0.0 3.5 0
05_Hub        0.8 2.5 1
06_Pluma      0.3 2.8 1
07_Gancho     0.6 2.4 1
08_Combinada  0.6 2.4 1
09_Mano       2.0 3.0 1
10_JefeIntro  1.0 4.5 2
11_JefePelea  0.5 3.5 2
12_Ojo        0.0 3.2 2
"
END=3.0
TITLE="PROJECT EPIPHANY"

inputs=() filters="" n=0 total=0 bounds=(0 0 0)
while read -r shot from length part; do
	[[ -z "$shot" ]] && continue
	inputs+=(-ss "$from" -t "$length" -i "$OUT/$shot.mp4")
	filters+="[$n:v]setpts=PTS-STARTPTS,fps=60,format=yuv420p[v$n];[$n:a]asetpts=PTS-STARTPTS,aresample=48000,apad,atrim=0:$length[a$n];"
	total=$(awk "BEGIN{print $total + $length}")
	bounds[$part]=$total
	n=$((n + 1))
done <<< "$CUTS"
concat=""
for i in $(seq 0 $((n - 1))); do concat+="[v$i][a$i]"; done
filters+="${concat}concat=n=$n:v=1:a=1[shots][sfx];"
filters+="color=black:s=1920x1080:r=60:d=$END,format=yuv420p,drawtext=fontfile=assets/fonts/Cinzel.ttf:text='$TITLE':fontcolor=0xE8C878:fontsize=96:x=(w-tw)/2:y=(h-th)/2:alpha='min(1,max(0,(t-0.4)/0.8))'[card];"
filters+="[shots][card]concat=n=2:v=1:a=0,fade=t=in:st=0:d=1.0[video];"
length=$(awk "BEGIN{print $total + $END}")
a=${bounds[0]} b=${bounds[1]}
layer() { echo "[$1:a]aloop=loop=-1:size=2e9,atrim=0:$length,volume=$2,volume='$3':eval=frame[$4];"; }
m=$n
inputs+=(-i "$MUSIC/calm.wav" -i "$MUSIC/dark.wav" -i "$MUSIC/pulse.wav" -i "$MUSIC/heartbeat.wav")
filters+=$(layer $m 0.9 "if(lt(t,$a-1),1,max(0,($a-t)))" calm)
filters+=$(layer $((m + 1)) 0.9 "if(lt(t,$a-1),0,min(1,(t-$a+1)))" dark)
filters+=$(layer $((m + 2)) 0.8 "if(lt(t,$a),0,min(1,(t-$a)/1.5))" pulse)
filters+=$(layer $((m + 3)) 0.9 "if(lt(t,$b),0,min(1,(t-$b)/0.5))" beat)
filters+="[sfx]apad,atrim=0:$length,volume=0.55[game];"
filters+="[calm][dark][pulse][beat][game]amix=inputs=5:normalize=0,afade=t=in:st=0:d=1.0,afade=t=out:st=$(awk "BEGIN{print $length - 1.5}"):d=1.5[audio]"
ffmpeg -loglevel error -y "${inputs[@]}" -filter_complex "$filters" -map "[video]" -map "[audio]" \
	-c:v libx264 -crf 16 -preset slow -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart "$OUT/teaser.mp4"
echo "Teaser: $OUT/teaser.mp4 ($length s)"
