#!/bin/sh
# Re-import the Godot project (refreshes the class_name cache) and report every
# GDScript parse/compile error.  Usage: tools/check.sh [max_lines]
GODOT=${GODOT:-/opt/godot/Godot_v4.3-stable_linux.x86_64}
DIR=$(dirname "$0")/../godot
"$GODOT" --headless --path "$DIR" --import >/dev/null 2>&1
"$GODOT" --headless --path "$DIR" -s res://tests/compile_all.gd 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR|FAIL|OK|at: " | grep -v main.tscn | head -${1:-80}
