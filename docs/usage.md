# 使用指南（内网部署）

本文面向在 Rocky Linux 内网环境部署 dsh-linux 发行包的同学。目标机全程离线、零安装。

## 1. 环境要求

| 项 | 要求 |
|---|---|
| 系统 | Rocky Linux 8 或 9，x86_64 |
| glibc | ≥ 2.28（Rocky 8 = 2.28，已踩线验证各原生二进制） |
| 磁盘 | 解压后约 1.3 GB，建议预留 2 GB |
| 内核 | Rocky 9（5.14+）沙箱开箱即用；Rocky 8 需确认 user namespace（见 [沙箱](#3-沙箱)） |
| 网络 | 不需要（全部离线）；仅 LLM 请求需要能到内网网关 |

## 2. 部署与启动

```bash
# 1) 拷包（内网文件传输方式自定）
scp dsh-linux-x64.tar.gz user@rocky8:/opt/

# 2) 解压
cd /opt
tar -xzf dsh-linux-x64.tar.gz

# 3) 验证
./dsh-linux-x64/bin/dsh --version

# 4) 启动 Web GUI
./dsh-linux-x64/bin/dsh web
# 输出形如：dsh web: http://127.0.0.1:3080/?token=<token>
# 用浏览器访问该地址（内网可访问此机器 3080 端口即可）

# 无桌面/纯服务器：
./dsh-linux-x64/bin/dsh web --no-open
# 或后台运行：
nohup ./dsh-linux-x64/bin/dsh web --no-open > dsh.log 2>&1 &
```

### 常用选项与环境变量

| 项 | 说明 |
|---|---|
| `./bin/dsh web --no-open` | 不自动打开浏览器（headless/内网推荐） |
| `DSH_HOME=/path` | 指定数据目录（会话、profile 等）；默认 `~/.dsh` |
| `./bin/dsh --profile <name>` | 使用指定 profile |
| `./bin/dsh bash` | 交互式命令行入口 |

`bin/dsh` 启动器会把包内 `bin/`（静态 bwrap）与 `node/`（运行时）加入 PATH，所有子进程都走内置运行时，与系统环境无关。

## 3. 沙箱

Linux 沙箱运行链：**bwrap（首选）→ landlock-run（备用）**，逐级功能探测，全部不可用则 **fail-closed**（受沙箱约束的工具拒绝执行，绝不无沙箱静默放行）。

- **bwrap**：已静态编译进 `bin/bwrap`，无需任何安装。需要内核支持 user namespace；若探测失败：
  ```bash
  sysctl -w kernel.unprivileged_userns_clone=1   # 立即生效
  # 持久化：echo 'kernel.unprivileged_userns_clone=1' >> /etc/sysctl.d/99-dsh.conf
  ```
- **landlock-run**：包内自带（`app/node_modules/@deepseek-ai/node-addon-landlock-run-linux-x64/bin/landlock-run`，静态 musl）。Rocky 9 内核 5.14+ 直接可用；Rocky 8（4.18）无 Landlock，跳过此 rung。
- 两者都不可用时，沙箱相关工具报 `SANDBOX_UNAVAILABLE`；non-sandboxed 功能（Web 启动、会话管理）不受影响。

## 4. 内网 LLM 出口

内网若不能访问公网 API，在 Web GUI 中配置**自定义 provider**：

1. Settings → Providers → **Add custom provider**
2. 填 Provider ID（小写）、base URL 指向内网 LLM 网关、协议、凭证、模型列表
3. 保存后在会话中选择该 provider / 模型

参考上游文档 `docs/user/guide/providers.md`（deepseek-harness 仓库）。

## 5. 升级

新版本发行包是完整自包含目录：解压新包后用新目录启动即可。旧数据在 `DSH_HOME`，可继续沿用；建议升级前备份 `DSH_HOME`。

## 6. 故障排查

| 现象 | 排查 |
|---|---|
| `--version` 无输出/报错 | 确认解压完整（`tar -xzf` 无报错）；确认 glibc ≥ 2.28（`ldd --version`） |
| 沙箱工具全部失败（`SANDBOX_UNAVAILABLE`） | 见 [沙箱](#3-沙箱)：查 `sysctl kernel.unprivileged_userns_clone`；Rocky 8 无 Landlock 属预期，bwrap 是关键 |
| `dsh web` 启动后打不开 | 用 `--no-open` + 手动访问输出 URL；确认目标机 3080 端口可访问 |
| 页面提示无法连接模型 | 内网 LLM 出口配置（见上）；确认网关可达、凭证正确 |
| 磁盘不足 | 解压需 ~1.3 GB 空闲 |

## 7. 内容构成

```
dsh-linux-x64/
├── bin/dsh            # 自包含启动器
├── bin/bwrap          # 静态编译的 bubblewrap（Linux 沙箱首选）
├── node/              # Node.js 运行时（v22.x linux-x64）
└── app/node_modules/  # dsh 全量依赖（linux-x64 平台解析，含 Web 前端资产）
```

## 8. 精简变体（内网已有系统 Node）

如果内网目标机已经装了 **Node.js ≥ 22.19**（推荐 24.x LTS，已实测 **24.14.0**），可用 `dsh-linux-x64-slim.tar.gz`：不内置 Node 运行时，包体约小 **55 MB**，其余内容与全包版一致。

```bash
tar -xzf dsh-linux-x64-slim.tar.gz
cd dsh-linux-x64

# node 在 PATH 上即可直接运行：
./bin/dsh --version
./bin/dsh web --no-open

# 或指定 node 绝对路径（多版本共存时）：
DSH_NODE_BIN=/usr/local/node-v24/bin/node ./bin/dsh web
```

要点：

- 版本要求与 dsh 引擎一致（`^22.19.0 || >=24.0.0`）；低于 22.19 会在启动时报引擎不满足。
- 沙箱仍走包内静态 `bin/bwrap`，与 Node 无关，行为同全包版。
- 原生依赖（koffi / node-pty / sharp 等）为 N-API 预编译，Node 24 兼容（已实测 web 启动 + 沙箱冒烟）。
- 全包版与精简版切换不影响 `DSH_HOME` 数据。

## 9. Basic 变体（最小可用，砍子代理 CLI 二进制）

内网只用 **API 提供商**（DeepSeek 官方或自定义网关）时，可进一步裁剪 Claude Code / Codex 子代理**内置二进制**（合计约 630 MB 解压，仅实际唤起对应 CLI 时才需要），体积大幅下降：

| 包 | 体积 | 相比默认 |
|---|---|---|
| `dsh-linux-x64-basic.tar.gz`（自带 Node） | **~130 MB** | -64% |
| `dsh-linux-x64-basic-slim.tar.gz`（系统 Node） | **~75 MB** | -75% |

**裁剪内容与限制**：

- 仅移除平台二进制包：`@anthropic-ai/claude-agent-sdk-linux-x64`、`@openai/codex-linux-x64`（Claude Code / Codex 子代理的 CLI 可执行文件）。
- **不可用**：Claude Code 子代理、Codex 子代理的 CLI 后端（JS 外壳与插件包仍在，但唤起时缺可执行文件；需要请用 full 系）。**设计上保证默认 profile 与启动不受影响**（这两个插件不在默认 web profile 中）。
- **保留**：DeepSeek / Anthropic / OpenAI 等 API 提供商、Web 前端、附件图片（sharp）、OTel 遥测（`session-telemetry-otel` 在默认 base 层中，必须保留）、沙箱（静态 bwrap + landlock）。
- 默认 profile 与 `DSH_HOME` 数据不受影响。

```bash
tar -xzf dsh-linux-x64-basic-slim.tar.gz   # 或 basic（自带 Node）
cd dsh-linux-x64
./bin/dsh web --no-open
```

## 10. 环境自检（`bin/check-env.sh`）

四个变体的 `bin/` 都随包带了一个环境自检脚本，内网主机直接跑：

```bash
./bin/check-env.sh                        # 用 DEEPSEEK_BASE_URL / DEEPSEEK_API_KEY（无则测默认 api.deepseek.com）
./bin/check-env.sh http://内网网关/v1     # 或直接给 base URL
```

它会依次检查并明确区分：

| 检查项 | 结果含义 |
|---|---|
| dsh / bwrap / landlock / node | 基础组件是否可用（含 Rocky 8 无 Landlock 属预期，沙箱走 bwrap） |
| `{base}/models` 连通（不带 `-k`） | 端点/端口/防火墙可达性 |
| 失败后再带 `-k` 重试 | 区分 **TLS 证书问题**（内网自签证书常见）与完全不可达 |
| 带 key 发真实 `chat/completions` | 区分 **401/403 凭据错**、**404 路径前缀错**、000 连通/TLS 错 |

**重要认知：模型配置页的绿点 = 配置有效（provider/model 已注册）；不代表端点真实可达。** 遇到"配置绿点 OK 但对话连不上网络"，先跑 `bin/check-env.sh` 定位是 DNS / 端口 / 证书 / 路径 / 凭据中的哪一层。

**自签证书处理**（内网网关是 HTTPS 且证书不被信任时，自检会提示）：
- 把内网 CA 证书加入 dsh 的 Node 信任链（`NODE_EXTRA_CA_CERTS=/path/ca.pem ./bin/dsh web`）；
- 或测试期 `NODE_TLS_REJECT_UNAUTHORIZED=0 ./bin/dsh web`（仅测试，勿在生产用）。