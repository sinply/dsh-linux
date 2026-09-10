# dsh-linux-x64 — DeepSeek Harness 内网离线 Linux 包

[English README](README.md)

> **声明：** 本发行包为第三方独立构建的 DeepSeek Harness 内网发行物，**与 DeepSeek 无关联、未经其认可，也不代表 DeepSeek 的任何立场**；文中产品名称仅作指称性引用。

自包含（self-contained）版本：**解压即用，目标机无需安装 Node.js / npm，全程离线**。

## 内容

| 组件 | 版本 | 说明 |
|---|---|---|
| Node.js | v22.23.2 (linux-x64) | 官方二进制，glibc ≥ 2.28 |
| dsh CLI | 0.1.5-rc.1 | `@deepseek-ai/dsh` 全量依赖（linux-x64 平台解析），含 web 前端资产 |
| 原生沙箱组件 | `@deepseek-ai/node-addon-system` 0.1.2 | 静态 `landlock-run` launcher + 预编译 Node-API flock addon（glibc/musl 均预置） |
| bubblewrap | 0.11.0（静态 musl） | `bin/bwrap`，Linux 沙箱首选 rung |

## 变体

| 变体 | 包 | 体积 | 适用 |
|---|---|---|---|
| 全包版（本包） | `dsh-linux-x64.tar.gz` | 349 MB | 内网机器无 Node，零安装 |
| 精简版 | `dsh-linux-x64-slim.tar.gz` | 294 MB | 内网已有系统 Node（≥22.19，推荐 24.x；已实测 24.14.0） |
| Basic 全包版 | `dsh-linux-x64-basic.tar.gz` | 252 MB | 无 Node + 只用 API 提供商（砍子代理 CLI 二进制） |
| Basic 精简版 | `dsh-linux-x64-basic-slim.tar.gz` | 198 MB | 有 Node + 只用 API 提供商 |

- **slim 系**：不内置 Node，`bin/dsh` 从 PATH（或 `DSH_NODE_BIN`）解析系统 node，其余与对应全包版一致。
- **basic 系**：移除 Claude Code / Codex 子代理的 CLI 可执行文件（`claude-agent-sdk-linux-x64`、`codex-linux-x64`，合计约 630 MB 解压）；API 提供商、Web 前端、附件、沙箱、OTel 遥测全部保留；若之后需要子代理 CLI，改用 full 系。
- 所有变体切换不影响 `DSH_HOME` 数据。

## 使用

```bash
tar -xzf dsh-linux-x64.tar.gz
cd dsh-linux-x64

cat BUILD-INFO.txt           # 本包对应的 dsh 版本与上游 commit
./bin/dsh --version          # 0.1.5-rc.1
./bin/dsh web                # Web GUI，启动后访问输出里的 http://127.0.0.1:3080/?token=...
./bin/dsh web --no-open      # 不自动打开浏览器（内网/无桌面场景）
DSH_HOME=/your/home ./bin/dsh web   # 指定数据目录（会话、profile 等）；默认 ~/.dsh
```

`bin/dsh` 会把捆绑的 Node（full 系）与 `bin/`（静态 bwrap）加入 PATH 再启动 CLI，子进程（config 子进程、插件等）都走内置运行时。

## 升级注意（从 0.1.2-rc.1 升级必读）

- **会话磁盘格式已升到 V3**（0.1.2-rc.1 为 V0）：用本包首次打开旧 `DSH_HOME` 会做一次性迁移并写入新代际。**升级前请备份 `$DSH_HOME`（默认 `~/.dsh`）；迁移后不要回退到 0.1.2-rc.1**，旧版本读不了迁移后的会话。
- 迁移要求 home 目录可写、磁盘余量充足，且不要让两个 dsh 进程同时打开同一 `DSH_HOME`。
- 默认 Chat Completions 模型改为 **`deepseek-flash`**（`DeepSeek-V41-Flash`）。内网网关若只提供旧模型名，请在 Settings → Providers 里显式配置模型列表。
- `str_replace_editor` 不再由默认 profile 提供，文件编辑使用 `read` / `write` / `edit`。
- 完整清单见随包 `CHANGELOG.zh.md`（仓库：https://github.com/sinply/dsh-linux ）。

## 兼容性（已在构建机实测）

