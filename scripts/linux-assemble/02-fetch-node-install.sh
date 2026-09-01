#!/usr/bin/env bash
# Step 2: fetch Node 22 linux-x64, generate a file:-deps package.json from the
# staged tarballs, and run a full npm install (optional platform deps resolved
# from the registry = the offline bundle's linux-x64 payload).
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
NODE_VER="v22.23.2"
export PATH="$STAGE/node/bin:$PATH"
mkdir -p "$STAGE/app"

if [ "${APP_CLEAN:-0}" = "1" ]; then
  echo "== clean previous app install =="
  rm -rf "$STAGE/app/node_modules" "$STAGE/app/package.json" "$STAGE/app/package-lock.json"
fi

echo "== network check =="
curl -sI --max-time 10 https://registry.npmjs.org/ | head -1
curl -sI --max-time 10 "https://nodejs.org/dist/$NODE_VER/node-$NODE_VER-linux-x64.tar.xz" | head -1

if [ ! -x "$STAGE/node/bin/node" ]; then
  echo "== download node =="
  cd "$STAGE"
  curl -fsSLo node.tar.xz "https://nodejs.org/dist/$NODE_VER/node-$NODE_VER-linux-x64.tar.xz"
  tar -xf node.tar.xz
  mv "node-$NODE_VER-linux-x64" node
  rm node.tar.xz
fi
"$STAGE/node/bin/node" --version
"$STAGE/node/bin/npm" --version

echo "== generate app/package.json (file: deps) =="
"$STAGE/node/bin/node" -e '
const fs=require("fs"), path=require("path"), cp=require("child_process");
const dir=process.argv[1];
const files=fs.readdirSync(dir).filter(f=>f.endsWith(".tgz")).sort();
const deps={};
for(const f of files){
  const full=path.join(dir,f);
  let pkg;
  try { pkg=JSON.parse(cp.execFileSync("tar",["-xOf",full,"package/package.json"],{encoding:"utf8",maxBuffer:16*1024*1024})); }
  catch(e){ console.error("PARSE_FAIL "+f); continue; }
  const name=pkg.name;
  if(!name||!pkg.version){ console.error("NO_NAME_VER "+f); continue; }
  if(deps[name]) console.error("CONFLICT "+name+" already "+deps[name]+" new "+full);
  deps[name]="file:"+full;
}
fs.writeFileSync(process.argv[2], JSON.stringify({name:"dsh-linux-offline",private:true,version:"0.0.0",dependencies:deps},null,2));
console.log("deps="+Object.keys(deps).length);
' "$STAGE/tarballs" "$STAGE/app/package.json"

echo "== npm install (full log -> npm-install.log) =="
cd "$STAGE/app"
"$STAGE/node/bin/npm" install --no-audit --no-fund --no-progress --foreground-scripts > "$STAGE/npm-install.log" 2>&1
echo "npm install exit=$?"
tail -5 "$STAGE/npm-install.log"
echo "== compile audit =="
grep -ciE "node-gyp|gyp ERR|make:|gcc|clang" "$STAGE/npm-install.log" || echo "no compile activity in install log"