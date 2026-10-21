#!/usr/bin/env bash
# Godot con el renderer de verdad sin ventana en la pantalla de Daniel: gamescope headless (la GPU real) dentro de un
# bwrap que tapa los sockets de su Wayland y su X, así si algo falla no puede abrir nada afuera, y el gamepad.
# xvfb-run no sirve: Vulkan no presenta sin DRI3 y Godot cae a Wayland, que es su sesión.
#   tools/offscreen.sh --path . [--rendering-method mobile] -s script.gd
set -euo pipefail
GODOT=${GODOT:-/opt/godot/versions/4.8-beta1/godot}
hide=()
for socket in /run/user/"$(id -u)"/wayland-*; do
	[ -S "$socket" ] && hide+=(--ro-bind /dev/null "$socket")
done
exec env -u WAYLAND_DISPLAY -u DISPLAY bwrap --dev-bind / / --tmpfs /dev/input --tmpfs /tmp/.X11-unix "${hide[@]}" \
	gamescope --backend headless -W 1600 -H 720 -w 1600 -h 720 -- "$GODOT" --display-driver x11 "$@"
