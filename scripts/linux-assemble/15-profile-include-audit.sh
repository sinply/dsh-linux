#!/usr/bin/env bash
# Which of the candidate prune packages are wired into the SHIPPED web/base
# profile composition (loader includes inside dsh-web-app / dsh-base layers).
B="${STAGE_DIR:-$HOME/dsh-linux-build}/bundle/dsh-linux-x64"
N="$B/app/node_modules"
echo "=== web-app layer files ==="
find "$N/@deepseek-ai/dsh-web-app" -maxdepth 2 -name "*.yml" -o -maxdepth 2 -name "*.js" | head -8
echo
for name in "session-telemetry-otel" "subagent-claude-code" "subagent-codex"; do
  echo "--- '$name' referenced in shipped layers? ---"
  grep -rl "$name" "$N/@deepseek-ai/dsh-web-app" "$N/@deepseek-ai/dsh-base" "$N/@deepseek-ai/dsh-app-boot" 2>/dev/null | sed "s|$N/||" | head -5
  echo
done
echo "=== does the JS wrapper import the platform binary eagerly? ==="
for p in "@anthropic-ai/claude-agent-sdk" "@openai/codex"; do
  echo "--- $p ---"
  grep -rn "claude-agent-sdk-\|codex-" "$N/$p"/*.js 2>/dev/null | head -6
done