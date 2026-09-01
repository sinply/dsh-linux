#!/usr/bin/env bash
# Step 10: assemble the SLIM variant — for intranet hosts that already run a
# system Node.js. The bundle ships WITHOUT the node runtime; bin/dsh resolves
# node from PATH (or $DSH_NODE_BIN). Everything else (deps incl. Web assets,
# static bwrap) is identical to the full bundle.
# Required env:
#   STAGE_DIR   build stage (default $HOME/dsh-linux-build)
#   OUT_DIR     directory that receives dsh-linux-x64-slim.tar.gz
#   SYSTEM_NODE dir containing a system node binary used for verification
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
: "${OUT_DIR:?set OUT_DIR (deliverable directory)}"
SYSTEM_NODE="${SYSTEM_NODE:-$STAGE/node24}"
BUNDLE_DIR="$STAGE/bundle-slim/dsh-linux-x64"
TARBALL="$STAGE/dsh-linux-x64-slim.tar.gz"
export PATH="$SYSTEM_NODE/bin:$PATH"

echo "== system node for verification =="
"$SYSTEM_NODE/bin/node" --version
node --version

echo "== 1. assemble slim bundle =="
rm -rf "$STAGE/bundle-slim" "$TARBALL"
mkdir -p "$BUNDLE_DIR/bin" "$BUNDLE_DIR/app"

echo "== 2. copy app (node_modules + Web assets, same as full bundle) =="
cp -a "$STAGE/app/node_modules" "$BUNDLE_DIR/app/node_modules"
cp "$STAGE/app/package.json" "$BUNDLE_DIR/app/package.json" 2>/dev/null || true

echo "== 3. bundle static bwrap =="
if [ -x "$STAGE/bwrap/bwrap" ]; then
  cp "$STAGE/bwrap/bwrap" "$BUNDLE_DIR/bin/bwrap"
  chmod +x "$BUNDLE_DIR/bin/bwrap"
fi

echo "== 3b. bundle check-env.sh (env self-check) =="
if [ -n "${DSH_LINUX_REPO:-}" ] && [ -f "$DSH_LINUX_REPO/scripts/linux-assemble/check-env.sh" ]; then
  cp "$DSH_LINUX_REPO/scripts/linux-assemble/check-env.sh" "$BUNDLE_DIR/bin/check-env.sh"
  chmod +x "$BUNDLE_DIR/bin/check-env.sh"
  echo "check-env.sh bundled"
else
  echo "WARN: DSH_LINUX_REPO unset/missing — slim bundle ships without check-env.sh"
fi

echo "== 4. write slim bin/dsh wrapper =="
cat > "$BUNDLE_DIR/bin/dsh" <<'EOF'
#!/usr/bin/env bash
# Slim variant: no bundled node — resolves the SYSTEM node (>=22.19, 24.x LTS
# recommended) from $DSH_NODE_BIN or PATH. bin/ (static bwrap) stays on PATH.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$ROOT/bin:$PATH"
NODE_BIN="${DSH_NODE_BIN:-node}"
if ! command -v "$NODE_BIN" >/dev/null 2>&1; then
  echo "error: node not found (set DSH_NODE_BIN or add node >=22.19 to PATH)" >&2
  exit 127
fi
exec "$NODE_BIN" "$ROOT/app/node_modules/@deepseek-ai/dsh/lib/bin.js" "$@"
EOF
chmod +x "$BUNDLE_DIR/bin/dsh"

echo "== 5. smoke: version via system node =="
"$BUNDLE_DIR/bin/dsh" --version

echo "== 6. smoke: bundled static bwrap rung =="
"$STAGE/bwrap/bwrap" --version
export PATH="$BUNDLE_DIR/bin:$PATH"
bwrap --ro-bind / / --dev /dev --unshare-pid --proc /proc --die-with-parent -- true && echo "bwrap-probe-ok (slim)"

echo "== 7. smoke: dsh web headless boot (system node) =="
export DSH_HOME="$STAGE/smoke-home-slim"
rm -rf "$DSH_HOME"
"$BUNDLE_DIR/bin/dsh" web > "$STAGE/web-smoke-slim.log" 2>&1 &
WEB_PID=$!
for i in $(seq 1 45); do
  URL=$(grep -oE "http://127\.0\.0\.1:3080/\?token=[A-Za-z0-9_-]+" "$STAGE/web-smoke-slim.log" 2>/dev/null | head -1 || true)
  [ -n "$URL" ] && break
  sleep 1
done
if [ -z "$URL" ]; then
  echo "NO TOKEN URL; tail:"; tail -15 "$STAGE/web-smoke-slim.log"
  kill "$WEB_PID" 2>/dev/null || true
  exit 1
fi
echo "$URL"
JAR="$STAGE/web-cookies-slim.txt"; rm -f "$JAR"
CODE=$(curl -L -s -c "$JAR" -b "$JAR" -o /dev/null -w "%{http_code}" "$URL")
echo "HTTP (redirects followed): $CODE"
[ "$CODE" = "200" ] || { echo "not 200"; kill "$WEB_PID" || true; exit 1; }
kill "$WEB_PID" 2>/dev/null || true
sleep 1
echo "web boot OK"

echo "== 8. sizes =="
du -sh "$BUNDLE_DIR"
ls -lh "$TARBALL" 2>/dev/null || true

echo "== 9. tar.gz + copy to OUT_DIR =="
tar -C "$STAGE/bundle-slim" -czf "$TARBALL" dsh-linux-x64
mkdir -p "$OUT_DIR"
cp "$TARBALL" "$OUT_DIR/dsh-linux-x64-slim.tar.gz"
ls -lh "$OUT_DIR/dsh-linux-x64-slim.tar.gz"
echo "== done =="