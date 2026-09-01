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

### 3.1 打 tarball（Windows 侧）

```powershell
# 官方 profile 构建（host + client + web 前端）
pnpm run build:official

# 重打包（输出 dist/npm-a3、dist/npm-vendor-a3；landlock entry 在 dist/npm-landlock）
$env:HARNESS_ROOT = "<deepseek-harness 检出路径>"
& scripts/linux-assemble/07-repack.ps1
```

> `07-repack.ps1` 通过环境变量取路径（`HARNESS_ROOT`、可选 `PNPM_CMD`），仓库内不固化任何本机路径。

### 3.2 WSL 组装（每步一个脚本，环境变量驱动）

```bash
# 环境变量速查
STAGE_DIR=~/dsh-linux-build        # 组装暂存（默认 $HOME/dsh-linux-build）
DSH_TGZ_SRC=…                      # 01: dsh 家族 tarball 目录
VENDOR_TGZ_SRC=…                   # 01: vendor tarball 目录
LANDLOCK_TGZ_SRC=…                 # 01: landlock entry tarball 目录
APP_CLEAN=1                        # 02: 全新重装（换版本时）
OUT_DIR=…                          # 04: 产物落盘目录
STAGE_DIR=…                        # 06/09: 同上

01-stage.sh        # 备料：拷 tarball 进暂存
02-fetch-node-install.sh   # 拉 Node + 生成 file: 依赖清单 + npm install（网络解析平台包）
03-verify.sh       # 验证：CLI 版本、平台二进制、无编译痕迹
05-glibc-audit.sh  # GLIBC 符号审计（Rocky 8 兼容性）
04-assemble.sh     # 组装 bin/dsh + node/ + app/，打 tar.gz 到 $OUT_DIR
06-smoke.sh        # 冒烟：版本、landlock/bwrap 两 rung、dsh web 启动
```

### 3.3 沙箱组件（一次性）

```bash
STAGE_DIR=… wsl -u root -e bash scripts/linux-assemble/09-build-bwrap.sh
# 产出静态 bwrap → 04 组装时自动进 bin/bwrap
```

### 3.4 冒烟验收标准

- `bin/dsh --version` 输出目标版本（如 `0.1.2-alpha.3`）
- `06-smoke.sh` 全绿：landlock 探测 + 约束执行；**bwrap 解析自 `bin/bwrap`（包内静态）** + 探测 + 约束执行；`dsh web` 起服务并跟随重定向返回 200
- 构建日志无 `node-gyp rebuild`（无安装期编译）

## 4. 发布清单

1. `dsh-linux-x64.tar.gz`（约 360 MB）+ 附带的 operator README
2. 记录：dsh 版本号、上游源码 commit、构建日期、GLIBC 审计结论
3. 内网分发（文件传输/发布渠道自定）；tar.gz 不入 git

## 5. 常见问题

| 问题 | 处理 |
|---|---|
| `verifying lockfile` 拉不动 registry | 构建机需能访问 registry.npmjs.org（仅构建机需要） |
| Windows 下 `tar` 报 `Cannot connect to X:` | PATH 里是 Git 的 busybox tar；`07-repack.ps1` 已强制优先 System32 的 bsdtar |
| 版本号不对 | 确认源码检出已到目标版本 tag，再走 3.1 重打包 + `APP_CLEAN=1` 重装 |
| bwrap 构建报 libcap 缺失 | 09 脚本已内置 musl 静态 libcap 步骤；保持 `CC=musl-gcc` 与 `LDFLAGS=-static` |