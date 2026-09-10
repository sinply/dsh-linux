# 版本更新说明（dsh-linux 离线发行包）

本文件记录 dsh-linux 每个发行包的更新内容。**dsh-linux 的版本号跟随上游 dsh 版本号**，同名版本一一对应：例如 `0.1.5-rc.1` 表示该发行包内封装的上游 dsh 为 `0.1.5-rc.1`。

- 产物与校验值（版本、大小、SHA-256）以 `dist/linux/build-info.json` 为准；包内 `BUILD-INFO.txt` 记录了该包对应的 dsh 版本与上游 commit。
- 上游变更的完整提交范围见每节「上游范围」。

---

## 0.1.5-rc.1 — 2026-09-10

**上游范围**：`dsh-v0.1.2-rc.1`（`a66e470204`，2026-09-03）→ `dsh-v0.1.5-rc.1`（`2377c272a8`，2026-09-10）。该区间 999 个非合并提交、6892 个文件、+209941 / −59902 行；中间经过 `0.1.3-alpha.1`、`0.1.3-alpha.2`、`0.1.5-alpha.1`、`0.1.5-alpha.2`（无 0.1.4.x）。

### 产物

| 变体 | 文件 | 大小 | SHA-256 |
|---|---|---|---|
| 全包版（默认） | `dsh-linux-x64.tar.gz` | 349 MB | `dec8e62a92a8d84488c13bf20b7de74af9f67587fa53db5a209e49a339556449` |
| 精简版（系统 Node） | `dsh-linux-x64-slim.tar.gz` | 294 MB | `e6c45c50d9b4ef33cb25f86c9fcdf03ead612895ec920ebee963387151b29e97` |
| Basic 全包版 | `dsh-linux-x64-basic.tar.gz` | 252 MB | `4fe52c9b03c04ec07183dcd75254d1f553efca8e5c5b37cd736f5bacc010130b` |
| Basic 精简版 | `dsh-linux-x64-basic-slim.tar.gz` | 198 MB | `4710d2d9f48ae114e0377b3ba3e7a1719ddb9392b859b79facc51619043f311f` |

构建时间 2026-09-10T09:07:18Z（UTC）；上游 commit `2377c272a8e839e0a84c9f0e623b867a1dce2014`。哈希为本次发行的产物值，完整清单以 `dist/linux/build-info.json` 为准（重新构建会产生不同的哈希）。

### 升级注意（务必先读）

1. **会话磁盘格式 V0 → V3（破坏性）**：`SESSION_FORMAT_VERSION` 从 `0` 升到 `3`。用本版首次打开旧 `DSH_HOME` 时，会对已有会话做一次性相邻迁移（V0→V1→V2→V3）并写入新代际；已提交的历史代际字节保持不变。
   - **升级前请备份 `$DSH_HOME`**（默认 `~/.dsh`）。
   - **迁移后不要回退到 0.1.2-rc.1**：旧版本读不了迁移后的会话。
   - 迁移要求 home 目录可写、磁盘余量充足；同一 `DSH_HOME` 不要被两个 dsh 进程同时打开（本版新增了跨进程写租约，但迁移期间仍应独占）。
   - 证据：`f7a6221158`、`e04cfc4c87`、`ee956c720d`、`d1521ea783`；`docs/session-format-status.md` 记录 `latestReleasedVersion: 3`（证据标签 `dsh-v0.1.5-alpha.1`）。
2. **默认 Chat Completions 模型改为 `deepseek-flash`**（显示名 `DeepSeek-V41-Flash`），此前是 `deepseek-v4-flash`；内置模型目录由 3 个收敛为 1 个（`deepseek-v4-flash` 与 `deepseek-v4-flash-vision-exp` 仍保留在目录中，但默认指向 `deepseek-flash`）。
   - **内网网关若只提供旧模型名，请在 Settings → Providers 里显式配置 `models` 列表**，或调整网关白名单。
   - 证据：`bc5fd3b8dc`（PR #3824）、`packages/bundle/base/cordis.patch.yml`。
