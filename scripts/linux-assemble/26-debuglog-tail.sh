#!/usr/bin/env bash
L=$(ls -t /home/sinply/.npm/_logs/*.log | head -1)
echo "LOG=$L  lines=$(wc -l < "$L")"
echo "=== last 35 ==="
tail -35 "$L"
echo "=== the fetch manifests just before death ==="
grep -n 'fetch manifest' "$L" | tail -6