# Release notes (dsh-linux offline distribution)

This file records every dsh-linux package release. **The dsh-linux version tracks the upstream dsh version**: `0.1.5-rc.1` means the package bundles upstream dsh `0.1.5-rc.1`.

- Authoritative artifact facts (version, size, SHA-256) live in `dist/linux/build-info.json`; each bundle ships a `BUILD-INFO.txt` naming its dsh version and upstream commit.
- Full upstream commit ranges are cited per release under "Upstream range".

[中文版本：CHANGELOG.zh.md](CHANGELOG.zh.md)

---

## 0.1.5-rc.1 — 2026-09-10

**Upstream range**: `dsh-v0.1.2-rc.1` (`a66e470204`, 2026-09-03) → `dsh-v0.1.5-rc.1` (`2377c272a8`, 2026-09-10): 999 non-merge commits, 6892 files, +209941 / −59902 lines, passing through `0.1.3-alpha.1`, `0.1.3-alpha.2`, `0.1.5-alpha.1`, `0.1.5-alpha.2` (there is no 0.1.4.x).

### Artifacts

| Variant | File | Size | SHA-256 |
|---|---|---|---|
| Full (default) | `dsh-linux-x64.tar.gz` | 349 MB | `dec8e62a92a8d84488c13bf20b7de74af9f67587fa53db5a209e49a339556449` |
| Slim (system Node) | `dsh-linux-x64-slim.tar.gz` | 294 MB | `e6c45c50d9b4ef33cb25f86c9fcdf03ead612895ec920ebee963387151b29e97` |
| Basic (bundled Node) | `dsh-linux-x64-basic.tar.gz` | 252 MB | `4fe52c9b03c04ec07183dcd75254d1f553efca8e5c5b37cd736f5bacc010130b` |
| Basic slim | `dsh-linux-x64-basic-slim.tar.gz` | 198 MB | `4710d2d9f48ae114e0377b3ba3e7a1719ddb9392b859b79facc51619043f311f` |

Built 2026-09-10T09:07:18Z (UTC) from upstream commit `2377c272a8e839e0a84c9f0e623b867a1dce2014`. Hashes are this release's artifacts; `dist/linux/build-info.json` is authoritative and a local rebuild produces different hashes.

### Upgrade notes (read first)

1. **Session on-disk format V0 → V3 (breaking).** `SESSION_FORMAT_VERSION` goes from `0` to `3`. The first launch with this package migrates an existing `DSH_HOME` once (V0→V1→V2→V3) and writes the new generation; already-committed older generations stay byte-identical.
   - **Back up `$DSH_HOME` (default `~/.dsh`) before upgrading.**
   - **Do not roll back to 0.1.2-rc.1 after migrating** — the older version cannot read migrated sessions.
   - The home directory must be writable with enough free space; do not open the same `DSH_HOME` from two dsh processes at once (this release adds a cross-process write lease, but migration still expects exclusive access).
   - Evidence: `f7a6221158`, `e04cfc4c87`, `ee956c720d`, `d1521ea783`; `docs/session-format-status.md` records `latestReleasedVersion: 3` (evidence tag `dsh-v0.1.5-alpha.1`).
