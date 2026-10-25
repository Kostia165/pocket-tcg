#!/bin/sh
# Builds the debug APK, installs it on the connected phone and launches the game.
# Run from Git Bash:  sh tools/deploy.sh
# Override tool locations with the GODOT and ADB environment variables.
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-/d/Program Files/Godot/Godot_v4.7.2-stable_win64_console.exe}"
ADB="${ADB:-/d/ProgramData/Android/Sdk/platform-tools/adb.exe}"

mkdir -p build
"$GODOT" --headless --path . --export-debug "Android" build/pocket-tcg.apk 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR: .*\.gd"
cp build/pocket-tcg.apk pocket-tcg.apk

# The export restarts adb; wait until the phone is authorized again.
for i in $(seq 1 20); do "$ADB" get-state 2>/dev/null | grep -q "^device" && break; sleep 1; done
"$ADB" install -r build/pocket-tcg.apk | tail -1
"$ADB" shell am force-stop com.pockettcg.game
"$ADB" shell monkey -p com.pockettcg.game -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
