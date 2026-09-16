#!/usr/bin/env bash
N=/home/sinply/dsh-linux-build/app/node_modules/.pnpm
DIR=$(find "$N" -maxdepth 1 -type d -name '*dsh-subagent-claude-code*' | head -1)
P="$DIR/node_modules/@deepseek-ai/dsh-subagent-claude-code"
echo "=== 可配置项 / executable 指定 ==="
grep -rn "executable\|claudePath\|CLAUDE\|env\b\|process.env" "$P/lib/index.js" 2>/dev/null | grep -iv '//' | head -12
echo
echo "=== README（启用方式/前置） ==="
sed -n '1,60p' "$P/README.md" 2>/dev/null
echo
echo "=== 默认 web profile 是否已含 subagent-claude-code 行 ==="
WEB=$(find "$N" -maxdepth 1 -type d -name '*dsh-web-app*' | head -1)
grep -rn "subagent-claude-code\|subagent-codex\|tool-subagent\|model-selection" "$WEB/node_modules/@deepseek-ai/dsh-web-app/cordis.patch.yml" 2>/dev/null | head