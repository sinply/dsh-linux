# 构建指南（从 dsh 源码构建本 Linux 发行包）

本文给维护者/构建者：如何从一个 deepseek-harness 源码检出，再产出 `dsh-linux-x64.tar.gz`。

## 1. 产物构成与原理

自包含目录 = **Node.js 运行时 + dsh 全量依赖 + Web 前端 + 沙箱组件**，目标机零安装：

| 组件 | 来源 |
|---|---|
| Node.js v22 linux-x64 | nodejs.org 官方二进制（glibc ≥ 2.28 底线） |
| dsh 各包 + Web 前端 | `build:official` + `release:pack` 打的 tarball |
| 平台可选依赖（koffi / esbuild / rolldown / node-pty / typert 等） | npm registry 的 linux-x64 预编译包，安装时按平台解析 |
| landlock-run | 上游发布的平台预编译包（静态 musl，glibc 无关） |
| bwrap | 本仓库脚本静态编译（musl + 静态 libcap），见 `09-build-bwrap.sh` |

**为什么在 Ubuntu（glibc 2.35）上组装也能跑 Rocky 8（glibc 2.28）**：全部二进制都是官方预编译产物（各自的 glibc 底线 ≤ 2.28），组装过程不做任何本地编译。装完后用 `objdump -T` 对各原生二进制做 GLIBC 符号审计（`05-glibc-audit.sh`），实测各上限：node-pty 2.28、koffi 2.17、rolldown 2.16、sharp 2.17、lightningcss 2.14、landlock/esbuild 静态。

## 2. 前置条件（构建机）

- **Windows + WSL2**（本仓库脚本在 WSL 里组装，获得真实的 linux-x64 平台解析）
- deepseek-harness 源码检出（含 `pnpm`、`node ^22.19 || >=24`）
- 网络：仅构建时需要（nodejs.org、registry.npmjs.org、GitHub）；目标机不需要

## 3. 流水线

### 3.0 一键打包（推荐）

```powershell
# 在 dsh-linux 仓库根目录执行；默认：自动找同级 ../deepseek-harness
# Windows PowerShell 5.1 与 PowerShell 7 (pwsh) 均可运行
powershell -File scripts\build-linux.ps1

# 只重跑 WSL 组装（复用上次的 tarball 与已安装依赖）
powershell -File scripts\build-linux.ps1 -SkipHarnessBuild -SkipRepack -ReuseStage

# 复用已构建的上游产物，只重新打 tarball + 组装
powershell -File scripts\build-linux.ps1 -SkipHarnessBuild

# 只出 full + slim，构建机只做完整校验
powershell -File scripts\build-linux.ps1 -Variants full,slim

# 先看要做什么，不执行
powershell -File scripts\build-linux.ps1 -DryRun
```

`scripts/build-linux.ps1` 是 Windows 侧的一次性编排器，按阶段执行并逐步可跳过：

| 阶段 | 动作 |
|---|---|
| 1 预检 | 解析路径、记录版本/上游 commit、探测 WSL 发行版 |
| 2 上游构建 | `pnpm install --frozen-lockfile` → `pnpm run clean` → `pnpm run build:official` |
| 3 重打包 | `07-repack.ps1` → `<harness>/dist/npm-<suffix>`、`dist/npm-vendor-<suffix>` |
| 4 组装 | WSL 内运行 `scripts/linux-assemble/build-all.sh`（安装、瘦身、校验、四个变体、冒烟） |
| 5 交付 | 复制 operator README 到 `dist/linux/`、写 `dist/linux/build-info.json`（版本 + sha256） |

常用参数：`-HarnessRoot`、`-Version`、`-Suffix`、`-Variants`、`-Distro`、`-StageDir`、`-SystemNode`、`-LandlockTgzSrc`、`-SkipInstall`、`-SkipHarnessBuild`、`-SkipRepack`、`-ReuseStage`、`-SkipSmoke`、`-Extract`、`-SkipHash`、`-DryRun`（详见脚本头注释与 `Get-Help .\scripts\build-linux.ps1`）。

产物根目录会多出两个文件：

- `BUILD-INFO.txt`（打进每个 bundle）：该包对应的 dsh 版本、上游 commit、运行时与构建时间；运维不必解压即可确认版本。
- `dist/linux/build-info.json`：本次全部产物的版本、大小与 SHA-256，便于内网分发校验。

只装了 Linux 构建机（无 Windows）时，可直接在 Linux/WSL 内跑同一套流程的组装段：

