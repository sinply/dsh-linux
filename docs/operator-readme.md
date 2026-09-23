# dsh-linux-x64 — DeepSeek Harness offline Linux distro

[中文版 README.zh.md](README.zh.md)

> **Disclaimer:** This package is an independent, third-party maintained build of DeepSeek Harness for intranet deployment.
> It is **not affiliated with, endorsed by, or representative of DeepSeek**; product names appear for identification only.

Self-contained build of DeepSeek Harness for **Rocky Linux 8 / 9 (x86_64)**, glibc ≥ 2.28. **Extract and run — no Node.js / npm / system dependencies, fully offline** (static bwrap sandbox bundled).

## Contents

| Component | Version | Notes |
|---|---|---|
| Node.js | v22.23.2 (linux-x64) | Official binary, glibc ≥ 2.28 |
| dsh CLI | 0.1.7-rc.1 | all `@deepseek-ai/dsh` dependencies (linux-x64 resolution) incl. Web frontend |
| Native sandbox | `@deepseek-ai/node-addon-system` 0.1.2 | static `landlock-run` launcher + prebuilt Node-API flock addon (glibc and musl) |
| bubblewrap | 0.11.0 (static musl) | `bin/bwrap`, preferred Linux sandbox rung |

## Variants

| Variant | Package | Size | When to use |
|---|---|---|---|
| Full (this package) | `dsh-linux-x64.tar.gz` | 440 MB | Intranet hosts without Node: bundled runtime, zero install |
| Slim | `dsh-linux-x64-slim.tar.gz` | 386 MB | Hosts already run system Node (>= 22.19, 24.x LTS recommended; verified 24.14.0) |
| Basic | `dsh-linux-x64-basic.tar.gz` | 343 MB | No Node + API providers only (subagent CLI binaries pruned) |
| Basic slim | `dsh-linux-x64-basic-slim.tar.gz` | 288 MB | System Node + API providers only |

- **Slim**: no bundled Node; `bin/dsh` resolves system node from PATH (or `DSH_NODE_BIN`).
- **Basic**: prunes the Claude Code / Codex subagent CLI executables (~630 MB extracted); API providers, Web frontend, attachments, sandbox, OTel telemetry kept. Switch back to Full if you need those CLIs.
- Variant switches do not affect `DSH_HOME` data.

## Usage

```bash
tar -xzf dsh-linux-x64.tar.gz
cd dsh-linux-x64

cat BUILD-INFO.txt           # dsh version and upstream commit of this package
./bin/dsh --version          # 0.1.7-rc.1
./bin/dsh web                # Web GUI: open http://127.0.0.1:3080/?token=... printed at startup
./bin/dsh web --no-open      # headless / intranet: do not open a browser
DSH_HOME=/your/home ./bin/dsh web   # custom data dir (sessions, profiles); default ~/.dsh
```

`bin/dsh` puts the bundled node (full variants) and `bin/` (static bwrap) on PATH; all child processes use the bundled runtime.

## Upgrade notes (from 0.1.5-rc.1)

