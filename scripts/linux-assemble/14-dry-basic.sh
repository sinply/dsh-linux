#!/usr/bin/env bash
# Dry-run size measurement: which imports @opentelemetry, then measure a pruned
# copy of the slim bundle (claude/codex binaries + dead otel + foreign pty).
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
SRC="$STAGE/bundle-slim/dsh-linux-x64"
WORK="$STAGE/dry-basic"

echo "=== who imports @opentelemetry (top-level lib of kept packages) ==="
grep -rl "@opentelemetry" "$SRC/app/node_modules/@deepseek-ai/"*/lib/ 2>/dev/null | sed "s|$SRC/app/node_modules/||" | head -8 || true
echo "--- transitive pullers (top-level dirs requiring otel) ---"
grep -rl "@opentelemetry/api" "$SRC/app/node_modules/"*/lib/*.js 2>/dev/null | sed "s|$SRC/app/node_modules/||" | head -8 || true

echo
echo "=== build pruned copy (hardlink, fast) ==="
rm -rf "$WORK"
cp -al "$SRC" "$WORK"
echo "before: $(du -sh "$WORK" | cut -f1)"
rm -rf \
  "$WORK/app/node_modules/@anthropic-ai/claude-agent-sdk" \
  "$WORK/app/node_modules/@anthropic-ai/claude-agent-sdk-linux-x64"
rm -rf \
  "$WORK/app/node_modules/@openai/codex" \
  "$WORK/app/node_modules/@openai/codex-linux-x64"
rm -rf "$WORK/app/node_modules/@opentelemetry"
# node-pty: keep only linux-x64 prebuilds
find "$WORK/app/node_modules/node-pty/prebuilds" -mindepth 1 -maxdepth 1 -type d ! -name "linux-x64" ! -name "linux-arm64" -exec rm -rf {} +
# sourcemaps global sweep (debugger-only)
find "$WORK/app/node_modules" -name "*.map" -size +32k -delete
echo "after:  $(du -sh "$WORK" | cut -f1)"

echo
echo "=== tar.gz sizes ==="
tar -C "$STAGE" -czf /tmp/basic-system.tar.gz -C "$WORK" dsh-linux-x64 2>/dev/null || tar -czf /tmp/basic-system.tar.gz -C "$WORK" dsh-linux-x64
ls -lh /tmp/basic-system.tar.gz | awk '{print $5}'
echo "reference full slim: 303M"
ls -lh "$STAGE/dsh-linux-x64-slim.tar.gz" | awk '{print $5}'