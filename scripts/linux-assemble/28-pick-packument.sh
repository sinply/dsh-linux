#!/usr/bin/env bash
N=/home/sinply/dsh-linux-build/node/bin/node
"$N" -e "
(async () => {
  const u='https://registry.npmjs.org/@deepseek-ai%2fdsh-web-frontend';
  const r = await fetch(u, { headers: { accept: 'application/vnd.npm.install-v1+json' } });
  const t = await r.text();
  console.log('status', r.status, 'bytes', t.length);
  try { const p = JSON.parse(t); console.log('parses OK; dist-tags', JSON.stringify(p['dist-tags'] || null)); console.log('versions', Object.keys(p.versions||{}).length); }
  catch (e) { console.log('PARSE FAIL', e.message); console.log(t.slice(0, 200)); }
})().catch(e => console.log('FETCH FAIL', e.message));
"