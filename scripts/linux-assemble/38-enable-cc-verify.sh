#!/usr/bin/env bash
# Verify: enable subagent-claude-code via the profile user patch (offline route),
# then boot dsh web headless.
set -e
B=/home/sinply/dsh-linux-build/bundle/dsh-linux-x64
H=/home/sinply/dsh-linux-build/smoke-cc-enable
rm -rf "$H"
export DSH_HOME="$H"
echo "== 1. first boot to init web profile =="
"$B/bin/dsh" web --no-open > /tmp/cc1.log 2>&1 &
P1=$!
URL=""
for i in $(seq 1 40); do URL=$(grep -oE 'http://127\.0\.0\.1:3080/\?token=[A-Za-z0-9_-]+' /tmp/cc1.log 2>/dev/null | head -1 || true); [ -n "$URL" ] && break; sleep 1; done
[ -z "$URL" ] && { echo "no URL"; tail -15 /tmp/cc1.log; kill $P1; exit 1; }
echo "boot1 ok: $URL"
kill $P1; sleep 1

echo "== 2. profiles/web user patch exists? =="
ls -la "$H/profiles/web/" 2>/dev/null | head
echo "== 3. write subagent-claude-code layer into the user patch (replace []) =="
PATCH="$H/profiles/web/cordis.patch.yml"
cat > "$PATCH" <<'EOF'
# Your patch layer for this dsh profile, applied after every bundle layer:
# a top-level YAML array of loader patch entries (id-targeted config
# overrides, disables, and insert lists; `!!js` expressions allowed).
- insert:
    - id: subagent-claude-code
      name: '@deepseek-ai/dsh-subagent-claude-code'
EOF
tail -8 "$PATCH"

echo "== 4. reboot web with the provider row =="
"$B/bin/dsh" web --no-open > /tmp/cc2.log 2>&1 &
P2=$!
URL2=""
for i in $(seq 1 40); do URL2=$(grep -oE 'http://127\.0\.0\.1:3080/\?token=[A-Za-z0-9_-]+' /tmp/cc2.log 2>/dev/null | head -1 || true); [ -n "$URL2" ] && break; sleep 1; done
[ -z "$URL2" ] && { echo "no URL after enable"; tail -25 /tmp/cc2.log; kill $P2; exit 1; }
JAR=/tmp/cc-cookies.txt; rm -f $JAR
CODE=$(curl -L -s -c $JAR -b $JAR -o /dev/null -w '%{http_code}' "$URL2")
echo "boot2 url=$URL2 -> $CODE"
echo "== 5. provider registered? (look for errors / provider in log) =="
grep -iE 'error|failed|claude-code' /tmp/cc2.log | grep -vE '^\s*$' | head -8 || echo "(无错误)"
kill $P2 2>/dev/null || true
echo DONE