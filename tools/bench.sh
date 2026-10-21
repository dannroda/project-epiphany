#!/usr/bin/env bash
# Benchmark automático (15.14): corre src/debug/benchmark/benchmark.tscn sin input y guarda el JSON en debug/tmp/bench/.
# En Android usa el preset "Android (benchmark)" (feature benchmark), que reemplaza al juego instalado.
#   tools/bench.sh desktop              en ventana, en la pantalla 1 sin robar el foco
#   tools/bench.sh android <serial>     instala el APK de debug (lo exporta con --build o si falta) y lo corre en el teléfono
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-/opt/godot/versions/4.8-beta1/godot}
PACKAGE=com.example.projectepiphany
# debug/tmp es compartido entre worktrees: un APK por worktree para que una corrida no instale el build de otra.
APK=debug/tmp/android/epiphany_bench_$(basename "$PWD").apk
OUT=debug/tmp/bench
PIPELINE_CACHE_MAX_MB=${PIPELINE_CACHE_MAX_MB:-40}
mkdir -p "$OUT"
stamp=$(date +%Y%m%d_%H%M)

case "${1:-}" in
desktop)
	printf '[display]\nwindow/size/no_focus=true\n' > override.cfg
	trap 'rm -f override.cfg' EXIT
	log="$OUT/desktop_$stamp.log"
	bwrap --dev-bind / / --tmpfs /dev/input "$GODOT" --path . --display-driver x11 --screen 1 -- --benchmark > "$log" 2>&1 || true
	json=$(sed -n 's/^BENCH_DONE //p' "$log" | tail -1)
	[ -n "$json" ] || { echo "no terminó, mirá $log"; exit 1; }
	dest="$OUT/desktop_$(uname -n)_$stamp.json"
	cp "$json" "$dest"
	;;
android)
	serial=${2:?falta el serial de adb}
	for busy in ${BUSY_PACKAGES:-dev.asteroids.game}; do
		if adb -s "$serial" shell pidof "$busy" > /dev/null 2>&1; then
			echo "$busy está corriendo en $serial (el teléfono es compartido), no lo interrumpo"
			exit 1
		fi
	done
	if [ "${3:-}" = "--build" ] || [ ! -f "$APK" ]; then
		mkdir -p "$(dirname "$APK")"
		"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
		"$GODOT" --headless --path . --export-debug "Android (benchmark)" "$APK" > "$OUT/export_$stamp.log" 2>&1
	fi
	# Sin el fd del lock: si un adb de acá arranca el servidor, el servidor lo heredaba y dejaba el teléfono trabado.
	adb() { command adb "$@" 9>&-; }
	# BENCH_LOCK_HELD: quien llama ya tiene el lock en el fd 9 (varias corridas seguidas sin soltar el teléfono).
	if [ -z "${BENCH_LOCK_HELD:-}" ]; then
		exec 9> "${XDG_RUNTIME_DIR:-/tmp}/epiphany_bench_$serial.lock"
		flock -n 9 || { echo "otra corrida usa $serial, espero mi turno"; flock 9; }
	fi
	if adb -s "$serial" shell dumpsys user | grep -q RUNNING_LOCKED; then
		echo "$serial se reinició y nadie lo desbloqueó: sin eso el juego no tiene dónde escribir"
		exit 1
	fi
	adb -s "$serial" install -r "$APK" > /dev/null
	adb -s "$serial" shell am force-stop "$PACKAGE"
	# La caché de pipelines junta los de todos los builds instalados y el juego la tiene entera en memoria (15.27).
	cache_kb=$(adb -s "$serial" shell run-as "$PACKAGE" du -k files/vulkan 2> /dev/null | tail -1 | cut -f1 | tr -dc 0-9)
	if [ "${cache_kb:-0}" -gt $((PIPELINE_CACHE_MAX_MB * 1024)) ]; then
		adb -s "$serial" shell run-as "$PACKAGE" sh -c "'rm -f files/vulkan/pipelines.*.cache'"
		echo "borré la caché de pipelines ($((cache_kb / 1024)) MB): la primera carga de cada nivel en esta corrida es en frío"
	fi
	adb -s "$serial" shell run-as "$PACKAGE" rm -f files/benchmark/latest.json
	# Con la pantalla apagada Android pausa el juego y la corrida no avanza (15.27).
	adb -s "$serial" shell input keyevent KEYCODE_WAKEUP
	adb -s "$serial" shell wm dismiss-keyguard
	sleep 1
	if adb -s "$serial" shell dumpsys window | grep -q "isKeyguardShowing=true"; then
		echo "$serial tiene la pantalla bloqueada: sin desbloquearlo el juego queda en pausa"
		exit 1
	fi
	adb -s "$serial" logcat -c
	adb -s "$serial" shell am start -n "$PACKAGE/com.godot.game.GodotAppLauncher" > /dev/null
	model=$(adb -s "$serial" shell getprop ro.product.model | tr -d '\r' | tr ' ' '_')
	log="$OUT/${model}_$stamp.log"
	: > "$log"
	done_json() { adb -s "$serial" shell run-as "$PACKAGE" ls files/benchmark/latest.json > /dev/null 2>&1; }
	for _ in $(seq 1 540); do
		sleep 5
		if ! adb -s "$serial" get-state > /dev/null 2>&1; then
			timeout 120 adb -s "$serial" wait-for-device 9>&- || true
			continue
		fi
		adb -s "$serial" logcat -d -s godot:V > "$log.new" 2>/dev/null && [ -s "$log.new" ] && mv "$log.new" "$log"
		grep -q "BENCH_DONE" "$log" && break
		if ! adb -s "$serial" shell pidof "$PACKAGE" > /dev/null 2>&1 && { sleep 5; ! adb -s "$serial" shell pidof "$PACKAGE" > /dev/null 2>&1; }; then
			done_json && break
			echo "el juego se cerró antes de terminar, mirá $log"
			exit 1
		fi
	done
	grep -q "BENCH_DONE" "$log" || done_json || { echo "no terminó en 45 min, mirá $log"; exit 1; }
	dest="$OUT/${model}_$stamp.json"
	adb -s "$serial" exec-out run-as "$PACKAGE" cat files/benchmark/latest.json > "$dest"
	;;
*)
	sed -n '2,4p' "$0"
	exit 1
	;;
esac
python3 -I tools/bench_report.py "$dest"
echo "$dest"