```bash
OUT_DIR=/path/to/dsh-linux/dist/linux \
DSH_TGZ_SRC=<harness>/dist/npm-<suffix> \
VENDOR_TGZ_SRC=<harness>/dist/npm-vendor-<suffix> \
VARIANTS="full slim basic basic-slim" \
bash scripts/linux-assemble/build-all.sh
# 只有重建 dsh <= 0.1.2 时才额外给 LANDLOCK_TGZ_SRC=<harness>/dist/npm-landlock
```

### 3.1 打 tarball（Windows 侧）

```powershell
# 官方 profile 构建（host + client + web 前端）
pnpm run build:official

# 重打包（输出 dist/npm-<suffix>、dist/npm-vendor-<suffix>；suffix 默认 a3）
$env:HARNESS_ROOT = "<deepseek-harness 检出路径>"
& scripts/linux-assemble/07-repack.ps1
```

> `07-repack.ps1` 通过环境变量取路径（`HARNESS_ROOT`、可选 `PNPM_CMD`/`OUT_SUFFIX`），仓库内不固化任何本机路径。

**目录约定与清理**：

- 每次打包写入 `dist/npm-<suffix>` / `dist/npm-vendor-<suffix>`，**不覆盖旧版本目录**；`07-repack.ps1` 会在打包前自动删除除"本次输出 + `npm-landlock`"以外的全部 `dist/npm*` 目录，旧版本产物无需手动清理。
- `dist/npm-landlock`（landlock entry 0.1.1）只与 **dsh ≤ 0.1.2** 的重建有关：0.1.5 起原生沙箱组件改为 `@deepseek-ai/node-addon-system`（预编译 Node-API addon），不在这条 family 里，安装时由 registry 解析，因此**默认不再作为输入**（需要时显式传 `-LandlockTgzSrc <harness>/dist/npm-landlock` 或 `LANDLOCK_TGZ_SRC=…`）。把它当作默认输入会让包里多出一个 0.1.5 已不使用的旧包，并可能让自检脚本命中旧的 launcher。

### 3.2 WSL 组装（每步一个脚本，环境变量驱动）

> **安装器选择（0.1.2-rc.1 起）**：npm 10 解析 `@openai/codex`（registry 上 4246 个版本、3.8MB 巨型 packument）时会无报错崩溃，因此 alpha.4 起改用 **pnpm 9** 安装（脚本 `34-pnpm-install.sh`，含 `supportedArchitectures` 平台过滤）。npm 方案（`02`）保留给更早版本。

```bash
# 环境变量速查
STAGE_DIR=~/dsh-linux-build        # 组装暂存（默认 $HOME/dsh-linux-build）
DSH_TGZ_SRC=…                      # 01: dsh 家族 tarball 目录
VENDOR_TGZ_SRC=…                   # 01: vendor tarball 目录
LANDLOCK_TGZ_SRC=…                 # 01: 可选，仅 dsh <= 0.1.2 需要
APP_CLEAN=1                        # 02: 全新重装（换版本时）
OUT_DIR=…                          # 04/10/11: 产物落盘目录
STAGE_DIR=…                        # 04/06/09/10/11: 同上
VARIANTS="full slim basic basic-slim"   # build-all: 选择变体
SKIP_INSTALL=1                     # build-all: 复用已装好的 app/node_modules
SKIP_SMOKE=1                       # build-all: 跳过 06 冒烟

01-stage.sh        # 备料：拷 tarball 进暂存
34-pnpm-install.sh # 拉 Node + 生成 file: 依赖清单 + pnpm 9 install（网络解析平台包）
35-platform-prune.sh  # 平台瘦身：删 musl / 非 linux-x64 的绑定变体（约 -340 MB）
03-verify.sh       # 验证：CLI 版本、平台二进制、无编译痕迹
05-glibc-audit.sh  # GLIBC 符号审计（Rocky 8 兼容性）
04-assemble.sh     # 组装 bin/dsh + node/ + app/，打 tar.gz 到 $OUT_DIR
10-assemble-slim.sh   # 系统 Node 变体（复用同一份 app/node_modules）
11-assemble-basic.sh  # basic / basic-slim（硬链接复制后裁剪，源 bundle 不动）
06-smoke.sh        # 冒烟：版本、landlock/bwrap 两 rung、dsh web 启动
```

`build-all.sh` 就是按上表顺序依次调用这些脚本（01 → 34 → 35 → 03 → 05 → 04/10/11 → 06），
每步输出同时落到 `$LOG_DIR/<脚本名>.log`，任一步失败即中止。**35-platform-prune 必须跑在 34 与 04 之间**，
否则包体多出约 340 MB 的 musl / 异构平台绑定。

### 3.3 沙箱组件（一次性）

