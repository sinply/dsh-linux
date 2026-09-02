#!/usr/bin/env bash
N=/home/sinply/dsh-linux-build/node/bin/node
"$N" -e '
(async () => {
  const targets = [
    "@openai/codex",
    "@deepseek-ai/dsh-web-frontend",
    "@anthropic-ai/claude-agent-sdk",
    "@deepseek-ai/dsh-subagent-codex",
    "@deepseek-ai/dsh",
  ];
  for (const name of targets) {
    const u = "https://registry.npmjs.org/" + encodeURIComponent(name);
    try {
      const t0 = Date.now();
      const r = await fetch(u, { headers: { accept: "application/vnd.npm.install-v1+json" } });
      const t = await r.text();
      const ms = Date.now() - t0;
      let ok = true, ver = 0;
      try { const p = JSON.parse(t); ver = Object.keys(p.versions || {}).length; } catch { ok = false; }
      console.log(`${name}: status=${r.status} bytes=${t.length} parse=${ok} versions=${ver} ${ms}ms`);
    } catch (e) { console.log(`${name}: FETCH FAIL ${e.message}`); }
  }
})();
'