2. **Default Chat Completions model is now `deepseek-flash`** (display name `DeepSeek-V41-Flash`), previously `deepseek-v4-flash`. The built-in catalog converges to one default entry (`deepseek-v4-flash` and `deepseek-v4-flash-vision-exp` remain listed, but the default points at `deepseek-flash`).
   - **If your intranet gateway only serves the old model id, configure `models` explicitly under Settings → Providers**, or update the gateway allowlist.
   - Evidence: `bc5fd3b8dc` (PR #3824), `packages/bundle/base/cordis.patch.yml`.
3. **`str_replace_editor` is no longer provided by the default profiles**: file editing uses `read` / `write` / `edit`. Prompts or scripts depending on it must be rewritten, or the package explicitly `insert`ed into a custom composition.
   - Evidence: `36a4665144`, `965adbb5cf`, `63795eaa5c`.
4. **Native sandbox package renamed (bundle layout changed)**: `native/landlock-run` → `native/system`, packages `@deepseek-ai/node-addon-landlock-run*` → **`@deepseek-ai/node-addon-system*`**, with **no root export**: use the `/landlock-run` and `/flock` subpaths. The bundled launcher path becomes
   `app/node_modules/@deepseek-ai/node-addon-system-linux-x64/bin/landlock-run`.
   - Evidence: `336ebb235e`, `7264906f99`, `97e7223d5f`.
5. **Bundled subagent CLIs upgraded**: Codex `0.149.1 → 0.153.4`, Claude Agent SDK `0.3.241 → 0.3.263`. Synchronize any intranet version pinning.
   - Evidence: `ace0c4619e` (PR #3787).
6. **Do not expect**: same-session message editing was reverted upstream before 0.1.5-rc.1 (`e974a655a0`, PR #3459) and is not in this release; fenced-diagram preview covers Mermaid only (Graphviz / SVG / HTML previews were reverted with PR #3901).

### New capabilities

- **Web GUI**: sidebar rebuilt as a dockable multi-tab workspace; file tree tab; file previews (images, paged text that keeps reading position, document preview, Mermaid diagrams); file-type icons; immutable deliverable cards with download and native file actions; open the workspace in local apps from the web UI (PR #3409); connection recovery with configurable backoff (`ConnectionRecoveryConfig`).
- **Tools**: bounded byte-range file reads (paged reads of large files); deliverable semantics split into "file changed" vs "explicitly presented" (new `tool-present`); `read_image` rendering in tool cards.
- **Network / proxy**: `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY` now actually apply (Node's `fetch` ignored them before), covering model requests, web search, `web_fetch`, and MCP over HTTP; new user doc `docs/user/guide/network-proxy.md`. **Limits**: OTLP telemetry does not use the proxy; workflow workers do not inherit proxy variables; a project `.env` may not set proxy variables; `NO_PROXY` has no CIDR support; SOCKS is unsupported.
- **Subagents / workflows**: a parent session records and observes the child catalogs it owns; Agent Teams packages publish as public experimental; workflow messages always steer; subagent human-inbox controls aligned.
- **MCP**: repeated tool-discovery cursors are rejected, preventing pagination cycles (PR #3846).
- **Skills**: skill candidates ranked by the shared fuzzy name ranker; skills can record browser GIFs via Playwright.
- **Settings**: custom provider base URLs are validated and normalized; plugin instances are distinguishable; a broken model catalog no longer blocks startup.
- **Performance**: streaming session open/migration plus large-session benchmarks.

### Sandbox and intranet notes

- **Build side**: the native package is now a **prebuilt Node-API addon** (`bin/glibc/system.node`, `bin/musl/system.node`) plus a static `bin/landlock-run`; no python/make/g++ is needed to compile it.
- **Runtime side**: the Linux sandbox chain is unchanged — **bundled static bwrap (preferred) → landlock-run (fallback)**, probed per rung, fail-closed when neither works. The bundled bwrap is the same statically linked bubblewrap 0.11.0.
- **New flock write lock**: cross-process session write ownership is arbitrated with POSIX flock; when the lock is unavailable the acquisition is refused rather than left unprotected.
- **Telemetry / privacy (evaluate)**: explicit feedback (`/feedback`, Dislike) is uploaded by default for all users and providers, capturing the full unprocessed context from seq 0 up to that feedback (which can include inherited history). Mount `session-telemetry-otel` accordingly if your intranet forbids egress. Evidence: `9ffe85a512` (PR #3598).
- Native subprocess containment was hardened (escaped-descendant containment, cancellation settlement); Windows-only window-hiding fixes do not affect this Linux package.

### Packaging changes (this repository)

- New **one-shot packaging**: `scripts/build-linux.ps1` (Windows orchestrator: preflight, upstream build, repack, WSL assembly, delivery, checksums) and `scripts/linux-assemble/build-all.sh` (WSL driver: stepwise pipeline, per-step logs, fail-fast).
- **Platform pruning (`35-platform-prune.sh`) is now part of the pipeline** — it drops musl / non-linux-x64 binding variants (~340 MB) and previously had to be run by hand.
- **Version traceability**: every bundle carries `BUILD-INFO.txt` (dsh version, upstream commit/tag, runtime, build time); `dist/linux/build-info.json` lists version, size, and SHA-256 of every artifact.
- `04-assemble.sh` no longer bakes in a machine path (`STAGE_DIR` is honored); `22-re-extract.sh` accepts `OUT_DIR` / `VARIANTS`; the landlock staging input in `01-stage.sh` is optional (from 0.1.5 the native package resolves from the registry).
- The scripts tolerate the native package rename: the landlock launcher is resolved by file name, so `check-env.sh` and `06-smoke.sh` work with both package layouts.

### Verification

Measured on the WSL2 Ubuntu 22.04 build host (kernel 6.6):

- **All four variants report `0.1.5-rc.1`** from `bin/dsh --version`; each extracted bundle carries `check-env.sh` and `BUILD-INFO.txt`.
- **GLIBC symbol audit** (Rocky 8 floor 2.28): node-pty **2.28** (at the floor), koffi 2.17, sharp 2.17, rolldown 2.16, lightningcss 2.14, `node-addon-require-builtin` 2.14, `node-addon-system`'s `bin/glibc/system.node` 2.4; landlock-run and esbuild are static/no glibc symbols — all ≤ 2.28.
- **No local compilation**: the install log contains zero `node-gyp rebuild` / `gyp ERR` hits; every native dependency is an official prebuilt artifact (since 0.1.5 `@deepseek-ai/node-addon-system` is a prebuilt Node-API addon too).
- **Both sandbox rungs**: bundled static `bin/bwrap` probe + confined run pass ✅; `landlock-run` (`@deepseek-ai/node-addon-system-linux-x64@0.1.2`) probe + confined run pass ✅ (the WSL kernel reports `partially enforced (older ABI)`; Rocky 9 enforces fully).
- **Web boot**: each of the four variants started `dsh web` and its token URL returned **HTTP 200** after redirects ✅.
- **Artifact integrity**: all four tarballs were re-extracted and verified, with the correct variant marker in each `BUILD-INFO.txt` (full / slim / basic / basic-slim).

### Known limitations

- `basic` / `basic-slim` omit the Claude Code and Codex subagent CLI executables (platform binary packages only; JS wrappers and plugins stay). Use `full` / `slim` when those subagents are needed.
- The slim variants require a system Node ≥ 22.19 (24.x LTS recommended, verified on 24.14.0); `full` and `basic` bundle Node v22.23.2.
- OTLP telemetry bypasses the proxy; `NO_PROXY` has no CIDR support; SOCKS is unsupported.
- Rocky 8 (kernel 4.18) has no Landlock and uses bwrap; some kernels disable unprivileged user namespaces, requiring `sysctl -w kernel.unprivileged_userns_clone=1`.
