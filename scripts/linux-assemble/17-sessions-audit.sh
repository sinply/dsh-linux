#!/usr/bin/env bash
# Locate dsh session files under a DSH_HOME and show one JSONL schema sample.
H="${1:-$HOME/dsh-linux-build/dsh-vscode-home}"
echo "=== home: $H ==="
echo "=== find session files (jsonl/ndjson) ==="
find "$H" -name "*.jsonl" -o -name "*.ndjson" 2>/dev/null | head -8
echo "=== sessions dir ==="
ls -la "$H/sessions" 2>/dev/null | head -8
echo "=== any log files ==="
find "$H" -maxdepth 3 -type d 2>/dev/null | head -20