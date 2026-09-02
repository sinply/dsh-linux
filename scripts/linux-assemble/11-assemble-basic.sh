#!/usr/bin/env bash
# Step 11: Basic variants — prune Claude Code / Codex subagent binaries and OTel
# telemetry from the FULL bundles (prod. by 04 = bundled-node, 10 = system-node)
# and repack. Copy-based (hardlinks): source bundles stay untouched.
# Required env:
#   OUT_DIR      deliverable directory (receives dsh-linux-x64-basic[-slim].tar.gz)
#   SYSTEM_NODE  node dir for the slim smoke (default $STAGE/node24)
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
: "${OUT_DIR:?set OUT_DIR (deliverable directory)}"
SYSTEM_NODE="${SYSTEM_NODE:-$STAGE/node24}"

FULL_SRC="$STAGE/bundle/dsh-linux-x64"
SLIM_SRC="$STAGE/bundle-slim/dsh-linux-x64"

# proven-dead payloads: the platform BINARY packages of the Claude Code / Codex
# subagent backends. Their JS wrappers and the plugin packages stay (tiny, and
# the plugins are not wired into the shipped web profile); the binaries are only
# needed when actually spawning those CLIs. OTel + session-telemetry-otel stay:
# session-telemetry-otel IS in the shipped base layer.
PRUNE_DIRS=(
  "@anthropic-ai/claude-agent-sdk-linux-x64"
  "@openai/codex-linux-x64"
)

prune_and_tar() {
  local src="$1" out_tgz="$2" workbase="$3"
  local workdir="$workbase/dsh-linux-x64"
  rm -rf "$workbase"
  mkdir -p "$workbase"
  cp -al "$src" "$workdir"
  echo "prune: before=$(du -sh "$workdir" | cut -f1)"
  # Works for both npm (hoisted: node_modules/<pkg>) and pnpm (isolated:
  # node_modules/.pnpm/<scope>+<name>@<ver>/...) layouts.
  for d in "${PRUNE_DIRS[@]}"; do
    rm -rf "$workdir/app/node_modules/$d"
    local pnpm_name="${d/\//+}"
    find "$workdir/app/node_modules/.pnpm" -maxdepth 1 -type d -name "${pnpm_name}@*" -exec rm -rf {} + 2>/dev/null || true
  done
  # node-pty: keep only the platforms this distribution targets (both layouts)
  find "$workdir/app/node_modules/node-pty/prebuilds" -mindepth 1 -maxdepth 1 -type d \
    ! -name "linux-x64" ! -name "linux-arm64" -exec rm -rf {} + 2>/dev/null || true
  find "$workdir/app/node_modules/.pnpm" -maxdepth 1 -type d -name '*node-pty*' -print0 2>/dev/null |
    while IFS= read -r -d "" d; do
      find "$d/node_modules/node-pty/prebuilds" -mindepth 1 -maxdepth 1 -type d \
        ! -name "linux-x64" ! -name "linux-arm64" -exec rm -rf {} + 2>/dev/null || true
    done
  # debug sourcemaps (never loaded at runtime)
  find "$workdir/app/node_modules" -name "*.map" -size +32k -delete 2>/dev/null || true
  echo "prune: after =$(du -sh "$workdir" | cut -f1)"
  tar -C "$workbase" -czf "$out_tgz" dsh-linux-x64
  ls -lh "$out_tgz" | awk '{print $5}'
}

smoke_web() {  # $1=bundle dir  $2=node bin ("" = bundled)  $3=tag
  local bdir="$1" node_bin="$2" tag="$3"
  echo "== smoke $tag: version =="
  if [ -n "$node_bin" ]; then DSH_NODE_BIN="$node_bin" "$bdir/bin/dsh" --version
  else "$bdir/bin/dsh" --version; fi
  echo "== smoke $tag: web boot =="
  export DSH_HOME="$STAGE/smoke-home-$tag"
  rm -rf "$DSH_HOME"
  if [ -n "$node_bin" ]; then
    DSH_NODE_BIN="$node_bin" "$bdir/bin/dsh" web --no-open > "$STAGE/web-$tag.log" 2>&1 &
  else
    "$bdir/bin/dsh" web --no-open > "$STAGE/web-$tag.log" 2>&1 &
  fi
  WEB_PID=$!
  URL=""
  for i in $(seq 1 45); do
    URL=$(grep -oE "http://127\.0\.0\.1:3080/\?token=[A-Za-z0-9_-]+" "$STAGE/web-$tag.log" 2>/dev/null | head -1 || true)
    [ -n "$URL" ] && break
    sleep 1
  done
  if [ -z "$URL" ]; then echo "NO URL; tail:"; tail -12 "$STAGE/web-$tag.log"; kill "$WEB_PID" 2>/dev/null || true; return 1; fi
  JAR="$STAGE/web-cookies-$tag.txt"; rm -f "$JAR"
  CODE=$(curl -L -s -c "$JAR" -b "$JAR" -o /dev/null -w "%{http_code}" "$URL")
  echo "$URL -> $CODE"
  kill "$WEB_PID" 2>/dev/null || true
  sleep 1
  [ "$CODE" = "200" ]
}

echo "== 1. basic bundled (own node) =="
prune_and_tar "$FULL_SRC" "$OUT_DIR/dsh-linux-x64-basic.tar.gz" "$STAGE/basic-bundled"
smoke_web "$STAGE/basic-bundled/dsh-linux-x64" "" "basic"

echo "== 2. basic slim (system node $SYSTEM_NODE) =="
test -x "$SYSTEM_NODE/bin/node" || { echo "SYSTEM_NODE missing: $SYSTEM_NODE"; exit 1; }
prune_and_tar "$SLIM_SRC" "$OUT_DIR/dsh-linux-x64-basic-slim.tar.gz" "$STAGE/basic-slim"
smoke_web "$STAGE/basic-slim/dsh-linux-x64" "$SYSTEM_NODE/bin/node" "basic-slim"

echo "== done. deliverables in $OUT_DIR =="
ls -lh "$OUT_DIR"/dsh-linux-x64* | awk '{print $9, $5}'