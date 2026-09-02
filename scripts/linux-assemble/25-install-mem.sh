#!/usr/bin/env bash
export PATH=/home/sinply/dsh-linux-build/node/bin:$PATH
cd /home/sinply/dsh-linux-build/app || exit 2
echo "== clean npm cache =="
npm cache clean --force 2>&1 | tail -2
echo "== memory sampler =="
( for i in $(seq 1 120); do date +%H:%M:%S; free -m | awk '/Mem:/{print "mem used=" $3 " free=" $4}'; sleep 3; done ) > ~/dsh-linux-build/mem-sample.txt 2>&1 &
SAMPLE=$!
echo "== npm install (console) =="
rm -f package-lock.json
npm install --no-audit --no-fund --no-progress --foreground-scripts 2>&1 | tail -20
echo "NPM_EXIT=${PIPESTATUS[0]}"
kill $SAMPLE 2>/dev/null
echo "== memory sample tail =="
tail -6 ~/dsh-linux-build/mem-sample.txt