3. **`str_replace_editor` 不再由默认 profile 提供**：文件编辑默认走 `read` / `write` / `edit`。依赖该工具的提示词或脚本需要改写，或在自定义组合里显式 `insert`（包仍在仓库中）。
   - 证据：`36a4665144`、`965adbb5cf`、`63795eaa5c`。
4. **原生沙箱包改名（影响包内路径）**：`native/landlock-run` → `native/system`，包名 `@deepseek-ai/node-addon-landlock-run*` → **`@deepseek-ai/node-addon-system*`**，且新包**不提供根导出**，必须走 `/landlock-run` 与 `/flock` 子路径。包内 launcher 路径随之变为
   `app/node_modules/@deepseek-ai/node-addon-system-linux-x64/bin/landlock-run`。
   - 证据：`336ebb235e`、`7264906f99`、`97e7223d5f`。
5. **子代理内置外部 CLI 升级**：Codex `0.149.1 → 0.153.4`、Claude Agent SDK `0.3.241 → 0.3.263`。若内网对这些外部 CLI 有版本管控，需要同步。
   - 证据：`ace0c4619e`（PR #3787）。
6. **不要期待的功能**：同会话消息编辑已在 0.1.5-rc.1 前被上游撤销（`e974a655a0`，PR #3459），本版没有该功能；图表围栏预览只支持 Mermaid，Graphviz / SVG / HTML 预览随 PR #3901 撤销。

### 新能力（面向使用者）

- **Web GUI**：Sidebar 重构为可停靠的多标签工作区；新增文件树标签、文件预览（图片、文本分页并保留阅读位置、文档预览、Mermaid 图表）、文件类型图标；交付文件卡片（不可变、可下载）与原生文件操作；可把 workspace 交给本地应用打开（PR #3409）；连接断开后按可配置退避持续重试（`ConnectionRecoveryConfig`）。
- **工具**：文件读取支持有界字节区间（分页读取大文件）；交付物语义区分「文件被改动」与「显式交付」（新增 `tool-present`）；工具卡支持 `read_image` 图片渲染。
- **网络/代理**：`HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY` 现在真正生效（此前 Node `fetch` 不读这些变量），覆盖模型请求、web search、`web_fetch`、MCP over HTTP；新增用户文档 `docs/user/guide/network-proxy.md`。**限制**：OTLP 遥测不走代理；工作流 worker 不继承代理变量；项目自身的 `.env` 不允许设置代理变量；`NO_PROXY` 不支持 CIDR；不支持 SOCKS。
- **子代理/工作流**：父会话可记录并观察自己拥有的子代理目录；Agent Teams 包进入 experimental 公开发布；工作流消息统一走 steer；子代理 human inbox 控件对齐。
- **MCP**：工具发现遇到重复 cursor 时直接拒绝，避免分页成环（PR #3846）。
- **技能**：技能候选按共享模糊名称排序；技能可录制浏览器 GIF（Playwright）。
- **设置**：自定义 provider 的 base URL 会做校验与归一化；插件实例可区分命名；模型目录非法的设置不再卡死启动。
- **性能**：大会话的打开/迁移改为流式处理，并加入大 Session 基准。

### 沙箱与内网部署要点

- **打包侧**：原生包改为**预编译 Node-API addon**（`bin/glibc/system.node`、`bin/musl/system.node`）+ 静态 `bin/landlock-run`，构建期不再需要 python/make/g++ 编译原生模块。
- **运行侧**：Linux 沙箱链仍是 **包内静态 bwrap（首选）→ landlock-run（备用）**，逐级探测、全部不可用则 fail-closed，行为与本仓库上一版一致；包内 bwrap 为静态链接 bubblewrap 0.11.0，与上一版相同。
- **新增 flock 写锁**：跨进程会话写所有权用 POSIX flock 仲裁；锁不可用时拒绝获取（不会给出未保护的锁）。
- **遥测/隐私（请评估）**：显式反馈（`/feedback`、Dislike）默认上传，且对所有用户与所有 provider 生效，采集范围为 seq 0 起该反馈的完整未处理上下文（可能包含继承的历史）。若内网不允许外发，请在部署时确认遥测配置（`session-telemetry-otel` 在默认 base 层）。证据：`9ffe85a512`（PR #3598）。
- 子进程原生 containment 加固（逃逸后代收敛、取消结算），Windows 侧为子进程窗口隐藏等修复——对 Linux 发行包无直接行为变化。

