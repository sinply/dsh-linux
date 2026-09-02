#!/usr/bin/env bash
export PATH=/home/sinply/dsh-linux-build/node/bin:$PATH
T=/home/sinply/dsh-linux-build/tarballs
D=/home/sinply/dsh-linux-build/install-fresh
rm -rf "$D" && mkdir -p "$D"
cd "$D" || exit 2
# regenerate the same file: deps package.json (reuse the generator logic)
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
fs.writeFileSync(process.argv[2], JSON.stringify({name:"dsh-linux-offline",private:true,version:"0.0.0",dependencies:deps},null,2));
console.log("deps="+Object.keys(deps).length);
' "$T" "$D/package.json"
date +%H:%M:%S.start
npm install --no-audit --no-fund --no-progress --foreground-scripts > "$D/install.log" 2>&1
echo "NPM_EXIT=$?"
date +%H:%M:%S.end
tail -5 "$D/install.log"