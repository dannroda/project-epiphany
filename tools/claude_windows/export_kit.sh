#!/usr/bin/env bash
# Desde Linux: copia la memoria y los skills del perfil de Claude al kit, para llevarlos a Windows por git.
set -euo pipefail
kit="$(cd "$(dirname "$0")" && pwd)"
profile="${CLAUDE_CONFIG_DIR:-$HOME/.claude-profiles/personal}"
memory="$profile/projects/-home-drod-Proyectos-Godot-project-epiphany/memory"
rm -rf "$kit/memory" "$kit/skills"
mkdir -p "$kit/memory" "$kit/skills"
cp "$memory"/*.md "$kit/memory/"
cp "$kit"/windows_memory/*.md "$kit/memory/"
for file in "$kit"/windows_memory/*.md; do
	name="$(basename "$file" .md)"
	title="$(grep -m1 '^description:' "$file" | sed 's/^description: *//; s/^"//; s/"$//')"
	echo "- [$name]($name.md) — $title" >> "$kit/memory/MEMORY.md"
done
for skill in "$profile"/skills/godot-*; do
	cp -r "$skill" "$kit/skills/"
done
echo "Kit actualizado: $(ls "$kit/memory" | wc -l) memorias, $(ls "$kit/skills" | wc -l) skills"
