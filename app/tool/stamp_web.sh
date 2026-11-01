#!/usr/bin/env bash
# Stamps the PostHog key on a Flutter web build. Without POSTHOG_KEY in the
# environment the snippet in index.html loads nothing.
#
#   flutter build web --release --dart-define-from-file env/production.json
#   POSTHOG_KEY=phc_... tool/stamp_web.sh     # defaults to build/web
set -euo pipefail

app="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:-$app/build/web}"
posthog_key="${POSTHOG_KEY:-}"
case "$posthog_key" in
  *[!A-Za-z0-9_-]*) echo "POSTHOG_KEY is not a project key" >&2; exit 1 ;;
esac

sed -e "s/__POSTHOG_KEY__/$posthog_key/g" "$out/index.html" > "$out/index.html.tmp"
mv "$out/index.html.tmp" "$out/index.html"

if grep -q "__POSTHOG_" "$out/index.html"; then
  echo "placeholders left in $out" >&2
  exit 1
fi
echo "$out is stamped"
