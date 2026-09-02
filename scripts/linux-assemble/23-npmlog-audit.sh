#!/usr/bin/env bash
L=/home/sinply/.npm/_logs/2026-09-02T01_41_33_614Z-debug-0.log
echo "lines: $(wc -l < "$L")"
echo "=== last 40 ==="
tail -40 "$L"
echo "=== error-ish ==="
grep -niE 'err|fail|exception|abort|ECONN|ETIMED|ESOCKET|network' "$L" | tail -15