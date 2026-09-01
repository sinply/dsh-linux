#!/usr/bin/env bash
# Find where subagent-claude-code / subagent-codex appear in installed profiles:
# cordis patch layers and resolver manifests of shipped packages.
N="${STAGE_DIR:-$HOME/dsh-linux-build}/app/node_modules"
export PATH="${STAGE_DIR:-$HOME/dsh-linux-build}/node/bin:$PATH"

echo "=== cordis patch layers referencing claude-code / codex ==="
grep -rln "claude-code\|subagent-codex" "$N/@deepseek-ai/"*/cordis*.yml 2>/dev/null | sed "s|$N/||"
echo "(none above = not wired into any shipped profile layer)"

echo
echo "=== resolver manifests / source referencing subagent backends ==="
grep -rln "subagent-claude-code\|subagent-codex" "$N/@deepseek-ai/"*/lib/*.js 2>/dev/null | sed "s|$N/||" | head -10

echo
echo "=== optionalDependencies of subagent packages (with node from stage) ==="
node -e '
const fs=require("fs");
for (const d of ["dsh-subagent-claude-code","dsh-subagent-codex","dsh-subagent-dsh-sdk","dsh-subagent-acp"]) {
  const p=require(process.argv[1]+"/@deepseek-ai/"+d+"/package.json");
  console.log(d+": deps="+JSON.stringify(Object.keys(p.dependencies||{}))+" optional="+JSON.stringify(Object.keys(p.optionalDependencies||{})));
}' "$N"