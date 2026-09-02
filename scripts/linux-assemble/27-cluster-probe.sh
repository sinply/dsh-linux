#!/usr/bin/env bash
# Find which alpha.4 tarball declares the "fatal cluster" deps (undici/octokit/open/turndown).
N=/home/sinply/dsh-linux-build/node/bin/node
T=/home/sinply/dsh-linux-build/tarballs
echo "=== packages declaring undici / @octokit/webhooks ==="
for f in "$T"/*.tgz; do
  deps=$(tar -xOf "$f" package/package.json 2>/dev/null | "$N" -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{const p=JSON.parse(s);const d={...(p.dependencies||{}),...(p.optionalDependencies||{})};const hit=Object.keys(d).filter(k=>/undici|octokit\/webhooks|^open$|turndown/.test(k));if(hit.length)console.log(require("path").basename(process.argv[1])+" -> "+hit.join(","))}catch(e){}})' "$f")
  [ -n "$deps" ] && echo "$deps"
done 2>/dev/null | head -10
echo "=== registry sanity: @octokit/webhooks@14.2.0 deps ==="
"$N" -e "fetch('https://registry.npmjs.org/@octokit/webhooks/14.2.0').then(r=>r.json()).then(p=>console.log('ok deps:',JSON.stringify(p.dependencies||{}))).catch(e=>console.log('FETCH FAIL',e.message))"