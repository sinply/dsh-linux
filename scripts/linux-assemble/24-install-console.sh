#!/usr/bin/env bash
# Console run of npm install (for diagnosing the silent exit 1) + OOM check.
export PATH=/home/sinply/dsh-linux-build/node/bin:$PATH
cd /home/sinply/dsh-linux-build/app || exit 2
rm -f package-lock.json
npm install --no-audit --no-fund --no-progress --foreground-scripts 2>&1 | tail -25
echo "NPM_EXIT=${PIPESTATUS[0]}"
echo "--- dmesg oom ---"
dmesg 2>/dev/null | grep -iE 'killed process|out of memory' | tail -5 || echo "(dmesg 不可读或无记录)"