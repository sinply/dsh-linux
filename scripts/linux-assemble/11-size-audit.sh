#!/usr/bin/env bash
# Size audit of the staged node_modules: big files and category totals.
N="${STAGE_DIR:-$HOME/dsh-linux-build}/app/node_modules"

echo "=== files > 10MB (top 15 by size) ==="
find "$N" -type f -size +10M -print0 2>/dev/null |
while IFS= read -r -d "" f; do
  du -h "$f"
done | sort -rh | head -15

echo
echo "=== category unpacked sizes ==="
du -sh \
  "$N/@anthropic-ai" \
  "$N/@openai" \
  "$N/openai" \
  "$N/@opentelemetry" \
  "$N/typescript" \
  "$N/node-pty" \
  "$N/@shikijs" \
  "$N/@img" \
  "$N/@deepseek-ai" 2>/dev/null

echo
echo "=== gz exclusivity check: contribution of the big SDK dirs to the tarball ==="
T="$HOME/dsh-linux-build"
tar -C "$T/bundle-slim/dsh-linux-x64" -czf /tmp/sdk-only.tar.gz app/node_modules/@anthropic-ai app/node_modules/@openai app/node_modules/openai app/node_modules/@opentelemetry 2>/dev/null
ls -lh /tmp/sdk-only.tar.gz | awk "{print \$5}"