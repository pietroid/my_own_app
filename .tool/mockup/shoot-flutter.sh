#!/usr/bin/env bash
# Screenshots a Flutter web build as a phone (390x844 @2x), one PNG per scene,
# plus strip.png with all of them side by side. macOS, Chrome, Node >= 22.
#
# Usage: shoot-flutter.sh <web_build_dir> <out_dir> <scene> [scene...]
# Each scene is loaded as /?s=<scene>; the preview entry point reads it.
#
# Why not `chrome --screenshot`: headless windows are at least ~500px wide, so
# Flutter lays out wider than the crop, and --virtual-time-budget freezes
# animations (a bottom sheet never finishes sliding in). This drives Chrome
# over the DevTools protocol instead: real mobile emulation, real time.
set -euo pipefail
web=$(cd "$1" && pwd); out=$2; shift 2
mkdir -p "$out"; out=$(cd "$out" && pwd)
here=$(cd "$(dirname "$0")" && pwd)
port=$((20000 + RANDOM % 20000)); debug=$((port + 1))
profile=$(mktemp -d)

python3 -m http.server "$port" -d "$web" >/dev/null 2>&1 & server=$!; disown
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --remote-debugging-port="$debug" --user-data-dir="$profile" --hide-scrollbars \
  about:blank >/dev/null 2>&1 & chrome=$!; disown
trap 'kill $server $chrome 2>/dev/null; sleep 1; rm -rf "$profile" 2>/dev/null || true' EXIT
# Chrome takes 2-4 s to open its debug port on a busy machine: wait for it
# (up to 20 s) rather than for a fixed time.
for _ in $(seq 40); do
  curl -s "http://127.0.0.1:$debug/json/version" >/dev/null && break
  sleep 0.5
done

imgs=""
for scene in "$@"; do
  node "$here/shoot.mjs" "$debug" "http://localhost:$port/?s=$scene" "$out/$scene.png" 4500
  imgs="$imgs<img src=\"$scene.png\" width=\"390\">"
done

count=$#
cat > "$out/strip.html" <<HTML
<!doctype html><html><body style="margin:0;background:#EFE9EA;display:flex;gap:24px;padding:24px">$imgs</body></html>
HTML
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --window-size=$((24 + count * 414)),892 --screenshot="$out/strip.png" "file://$out/strip.html" 2>/dev/null
ls "$out"
