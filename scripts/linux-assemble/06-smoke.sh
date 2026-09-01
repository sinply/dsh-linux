#!/usr/bin/env bash
# Step 6: headless smoke tests against the assembled bundle.
#   1) catalog version
#   2) landlock launcher probe + confined run (bundled binary)
#   3) bwrap rung probe + confined run (first-choice Linux runner; Rocky 8 path)
#   4) dsh web boots, binds 127.0.0.1:3080, token URL serves the app (303 -> 200)
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
BUNDLE_DIR="$STAGE/bundle/dsh-linux-x64"
DSH="$BUNDLE_DIR/bin/dsh"
export PATH="$BUNDLE_DIR/node/bin:$PATH"

echo "== 1. catalog version =="
"$DSH" --version

echo "== 2. landlock rung (bundled static launcher) =="
LL="$BUNDLE_DIR/app/node_modules/@deepseek-ai/node-addon-landlock-run-linux-x64/bin/landlock-run"
file "$LL" | head -1
"$LL" --probe 2>&1 || true
echo -n "confined run (read-only /): "
"$LL" --ro / --rw /dev/null -- bash -c 'echo landlock-confined-ok'

echo "== 3. bundled static bwrap rung (first-choice on Linux; Rocky 8 path) =="
export PATH="$BUNDLE_DIR/bin:$PATH"
echo -n "resolved bwrap: "
command -v bwrap
file "$(command -v bwrap)" | head -1
echo -n "probe (provider's exact command): "
bwrap --ro-bind / / --dev /dev --unshare-pid --proc /proc --die-with-parent -- true && echo "bwrap-probe-ok"
echo -n "confined run: "
bwrap --ro-bind / / --dev /dev --unshare-pid --proc /proc --die-with-parent -- bash -c 'echo bwrap-confined-ok'

echo "== 4. dsh web headless boot =="
export DSH_HOME="$STAGE/smoke-home"
rm -rf "$DSH_HOME"
"$DSH" web > "$STAGE/web-smoke.log" 2>&1 &
WEB_PID=$!
echo "web pid=$WEB_PID, waiting for listener..."
for i in $(seq 1 45); do
  URL=$(grep -oE "http://127\.0\.0\.1:3080/\?token=[A-Za-z0-9_-]+" "$STAGE/web-smoke.log" 2>/dev/null | head -1 || true)
  [ -n "$URL" ] && break
  sleep 1
done
if [ -z "$URL" ]; then
  echo "NO TOKEN URL within 45s; tail of log:"
  tail -20 "$STAGE/web-smoke.log"
  kill "$WEB_PID" 2>/dev/null || true
  exit 1
fi
echo "url=$URL"
JAR="$STAGE/web-cookies.txt"
rm -f "$JAR"
HTTP_CODE=$(curl -L -s -c "$JAR" -b "$JAR" -o /dev/null -w "%{http_code}" "$URL")
FINAL_URL=$(curl -L -s -c "$JAR" -b "$JAR" -o /dev/null -w "%{url_effective}" "$URL")
echo "HTTP status (redirects followed, cookies kept): $HTTP_CODE  final: $FINAL_URL"
[ "$HTTP_CODE" = "200" ] || { echo "app not 200"; kill "$WEB_PID" || true; exit 1; }
echo "server log excerpt:"
grep -vE "^\s*$" "$STAGE/web-smoke.log" | head -8
echo "web boot OK; stopping"
kill "$WEB_PID" 2>/dev/null || true
sleep 1
echo "== done =="