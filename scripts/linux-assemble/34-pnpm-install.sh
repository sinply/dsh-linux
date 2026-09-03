#!/usr/bin/env bash
# Install the staged tarballs with pnpm 9 (npm 10.9.8 crashes on the
# @openai/codex 4246-version packument). Platform-filtered to linux-x64 glibc.
# Cleans a previous install first (re-runnable for version changes).
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
export PATH="$STAGE/node/bin:$PATH"
cd "$STAGE/app"

echo "== clean previous install =="
rm -rf node_modules package-lock.json .pnpm-store 2>/dev/null || true

echo "== package.json (file: deps) =="
node -e '
const fs=require("fs"), path=require("path"), cp=require("child_process");
const dir=process.argv[1];
const files=fs.readdirSync(dir).filter(f=>f.endsWith(".tgz")).sort();
const deps={};
for(const f of files){
  const full=path.join(dir,f);
  try { const p=JSON.parse(cp.execFileSync("tar",["-xOf",full,"package/package.json"],{encoding:"utf8",maxBuffer:32*1024*1024})); deps[p.name]="file:"+full; }
  catch(e){ console.error("PARSE_FAIL "+f); }
}
// pnpm resolves transitive @deepseek-ai/* ranges against the npm registry,
// which 404s for unpublished family members (e.g. dsh-http-proxy). Override
// every @deepseek-ai dep to the local tarball so resolution never leaves the
// stage.
const overrides={};
for (const [name,spec] of Object.entries(deps)) if (name.startsWith("@deepseek-ai/")) overrides[name]=spec;
fs.writeFileSync(process.argv[2], JSON.stringify({name:"dsh-linux-offline",private:true,version:"0.0.0",dependencies:deps,pnpm:{overrides}},null,2));
console.log("deps="+Object.keys(deps).length+" overrides="+Object.keys(overrides).length);
' "$STAGE/tarballs" "$STAGE/app/package.json"

echo "== .npmrc (linux x64 glibc only) =="
cat > "$STAGE/app/.npmrc" <<'EOF'
supportedArchitectures.os=linux
supportedArchitectures.cpu=x64
supportedArchitectures.libc=glibc
EOF

echo "== pnpm install =="
rm -rf node_modules package-lock.json
npx -y pnpm@9.15.0 install --no-frozen-lockfile > "$STAGE/pnpm-install.log" 2>&1
echo "pnpm exit=$?"

echo "== verify =="
"$STAGE/node/bin/node" node_modules/@deepseek-ai/dsh/lib/bin.js --version
echo "-- landlock --"
find node_modules -name landlock-run -type f | head -1
echo "-- koffi --"
find node_modules -name 'koffi*.node' | head -2
echo "-- compile audit in log --"
grep -ciE 'node-gyp rebuild|gyp ERR' "$STAGE/pnpm-install.log" || echo "none"
tail -6 "$STAGE/pnpm-install.log"