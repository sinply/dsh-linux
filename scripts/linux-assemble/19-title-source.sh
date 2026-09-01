#!/usr/bin/env bash
H="${1:-$HOME/dsh-linux-build/dsh-vscode-home}"
echo "=== storages tree ==="
find "$H/storages" -maxdepth 4 2>/dev/null | head -40
echo
echo "=== any readable json (title/meta) under storages or session dir ==="
find "$H/storages" -type f \( -name "*.json" -o -name "*.jsonl" -o -name "meta*" -o -name "title*" \) 2>/dev/null | head
echo
echo "=== list a projection-cache session dir ==="
SC=$(find "$H/storages/session_projcache" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | head -1)
echo "cache dir: $SC"
ls -la "$SC" 2>/dev/null
echo
echo "=== file types under a session dir ==="
S=$(find "$H/sessions" -mindepth 2 -maxdepth 2 -type d | head -1)
find "$S" -type f -exec file {} + 2>/dev/null