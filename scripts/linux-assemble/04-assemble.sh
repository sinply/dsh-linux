#!/usr/bin/env bash
# Step 4: assemble the self-contained bundle layout on native WSL fs, produce
# the tarball, and copy the deliverable into dsh-linux/dist/linux.
# Output root: set OUT_DIR to the directory that receives the deliverable.
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
OUT="${OUT_DIR:?set OUT_DIR (directory that receives dsh-linux-x64.tar.gz)}"
BUNDLE_DIR="$STAGE/bundle/dsh-linux-x64"
TARBALL="$STAGE/dsh-linux-x64.tar.gz"
export PATH="$STAGE/node/bin:$PATH"
. "$(dirname "$0")/lib-build-info.sh"

echo "== 1. assemble bundle on native fs =="
rm -rf "$STAGE/bundle" "$TARBALL"
mkdir -p "$BUNDLE_DIR/bin" "$BUNDLE_DIR/app"

echo "== 2. copy node runtime =="
cp -a "$STAGE/node" "$BUNDLE_DIR/node"

echo "== 3. copy app (node_modules from linux-x64 resolution) =="
cp -a "$STAGE/app/node_modules" "$BUNDLE_DIR/app/node_modules"
cp "$STAGE/app/package.json" "$BUNDLE_DIR/app/package.json" 2>/dev/null || true

echo "== 4. write bin/dsh wrapper =="
cat > "$BUNDLE_DIR/bin/dsh" <<'EOF'
#!/usr/bin/env bash
# Self-contained dsh launcher: every node run (including child processes via
# process.execPath and by-name lookups) resolves to the bundled runtime;
# bin/ (bundled static bwrap) comes first on PATH for the Linux sandbox.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$ROOT/bin:$ROOT/node/bin:$PATH"
exec "$ROOT/node/bin/node" "$ROOT/app/node_modules/@deepseek-ai/dsh/lib/bin.js" "$@"
EOF
chmod +x "$BUNDLE_DIR/bin/dsh"

echo "== 4b. bundle static bwrap (Rocky 8 zero-install sandbox) =="
if [ -x "$STAGE/bwrap/bwrap" ]; then
  cp "$STAGE/bwrap/bwrap" "$BUNDLE_DIR/bin/bwrap"
  chmod +x "$BUNDLE_DIR/bin/bwrap"
  file "$BUNDLE_DIR/bin/bwrap"
else
  echo "WARN: no static bwrap at $STAGE/bwrap/bwrap — bundle ships without it"
fi

echo "== 4c. bundle check-env.sh (env self-check) =="
if [ -n "${DSH_LINUX_REPO:-}" ] && [ -f "$DSH_LINUX_REPO/scripts/linux-assemble/check-env.sh" ]; then
  cp "$DSH_LINUX_REPO/scripts/linux-assemble/check-env.sh" "$BUNDLE_DIR/bin/check-env.sh"
  chmod +x "$BUNDLE_DIR/bin/check-env.sh"
  echo "check-env.sh bundled"
else
  echo "WARN: DSH_LINUX_REPO unset/missing — bundle ships without check-env.sh"
fi

echo "== 5. smoke: version via wrapper =="
"$BUNDLE_DIR/bin/dsh" --version

echo "== 5b. BUILD-INFO.txt =="
write_build_info "$BUNDLE_DIR" "full (bundled Node.js)" "$("$STAGE/node/bin/node" --version) bundled"

echo "== 6. bundle layout + sizes =="
ls -la "$BUNDLE_DIR"
du -sh "$BUNDLE_DIR" "$BUNDLE_DIR/node" "$BUNDLE_DIR/app/node_modules"

echo "== 7. tar.gz on native fs =="
tar -C "$STAGE/bundle" -czf "$TARBALL" dsh-linux-x64
ls -lh "$TARBALL"

echo "== 8. copy deliverable into dsh-linux/dist/linux =="
mkdir -p "$OUT"
cp "$TARBALL" "$OUT/dsh-linux-x64.tar.gz"
ls -lh "$OUT"

echo "== done. deliverable: $OUT/dsh-linux-x64.tar.gz =="