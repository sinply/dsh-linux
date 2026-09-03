# dsh-linux

[English](README.md)

> **声明：** 本仓库为第三方独立维护的打包与运维工程，基于公开的
> [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 构建，**与 DeepSeek 无关联、未经其认可，也不代表 DeepSeek 的任何立场**；
> 文中出现的产品名称与商标仅作指称性引用。

DeepSeek Harness 的 **内网离线 Linux 发行包**：把 dsh CLI、Node.js 运行时、全部依赖、Web 前端与沙箱组件（landlock-run + 静态 bwrap）打包成一个自包含目录，目标机 **解压即用、全程离线、零安装**。

- 产物：`dsh-linux-x64.tar.gz`（约 358 MB，解压后约 1.3 GB）
- 目标平台：Rocky Linux 8 / 9（x86_64），glibc ≥ 2.28
- 上游：dsh = [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)（MIT）；landlock-run 使用上游发布的平台预编译包（静态 musl）

## 快速开始（内网目标机）

```bash
tar -xzf dsh-linux-x64.tar.gz
cd dsh-linux-x64
./bin/dsh --version        # 0.1.2-rc.1
./bin/dsh web              # Web GUI：访问启动输出里的 http://127.0.0.1:3080/?token=...
./bin/dsh web --no-open    # 无桌面/内网场景：不尝试自动打开浏览器
```

无需安装 Node.js / npm / 其他系统依赖。沙箱组件已内置：Linux 优先走包内静态 `bin/bwrap`；landlock-run 为备用 rung。

> 个别 RHEL 8 内核默认关闭非特权 user namespace，会让 bwrap 探测失败。此时启用即可：
> `sysctl -w kernel.unprivileged_userns_clone=1`（详见 [docs/usage.md](docs/usage.md#沙箱)）。

## 发行变体

| 变体 | 安装包 | 适用条件 | 体积（实测） |
|---|---|---|---|
| 全包版（默认） | `dsh-linux-x64.tar.gz` | 内网机器**没有** Node：自带运行时，零安装 | ~354 MB |
| 精简版（系统 Node） | `dsh-linux-x64-slim.tar.gz` | 内网机器**已有** Node（≥ 22.19，推荐 24.x LTS；已实测 24.14.0） | ~299 MB |
| Basic 全包版 | `dsh-linux-x64-basic.tar.gz` | 无 Node + 只用 API 提供商（砍子代理 CLI 二进制） | ~249 MB |
| Basic 精简版 | `dsh-linux-x64-basic-slim.tar.gz` | 有 Node + 只用 API 提供商 | **~195 MB** |

- **slim 系**：不内置 Node，`bin/dsh` 从 PATH（或 `DSH_NODE_BIN`）解析系统 node；其余与对应全包版一致。
- **basic 系**：裁剪了 Claude Code / Codex 子代理的 CLI 可执行文件（`claude-agent-sdk-linux-x64`、`codex-linux-x64`，合计约 630 MB 解压；仅实际唤起对应 CLI 时才需要，且插件不在默认 web profile 中）。API 提供商、Web 前端、附件、沙箱、OTel 遥测全部保留。
- 切换变体（含 basic ↔ full）不影响 `DSH_HOME` 数据。

默认**全包版**：自带 Node.js 运行时与全部功能，任何内网机器零安装即可用；需要更小时按上表选择。

## 文档

- [使用指南 docs/usage.md](docs/usage.md) —— 部署、配置、故障排查、内网 LLM 网关接入
- [构建指南 docs/build.md](docs/build.md) —— 如何从 dsh 源码重新构建本发行包

## 配套

- [dsh-vscode](https://github.com/sinply/dsh-vscode) —— 在 VS Code 中启动/管理 dsh Web GUI 的插件，以离线 `.vsix` 形式内网安装。

## 仓库结构

```
dsh-linux/
├── README.md              # English
├── README.zh.md           # 中文
├── docs/                  # 使用 + 构建文档
├── scripts/linux-assemble/  # 可复现构建脚本（01–11）
└── dist/linux/            # 产物出口（git 忽略，不入库）
```

`dist/` 产物不入库（tar.gz 近 360 MB，且是构建结果而非源码）；发布物通过内网文件传输或其他发布渠道分发。

## License

BSD 3-Clause。上游 dsh 版权归 DeepSeek；本仓库为独立打包与运维工程（协议与署名详见 [LICENSE](LICENSE)）。