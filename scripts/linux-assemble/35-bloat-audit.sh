#!/usr/bin/env bash
N=/home/sinply/dsh-linux-build/app/node_modules/.pnpm
echo "=== claude / codex 平台包（pnpm store 内）==="
find "$N" -maxdepth 1 -type d \( -name '*claude-agent-sdk*' -o -name '*codex*' \) -printf '%f\n' | sort
echo
echo "=== 各平台包体积 ==="
find "$N" -maxdepth 1 -type d \( -name '*claude-agent-sdk*' -o -name '*codex*' -o -name '*rolldown*' -o -name '*koffi*' \) -exec du -sh {} \; 2>/dev/null | sort -rh | head -25
echo
echo "=== .pnpm 总大小 ==="
du -sh "$N"