```bash
STAGE_DIR=… wsl -u root -e bash scripts/linux-assemble/09-build-bwrap.sh
# 产出静态 bwrap → 04 组装时自动进 bin/bwrap
```

### 3.4 精简变体（系统 Node，可选）

内网已有系统 Node（≥ 22.19，推荐 24.x LTS）时可额外产出一个不带运行时的变体，包体小约 55 MB：

```bash
# SYSTEM_NODE = 用于验证的 Node 目录（官方 node-v24.14.0-linux-x64 解压目录；默认 $STAGE/node24）
SYSTEM_NODE=… OUT_DIR=… bash scripts/linux-assemble/10-assemble-slim.sh
# 产出 dsh-linux-x64-slim.tar.gz（复用同一份 app/node_modules，无需重装依赖）
```

### 3.5 Basic 变体（最小可用，可选）

只用 API 提供商（内网 DeepSeek 网关）时，产出裁剪版：移除 Claude Code / Codex 子代理的**平台二进制包**（`@anthropic-ai/claude-agent-sdk-linux-x64` + `@openai/codex-linux-x64`，合计约 630 MB 解压）。JS 外壳、插件包与 OTel 遥测**保留**（`session-telemetry-otel` 在默认 base 层，删了会破坏启动）。基于 3.2/3.4 的完整 bundle 复制裁剪（硬链接，源 bundle 不动），不影响默认 profile 与 `DSH_HOME`：

```bash
# 前置：04（全包版）与 10（slim 版）已产出完整 bundle；09 已产出静态 bwrap
OUT_DIR=… [SYSTEM_NODE=$STAGE/node24] bash scripts/linux-assemble/11-assemble-basic.sh
# 产出 dsh-linux-x64-basic.tar.gz（自带 Node，~130 MB）与 dsh-linux-x64-basic-slim.tar.gz（系统 Node，~75 MB）
```

裁剪清单固化在脚本内（`PRUNE_DIRS`），仅为 proven-dead 的二进制包；boot 冒烟（版本 + web 200）在脚本内对两个变体分别执行，确保未破坏加载（曾因误删 `session-telemetry-otel` 启动失败，此后已改为保留）。

### 3.6 冒烟验收标准

- `bin/dsh --version` 输出目标版本（如 `0.1.5-rc.1`）
- `06-smoke.sh` 全绿：landlock 探测 + 约束执行；**bwrap 解析自 `bin/bwrap`（包内静态）** + 探测 + 约束执行；`dsh web` 起服务并跟随重定向返回 200
- `11-assemble-basic.sh` 对 basic / basic-slim 各自再做一次 web boot（版本 + 200）
- 构建日志无 `node-gyp rebuild`（无安装期编译；0.1.5 起原生 system 包为预编译 Node-API addon，构建期不再需要 python/make）

## 4. 发布清单

1. 四个 `dist/linux/dsh-linux-x64*.tar.gz`（默认全包版约 370 MB）+ `dist/linux/README.md` / `README.zh.md`（operator README，源自 `docs/operator-readme*.md`）
2. `dist/linux/build-info.json`：dsh 版本、上游 commit/tag、构建时间、各产物大小与 SHA-256
3. 版本更新说明：在 `CHANGELOG.zh.md` / `CHANGELOG.md` 追加本版条目（上游面向用户的变更、破坏性变更与升级注意、产物与校验值）
4. 记录：GLIBC 审计结论（`05-glibc-audit.sh` 输出）、冒烟结论
5. 内网分发（文件传输/发布渠道自定）；tar.gz 不入 git

## 5. 常见问题

| 问题 | 处理 |
|---|---|
| `verifying lockfile` 拉不动 registry | 构建机需能访问 registry.npmjs.org（仅构建机需要）；大 tarball 偶发 `error (23)` 重试即可 |
| Windows 下 `tar` 报 `Cannot connect to X:` | PATH 里是 Git 的 busybox tar；`07-repack.ps1` 已强制优先 System32 的 bsdtar |
| `tsdown` 报 `Cannot find entry` | 工作区有上游已删除包的残留目录；先 `pnpm run clean`（`build-linux.ps1` 已内置该步） |
| 版本号不对 | 确认源码检出已到目标版本 tag/commit，再走 3.1 重打包 + 重装（`build-linux.ps1` 不带 `-ReuseStage`） |
| bwrap 构建报 libcap 缺失 | 09 脚本已内置 musl 静态 libcap 步骤；保持 `CC=musl-gcc` 与 `LDFLAGS=-static` |
| WSL 报 `CreateInstance/E_ACCESSDENIED` | 从受限/沙箱终端调用 WSL 会被拒；改用普通终端，并用 `wsl -l -v` 确认发行版名与 `-Distro` 一致 |