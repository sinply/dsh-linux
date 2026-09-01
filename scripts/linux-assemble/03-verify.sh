#!/usr/bin/env bash
# Step 3: verify the linux-x64 resolution inside the staged install:
# CLI version, platform prebuilt binaries, and absence of install-time compilation.
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
export PATH="$STAGE/node/bin:$PATH"
APP="$STAGE/app/node_modules"

echo "== 1. dsh CLI version =="
"$STAGE/node/bin/node" "$APP/@deepseek-ai/dsh/lib/bin.js" --version

echo "== 2. platform-first binaries (linux-x64) =="
echo "-- landlock-run launcher --"
find "$APP" -name landlock-run -type f 2>/dev/null || echo MISSING
echo "-- koffi native lib --"
find "$APP" -name "koffi*.node" 2>/dev/null || echo MISSING
echo "-- typert binary --"
find "$APP" -path "*typert*" -type f 2>/dev/null | grep -v "\.map$" | head -8 || echo MISSING
echo "-- esbuild --"
find "$APP" -path "*esbuild*" -name esbuild -type f 2>/dev/null | head -2 || echo MISSING
echo "-- rolldown binding --"
find "$APP" -name "*.node" -path "*rolldown*" 2>/dev/null | head -4 || echo MISSING

echo "== 3. compile evidence in install log =="
grep -ciE "node-gyp|gyp ERR" "$STAGE/npm-install.log" || echo "none"

echo "== 4. sizes =="
du -sh "$STAGE/app/node_modules" 2>/dev/null
echo "top-level packages: $(ls "$APP" | wc -l)"

echo "== 5. glibc/arch sanity =="
find "$APP" -name landlock-run -type f -exec file {} \; 2>/dev/null
find "$APP" -name "koffi*.node" -exec file {} \; 2>/dev/null