- 目标平台：**Rocky Linux 8 / 9, x86_64**；glibc ≥ 2.28（Rocky 8 = 2.28）。
- 全部原生二进制的 GLIBC 符号审计：node-pty 2.28（踩线）、koffi 2.17、rolldown 2.16、sharp 2.17、lightningcss 2.14、landlock/esbuild 静态 —— 均 ≤ 2.28。
- 安装过程零本地编译（0.1.5 起原生 system 包为**预编译** Node-API addon，构建期也不需要 python/make/g++）。
- 冒烟测试（WSL 构建机，内核 6.6）：landlock launcher 探测 + 约束执行 ✅；bwrap 探测 + 约束执行 ✅；`dsh web` 启动、token URL 跟随重定向返回 200 ✅；四个变体各自启动校验 ✅。

## 沙箱说明（重要，Rocky 8）

Linux 沙箱运行链为 **bwrap（首选，已内置）→ landlock（备用，已内置）**，逐级功能探测，全部不可用则 fail-closed（受沙箱约束的工具拒绝执行，绝不无沙箱放行）。

- **bwrap**：包内已附带**静态编译**的 `bin/bwrap`（bubblewrap 0.11.0，musl 静态链接，无任何系统依赖），**目标机无需安装任何东西**。
  - 个别 RHEL 8 内核默认关闭非特权 user namespace，会让 bwrap 探测失败，启用即可：
    ```bash
    sysctl -w kernel.unprivileged_userns_clone=1
    echo 'kernel.unprivileged_userns_clone=1' >> /etc/sysctl.d/99-dsh.conf
    ```
- **landlock-run / flock**：包内自带 `@deepseek-ai/node-addon-system-linux-x64`
  （`app/node_modules/@deepseek-ai/node-addon-system-linux-x64/bin/landlock-run`，静态 musl；同包内含 `bin/glibc/system.node`）。
  该包为预编译 Node-API addon，无需 node-gyp / Python 编译。Rocky 9（内核 5.14+）直接可用；Rocky 8（4.18）无 Landlock，自动跳过此 rung，走 bwrap。
- 两者都不可用时，仅受沙箱约束的工具报 `SANDBOX_UNAVAILABLE`；Web 启动、会话管理等功能不受影响。
- 会话写入使用 POSIX flock 做跨进程写租约；取不到锁时拒绝写入，不会给出未保护的写路径。

## 内网 LLM 出口

如果内网无法访问外网 API，请在 Web GUI「添加提供商（Add provider）」里配置**自定义 provider**：base URL 指向内网 LLM 网关、协议、凭证与模型列表。仓库文档：`docs/user/guide/providers.md`。

如果内网只能通过代理出网，本版支持 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY`（在启动环境或 `$DSH_HOME/.env` 中设置；项目 `.env` 里设置会被拒绝启动）。注意：OTLP 遥测不走代理，`NO_PROXY` 不支持 CIDR，不支持 SOCKS。

## 目录结构

```
dsh-linux-x64/
├── BUILD-INFO.txt     # 本包版本 / 上游 commit / 运行时 / 构建时间
├── bin/dsh            # 启动器（自包含）
├── bin/check-env.sh   # 环境自检脚本
├── bin/bwrap          # 静态 bubblewrap（沙箱首选）
├── node/              # Node v22.23.2 运行时（slim/basic-slim 无此目录）
└── app/node_modules/  # dsh 全量依赖（linux-x64 平台解析，含 web 前端）
```

## 环境自检（`bin/check-env.sh`）

包内带自检脚本，内网主机跑一下即可定位"连不上网络"到底是哪一层：

```bash
./bin/check-env.sh http://内网网关/v1     # 或先 export DEEPSEEK_BASE_URL / DEEPSEEK_API_KEY
```

自动区分：DNS / 端口 / TLS 证书（内网自签常见）/ base URL 路径 / 凭据。**模型配置页的绿点只代表配置有效，不代表端点可达**；对话连不上时先跑它。

自签证书：`NODE_EXTRA_CA_CERTS=/path/ca.pem ./bin/dsh web`（或测试期 `NODE_TLS_REJECT_UNAUTHORIZED=0`）。

## 构建记录

- 版本来源：源码 `deepseek-harness`（HEAD `2377c272a8` = `dsh-v0.1.5-rc.1`）经 `build:official` + `release:pack` 重新打包。
- 依赖：274 个 tarball（265 dsh + 9 vendor），pnpm 9 安装（linux-x64 glibc 平台过滤 + musl 变体瘦身）；原生沙箱组件 `@deepseek-ai/node-addon-system` 0.1.2 由 registry 解析（预编译 addon）。
- 组装环境：WSL2 Ubuntu 22.04（构建产物均为官方预编译二进制，不依赖构建机 glibc）。
- 可复现流水线与文档：https://github.com/sinply/dsh-linux （一键打包：`powershell -File scripts\build-linux.ps1`）
