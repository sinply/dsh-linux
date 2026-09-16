#!/usr/bin/env bash
N=/home/sinply/dsh-linux-build/app/node_modules/.pnpm
# locate the installed claude-code subagent package (rc.1)
DIR=$(find "$N" -maxdepth 1 -type d -name '*dsh-subagent-claude-code*' | head -1)
echo "package dir: $DIR"
P="$DIR/node_modules/@deepseek-ai/dsh-subagent-claude-code"
echo "=== cordis.patch.yml (how to enable) ==="
cat "$P/cordis.patch.yml" 2>/dev/null | head -40
echo
echo "=== package.json deps/config keys ==="
node -e "const p=require('$P/package.json'); console.log('name',p.name,'ver',p.version); console.log('deps',JSON.stringify(Object.keys(p.dependencies||{}))); console.log('config?', JSON.stringify(p.dsh||{}).slice(0,400))" 2>&1 | head -5
echo
echo "=== how it spawns claude (executable/env) ==="
grep -rn "claude-agent-sdk\|ANTHROPIC_API_KEY\|apiKey\|executable\|spawn" "$P/lib/index.js" 2>/dev/null | head -12