- **The session on-disk format is now V4** (0.1.5-rc.1 was V3): the first launch with this package migrates an existing `DSH_HOME` once and writes the new generation. **Back up `$DSH_HOME` (default `~/.dsh`) first, and do not roll back to 0.1.5-rc.1 afterwards** — the repository ships no V4→V3 reverse migration, and the older version cannot read migrated sessions.
- **`$DSH_HOME/settings.yaml` is imported once and renamed to `settings.yaml.imported`**; sections rejected by the current composition survive only in the renamed file. Back that file up too.
- Presets became declarative profile patches: the old `roots` / `includeShippedRoot` / `includeUserRoot` / `USER_PRESET_DIR` and user preset directories are no longer read.
- Config key `spill-policy.maxInlineBytes` → `maxInlineTokens`; `tool-ralph` is disabled by default.
- The default model id is still `deepseek-flash` (displayed as `DeepSeek-V41-Flash`; the catalog now also lists `deepseek-v4-pro`).
- Full list: `CHANGELOG.md` (repo: https://github.com/sinply/dsh-linux ).

## Compatibility (verified on the build host)

- **Rocky Linux 8 / 9, x86_64**; glibc ≥ 2.28 (Rocky 8 = 2.28).
- GLIBC symbol audit of the native binaries: node-pty 2.28 (at the floor), koffi 2.17, sharp 2.17, rolldown 2.16, lightningcss 2.14, `node-addon-require-builtin` 2.14, landlock/esbuild static — all ≤ 2.28.
- **Exception (new in 0.1.7-rc.1)**: three native addons of experimental capabilities need a newer glibc and **cannot load on Rocky 8**: `sherpa-onnx` (speech-to-text) 2.32, `@trycua/cua-driver` (computer-use) 2.30, `@ubjs/node` (browser-use) 2.30. None is in the default profiles, so **default functionality (Web GUI, sessions, sandbox, model requests) is unaffected**; Rocky 9 (glibc ≥ 2.34) is unaffected.
- Zero compile anywhere: the native sandbox package is a **prebuilt** Node-API addon, so neither the build host nor the target needs python/make/g++.
- Smoke tests passed (WSL build host, kernel 6.6): landlock probe + confined run ✅; bwrap probe + confined run ✅; `dsh web` boot, token URL follows redirects to 200 ✅; all four variants boot ✅.

## Sandbox (important on Rocky 8)

Linux sandbox chain: **bwrap (first, bundled) → landlock (fallback, bundled)**, functionally probed in order, fail-closed when both are unavailable (sandboxed tools refuse to run; never unconfined passthrough).

- **bwrap**: statically compiled, bundled as `bin/bwrap` (bubblewrap 0.11.0, musl static — no system dependency).
  - If a hardened RHEL 8 kernel disabled unprivileged user namespaces, enable it:
    ```bash
    sysctl -w kernel.unprivileged_userns_clone=1
    echo 'kernel.unprivileged_userns_clone=1' >> /etc/sysctl.d/99-dsh.conf
    ```
- **landlock-run / flock**: bundled as `@deepseek-ai/node-addon-system-linux-x64`
  (`app/node_modules/@deepseek-ai/node-addon-system-linux-x64/bin/landlock-run`, static musl, plus `bin/glibc/system.node`). It is a prebuilt Node-API addon — no node-gyp / Python. Rocky 9 (kernel 5.14+) works directly; Rocky 8 (4.18) skips it and uses bwrap.
- When both are unavailable, only sandbox-confined tools report `SANDBOX_UNAVAILABLE`; web boot and session management are unaffected.
- Session writes use a POSIX flock cross-process write lease; when the lock cannot be taken the write is refused rather than left unprotected.

## Intranet LLM endpoint

If the intranet cannot reach public APIs, add a **custom provider** in the Web GUI (Settings → Providers → Add custom provider): point base URL at your intranet LLM gateway, set protocol, credentials and model list. See upstream `docs/user/guide/providers.md` (deepseek-harness).

If the intranet only reaches the outside through a proxy, this release honors `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY` (set them in the launch environment or `$DSH_HOME/.env`; setting them in a project `.env` refuses startup). Note: OTLP telemetry does not use the proxy, `NO_PROXY` has no CIDR support, and SOCKS is unsupported.

## Layout

```
dsh-linux-x64/
├── BUILD-INFO.txt     # dsh version / upstream commit / runtime / build time
├── bin/dsh            # self-contained launcher
├── bin/check-env.sh   # environment self-check (see below)
├── bin/bwrap          # static bubblewrap (Linux sandbox, first rung)
├── node/              # Node v22.23.2 runtime (absent in slim/basic-slim)
└── app/node_modules/  # all deps (linux-x64 resolution, incl. Web frontend)
```

## Environment self-check (`bin/check-env.sh`)

Run it on the host to locate "cannot connect" issues layer by layer:

```bash
./bin/check-env.sh http://intranet-gateway/v1    # or export DEEPSEEK_BASE_URL / DEEPSEEK_API_KEY first
```

It distinguishes DNS / port / TLS certificate (common for intranet self-signed) / base-URL path / credentials. Note: a **green dot in the model config means the config is valid — not that the endpoint is reachable**. For self-signed certs: `NODE_EXTRA_CA_CERTS=/path/ca.pem ./bin/dsh web` (or test-only `NODE_TLS_REJECT_UNAUTHORIZED=0`).

## Build record

Built from the dsh source checkout (HEAD `46a7f68b09` = `dsh-v0.1.7-rc.1`, clean tracked tree) via `build:official` + `release:pack`: 318 tarballs (309 dsh + 9 vendor); pnpm 9 install (linux-x64 glibc platform filter + musl-variant prune); the native sandbox package `@deepseek-ai/node-addon-system` 0.1.2 resolves from the registry (prebuilt addon). Assembled on WSL2 Ubuntu 22.04 (all artifacts are official prebuilt binaries, independent of the builder glibc). Reproducible pipeline + docs: https://github.com/sinply/dsh-linux (one-shot packaging: `powershell -File scripts\build-linux.ps1`).
