#!/usr/bin/env bash
H="${1:-$HOME/dsh-linux-build/dsh-vscode-home}"
S=$(find "$H/sessions" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | head -1)
echo "=== session dir: $S ==="
ls -la "$S"
echo "=== files sizes ==="
find "$S" -type f -exec du -h {} + 2>/dev/null
echo "=== first file head (first 3 lines, truncated) ==="
F=$(find "$S" -type f | head -1)
[ -n "$F" ] && head -c 1200 "$F"
echo
echo "=== file names under one session ==="
find "$S" -type f -printf "%f\n" 2>/dev/null | head