### 打包工程（dsh-linux 侧）

- 新增**一键打包**：`scripts/build-linux.ps1`（Windows 编排，含预检、上游构建、重打包、WSL 组装、交付与校验清单）与 `scripts/linux-assemble/build-all.sh`（WSL 侧驱动，逐步流水线 + 日志 + 失败即停）。
- **平台瘦身（`35-platform-prune.sh`）纳入流水线**：删掉 musl / 非 linux-x64 绑定变体（约 −340 MB），此前需手动执行。
- **版本可追溯**：每个 bundle 内新增 `BUILD-INFO.txt`（dsh 版本、上游 commit/tag、运行时、构建时间）；`dist/linux/build-info.json` 记录全部产物的版本、大小与 SHA-256。
- `04-assemble.sh` 不再固化本机路径（`STAGE_DIR` 生效）；`22-re-extract.sh` 支持 `OUT_DIR` / `VARIANTS`；`01-stage.sh` 的 landlock 备料变为可选（0.1.5 起原生包由 registry 解析）。
- 脚本对原生包改名做了兼容：landlock launcher 改为按文件名解析，`check-env.sh` 与 `06-smoke.sh` 在新旧两种包布局下都可用。

### 校验结论

本次构建在 WSL2 Ubuntu 22.04（内核 6.6）上实测：

- **四个变体的 `bin/dsh --version` 均为 `0.1.5-rc.1`**；解压后 `check-env.sh` 与 `BUILD-INFO.txt` 齐备。
- **GLIBC 符号审计**（Rocky 8 底线 2.28）：node-pty **2.28**（踩线）、koffi 2.17、sharp 2.17、rolldown 2.16、lightningcss 2.14、`node-addon-require-builtin` 2.14、`node-addon-system` 的 `bin/glibc/system.node` 2.4；landlock-run 与 esbuild 为静态/无 glibc 符号 —— 全部 ≤ 2.28。
- **零本地编译**：安装日志中 `node-gyp rebuild` / `gyp ERR` 命中数为 0；全部原生依赖走官方预编译产物（0.1.5 起 `@deepseek-ai/node-addon-system` 也是预编译 Node-API addon）。
- **沙箱两 rung**：包内静态 `bin/bwrap` 探测 + 约束执行通过 ✅；`landlock-run`（`@deepseek-ai/node-addon-system-linux-x64@0.1.2`）探测 + 约束执行通过 ✅（WSL 内核 ABI 较旧，报告 `partially enforced (older ABI)`；Rocky 9 上为完整强制）。
- **Web 启动**：四个变体分别启动 `dsh web`，token URL 跟随重定向返回 **HTTP 200** ✅。
- **产物完整性**：四个 tar.gz 重新解压校验通过，包内 `BUILD-INFO.txt` 变体标记正确（full / slim / basic / basic-slim）。

### 已知限制

- `basic` / `basic-slim` 不含 Claude Code 与 Codex 子代理的 CLI 可执行文件（仅移除平台二进制包，JS 外壳与插件保留）；需要这两个子代理时请用 `full` / `slim`。
- slim 系需要目标机自带 Node ≥ 22.19（推荐 24.x LTS，已在 24.14.0 上实测）；full / basic 自带 Node v22.23.2。
- OTLP 遥测不走代理；`NO_PROXY` 不支持 CIDR；不支持 SOCKS 代理。
- Rocky 8（内核 4.18）无 Landlock，走 bwrap；个别内核默认关闭非特权 user namespace，需要 `sysctl -w kernel.unprivileged_userns_clone=1`。
