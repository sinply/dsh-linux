#!/usr/bin/env bash
A=/home/sinply/dsh-linux-build/bundle/dsh-linux-x64/app/node_modules/@deepseek-ai/dsh-web-frontend/dist/assets
echo "=== total web assets ==="
du -sh "$A" 2>/dev/null
echo "=== biggest js/css ==="
ls -S "$A"/*.js "$A"/*.css 2>/dev/null | head -6 | while read -r f; do du -h "$f"; done
echo "=== lang chunks count ==="
ls "$A"/langs/ 2>/dev/null | wc -l
echo "=== main vendor/index ==="
du -h "$A"/vendor-*.js "$A"/index-*.js 2>/dev/null | sort -rh | head -3
echo "=== fonts size ==="
du -sh "$A"/fonts 2>/dev/null