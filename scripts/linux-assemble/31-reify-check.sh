#!/usr/bin/env bash
L=$(ls -t /home/sinply/.npm/_logs/*.log | head -1)
echo "LOG=$L  lines=$(wc -l < "$L")"
echo "=== 是否有 reify 阶段 ==="
grep -c 'silly reify' "$L" || true
grep -m3 'silly reify' "$L" || echo "(无 reify 记录)"
echo "=== 结尾 25 行 ==="
tail -25 "$L"