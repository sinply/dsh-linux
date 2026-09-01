#!/usr/bin/env bash
# Which @deepseek-ai packages declare the heavy optional SDKs as dependencies,
# and whether their lib code imports those SDKs at module top level (eager).
N="${STAGE_DIR:-$HOME/dsh-linux-build}/app/node_modules"
echo "=== dependents of heavy SDKs ==="
for pkg in "@anthropic-ai/claude-agent-sdk" "@openai/codex" "opentelemetry" "typescript" "sharp" "@img/sharp"; do
  echo "--- dependents of $pkg ---"
  grep -rl "\"$pkg" "$N/@deepseek-ai/"*/package.json 2>/dev/null | sed "s|$N/||;s|/package.json||" | sort -u
  echo
done
echo "=== eager top-level imports of SDKs in built lib (non-optional) ==="
grep -rl "require(\"@anthropic-ai\|require(\"@openai\|from \"@anthropic-ai\|from \"@openai/codex" "$N/@deepseek-ai/"*/lib/ 2>/dev/null | head -10 | sed "s|$N/||"
echo
echo "=== optionalDependencies of the two subagent packages ==="
node -e '
const fs=require("fs");
for (const d of ["@deepseek-ai/dsh-subagent-claude-code","@deepseek-ai/dsh-subagent-codex","@deepseek-ai/dsh-subagent-acp","@deepseek-ai/dsh-agent"]) {
  const p=require(process.argv[1]+"/"+d+"/package.json");
  console.log(d, "\n  dependencies:", JSON.stringify(Object.keys(p.dependencies||{})), "\n  optionalDependencies:", JSON.stringify(Object.keys(p.optionalDependencies||{})));
}' "$N"