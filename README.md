# dsh-linux

[中文简体](README.zh.md)

> **Disclaimer:** This repository is an independent, third-party maintained packaging and operations project built on the public
> [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness). It is **not affiliated with, endorsed by, or representative of DeepSeek**;
> the product names and trademarks that appear are referenced for identification only.

An **offline, self-contained Linux distribution of DeepSeek Harness** for intranet deployment. The dsh CLI, Node.js runtime, all dependencies, the Web frontend, and the sandbox components (landlock-run + static bwrap) are packed into a single directory: **extract and run — zero installation, fully air-gapped**.

- Artifact: `dsh-linux-x64.tar.gz` (~358 MB; ~1.3 GB extracted)
- Target platform: **Rocky Linux 8 / 9 (x86_64)**, glibc ≥ 2.28
- Upstream: dsh = [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) (MIT); landlock-run uses the upstream per-platform prebuilt packages (static musl)

## Quick start (intranet target host)

```bash
tar -xzf dsh-linux-x64.tar.gz
cd dsh-linux-x64
./bin/dsh --version        # 0.1.2-alpha.3
./bin/dsh web              # Web GUI: open http://127.0.0.1:3080/?token=... printed at startup
./bin/dsh web --no-open    # headless / intranet: do not try to open a browser
```

No Node.js / npm / other system dependencies are required. Sandbox components are bundled: Linux prefers the bundled static `bin/bwrap`; landlock-run is the fallback rung.

> Some hardened RHEL 8 kernels disable unprivileged user namespaces, which makes the bwrap probe fail. Enable it with:
> `sysctl -w kernel.unprivileged_userns_clone=1` (see [docs/usage.md](docs/usage.md#沙箱)).

## Distribution variants

| Variant | Package | When to use | Size (measured) |
|---|---|---|---|
| Full (default) | `dsh-linux-x64.tar.gz` | Intranet hosts **without** Node: bundled runtime, zero install | ~358 MB |
| Slim (system Node) | `dsh-linux-x64-slim.tar.gz` | Intranet already runs Node (>= 22.19, 24.x LTS recommended; verified on 24.14.0) | ~303 MB |
| Basic (bundled Node) | `dsh-linux-x64-basic.tar.gz` | No Node + API providers only (subagent CLI binaries pruned) | ~130 MB |
| Basic slim | `dsh-linux-x64-basic-slim.tar.gz` | System Node + API providers only | **~75 MB** |

- **Slim**: no bundled Node; `bin/dsh` resolves the system node from PATH (or the `DSH_NODE_BIN` env var). Everything else matches the corresponding full variant.
- **Basic**: prunes the Claude Code / Codex subagent **CLI executables** (`claude-agent-sdk-linux-x64`, `codex-linux-x64`, ~630 MB extracted; only needed when actually spawning those CLIs, and their plugins are not wired into the default web profile). API providers, Web frontend, attachments, sandbox and OTel telemetry are all kept.
- Switching variants (incl. basic ↔ full) does not affect `DSH_HOME` data.

The **full** variant is the default: bundled Node runtime and every feature, zero-install on any intranet host; pick a smaller one from the table when size matters.

## Documentation

The detailed operator and build docs are in Chinese:

- [Operator guide docs/usage.md](docs/usage.md) — deployment, configuration, troubleshooting, intranet LLM gateway
- [Build guide docs/build.md](docs/build.md) — rebuilding this distribution from dsh source

## Companion

- [dsh-vscode](https://github.com/sinply/dsh-vscode) — VS Code extension to launch/manage the dsh Web GUI; shipped as an offline `.vsix` for intranet install.

## Repository layout

```
dsh-linux/
├── README.md              # English
├── README.zh.md           # 中文
├── docs/                  # usage + build docs (Chinese)
├── scripts/linux-assemble/  # reproducible build pipeline (01–11)
└── dist/linux/            # artifact output (git-ignored)
```

`dist/` artifacts are not committed (the tarball is ~360 MB and a build result, not source); ship them via your intranet file transfer / release channel.

## License

BSD 3-Clause. Upstream dsh is copyrighted by DeepSeek; this repository is an independent packaging and operations project (see [LICENSE](LICENSE)).