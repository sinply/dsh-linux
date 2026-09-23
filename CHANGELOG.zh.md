# 版本更新说明（dsh-linux 离线发行包）

本文件记录 dsh-linux 每个发行包的更新内容。**dsh-linux 的版本号跟随上游 dsh 版本号**，同名版本一一对应：例如 `0.1.5-rc.1` 表示该发行包内封装的上游 dsh 为 `0.1.5-rc.1`。

- 产物与校验值（版本、大小、SHA-256）以 `dist/linux/build-info.json` 为准；包内 `BUILD-INFO.txt` 记录了该包对应的 dsh 版本与上游 commit。
- 上游变更的完整提交范围见每节「上游范围」。

---

## 0.1.7-rc.1 — 2026-09-23

**上游范围**：`dsh-v0.1.5-rc.1`（`2377c272a8`，2026-09-10）→ `dsh-v0.1.7-rc.1`（`46a7f68b09`，2026-09-23）。该区间 2213 个非合并提交 + 1095 个合并提交、7889 个文件、+1206887 / −128109 行；中间经过 `0.1.5-rc.2`、`0.1.5-rc.3`、`0.1.6-alpha.1`、`0.1.6-alpha.2`、`0.1.7-alpha.1`、`0.1.7-alpha.2`。

### 产物

| 变体 | 文件 | 大小 | SHA-256 |
|---|---|---|---|
| 全包版（默认） | `dsh-linux-x64.tar.gz` | 440 MB | `454d73696f28f6c26d01e6754f663aca5e9fd97a3d411883d6d86de05d55007d` |
| 精简版（系统 Node） | `dsh-linux-x64-slim.tar.gz` | 386 MB | `f869a9eb7b8cd5d040ade762c840d8a9ca134b2dd87138cfee06828ee7f9a5e9` |
| Basic 全包版 | `dsh-linux-x64-basic.tar.gz` | 343 MB | `3b95dbdf9719f2770e904016316fc4717d76acdc78c792e38a5e94df15a99f17` |
| Basic 精简版 | `dsh-linux-x64-basic-slim.tar.gz` | 288 MB | `82a9219d0a7a69812371b6147231ab86d97c2db252df502c898485b939e68def` |

构建时间 2026-09-23T15:26:44Z（UTC）；上游 commit `46a7f68b0922371ce7144b668b90e377d8e799f4`；工作树干净（`upstreamDirty: false`）。哈希为本次发行的产物值，完整清单以 `dist/linux/build-info.json` 为准（重新构建会产生不同的哈希）。

**体积相比 0.1.5-rc.1 明显增长**（349→440 / 294→386 / 252→343 / 198→288 MB），主要来自上游新增能力所需的依赖（解压后）：`@deepseek-ai/libreoffice-kit-wasm` **186 MB**（Office 转换）、`@trycua/cua-driver-linux-x64-gnu` **42 MB**（computer-use）、`sherpa-onnx-linux-x64` **32 MB**（语音转写），以及约 44 个新增包。

### 升级注意（务必先读）

1. **会话磁盘格式 V3 → V4（破坏性）**：`SESSION_FORMAT_VERSION` 从 `3` 升到 `4`（`packages/core/session/src/types.ts`，引入提交 `669b724a78`）。0.1.7-rc.1 是**第一个以 V4 写入**的发行版。
   - **升级前请备份 `$DSH_HOME`**（默认 `~/.dsh`）。
   - 新增 `session-format-v3-to-v4` 迁移包，把受支持的已发布 V3 会话恢复为 V4，**不重写已存储的代际**；但**反向（V4→V3）迁移在仓库内没有证据**，因此**迁移后不要回退到 0.1.5-rc.1**。
   - 上游发布记录 `docs/session-format-status.md` 在两个 tag 上都仍写着 `latestReleasedVersion: 3`（证据标签 `dsh-v0.1.5-alpha.1`），同时新增了独立的 Finalization 记录 `latestFinalizedVersion: 4`：**V4 已定稿，但发布记录尚未推进**。换言之，本包写入的格式比上游文档标记的"已发布格式"更新一代。
2. **`$DSH_HOME/settings.yaml` 不再是活配置文档**：Settings 启动且 Loader 完成后，早期版本遗留的 `settings.yaml` 会被**一次性导入**到 profile patch 的同名条目，并在首次写入前改名为 **`settings.yaml.imported`**；被当前组合拒绝的 section **只保留在改名后的文件里**。升级前请备份该文件。
3. **预设机制重建为声明式（破坏性）**：旧的 `default` / `roots` / `includeShippedRoot` / `includeUserRoot` / `USER_PRESET_DIR` 与磁盘预设目录（`packages/preset/agent-presets/presets/`）在 0.1.7 全部不存在，改为 `packages/bundle/web-app/presets/{cordis,minimal,ptc,standard}.patch.yml` 四个 profile patch；新配置字段为 `selectedDefault`、`modeSelectionEnabled`。**用户自建的预设目录不会再被读取**，仓库内没有自动转换工具。
4. **配置项重命名**：base 的 `spill-policy` 由 `maxInlineBytes: 50000` 改为 **`maxInlineTokens: 12500`**；存量 overlay 若仍写旧键需改写。
5. **`tool-ralph` 默认禁用**（base patch 加 `disabled: true`，可通过 overlay 行恢复）。
6. **包与目录增删**：
   - 删除：`@deepseek-ai/dsh-settings-file`、`packages/e2b/*`（E2B 云沙箱族整体移除）、`packages/code-runtime/*`、`workflow-worker-thread`（由 `ptc-runtime` + `workflow-ptc` 取代）、`packages/fs/tool-present`（迁到 `packages/deliverables/`）。
   - 新增：`dsh-settings`（seam）、`dsh-config-editor`、`dsh-plugin-manager`、`dsh-hmr`、`dsh-authorization`、`dsh-deepseek-account*`、`dsh-mcp-resources`、`dsh-compaction-image-offload`、`dsh-ptc-runtime(-node)`、`dsh-workflow-ptc`、`dsh-agent-preset(-registry)`、`dsh-skill-office`、`dsh-tool-workspace-dependencies`、`dsh-ssh` / `dsh-sandbox-ssh` / `dsh-fs-ssh` / `dsh-subprocess-ssh`、`dsh-api-{account,job,terminal}-controller`、`dsh-document-office-to-pdf`、`dsh-session-format-v3-to-v4`、`dsh-product-telemetry-otel`。
7. **默认模型标识未变**（`deepseek-official` / `deepseek-flash`），但目录内容变了：`deepseek-flash` 显示名改为 **`DeepSeek-V41-Flash`**（text+image，`systemPromptUpdate: in-history`），新增 **`deepseek-v4-pro`**（`DeepSeek-V4-Pro`），并移除了旧的 V4 Flash / V4 Flash Vision Exp 默认项；官方 DeepSeek 适配器改为 **Messages-only**。
8. **Node 引擎要求未变**：根 `package.json` 两版都是 `^22.19.0 || >=24.0.0`，没有任何包要求更高版本 —— 所以包内自带的 **Node v22.23.2 仍然满足**（slim 系的系统 Node 要求也不变）。
9. **内部依赖改为精确版本**：dsh 族内一律 `workspace:*`（打包成精确版本），vendor / native 用 `workspace:~`。这只影响第三方消费者（不能再混用不同版本的 dsh 包），离线包本身是整包同版本。

### 新能力

- **Web GUI**：工具过程可视化重构（四种工作细节模式、preparing / start / result 三阶段、文件改动的内容准备进度）；会话分组；可扩展会话菜单；Team 面板交互与投影面板；交付物审阅（单标签页对比一轮内变更文件、从卡片直接对比）；Excel / PDF / 图片预览；设置页把"添加模型"合并为第三方与自定义 API 两种模式；DeepSeek 账号登录与 Platform 页面；插件本地化元数据展示。
- **工具**：jobs 统一为 `JobSpec` / `VisibleJobs` 与单一事件流，支持人工 kill 作业；subagent 委派上限收敛（默认 8 个活跃可续子代理、深度 1，按根节点封顶 16）；新增 workspace 依赖工具；交付物独立包组；持久终端 Remote 控制器。
- **MCP**：scoped resources 与 server instructions、现代协议协商、`mcp-resources` 包。
- **插件**：强制 DSH peer 兼容性并以类型化拒绝报告不兼容；插件管理器支持首个可用公共 registry、GitHub 安装失败的镜像恢复、CN 网络出口优先大陆镜像；新增可选 bundle（如 Auto review）默认关闭并在安装对话框中引导。
- **网络与出口**：`node-addon-require-builtin` 升到 `^0.1.6`（linux-x64 使用 `-linux-x64-gnu` 变体）；gateway 新增 `streamInboxBytes`（默认 262144，超限报 `gateway/uplink-overflow`）；新增 SSH 后端族（`dsh-ssh` / `sandbox-ssh` / `fs-ssh` / `subprocess-ssh`）。
- **沙箱与子进程**：Linux 取消结算与 scope 收敛、Windows 控制台窗口隐藏、sandbox 删除权限收紧（ACL / Low integrity）、ACL 源解析固定。
- **遥测**：新增产品事件 OTLP exporter 包，支持 `DSH_TELEMETRY_DISABLED` 关闭。

### 沙箱与内网部署要点

- 原生沙箱包 **未变**：`@deepseek-ai/node-addon-system` 与 `-linux-x64` 仍为 **0.1.2**（静态 Landlock launcher + glibc/musl 的 Node-API flock addon）。
- 捆绑的外部子代理 CLI **未变**：Claude Agent SDK `0.3.263`、`@anthropic-ai/sdk` `0.93.0`、`@openai/codex` `0.153.4`。
- 内网代理支持（`HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `NO_PROXY`）沿用上一版；限制不变：OTLP 遥测不走代理、`NO_PROXY` 不支持 CIDR、不支持 SOCKS。
- **Office 文档转换新增第三方依赖** `@deepseek-ai/libreoffice-kit@^0.1.0`：它**没有 linux-x64 原生平台包**，只有 `-wasm`，因此 linux-x64 上的 Office 转换走 wasm 路径，实际可用性以包内实测为准（本次未单独验证）。

### 打包工程（dsh-linux 侧）

- **上游发布族规则变化**：`scripts/release/families.ts` 由「非实验包 + 实验白名单」改为 `packages/*/*/package.json` + `apps/*/package.json`（实验包策略变为当前为空的私有 denylist）。**所有 `packages/experimental/*` 现在默认都会打包**，本次 dsh 族 tarball 数由 265 增至 309。
- 修复 `build-linux.ps1` 两处只在 PowerShell 5.1 下暴露的问题：`Tee-Object` 不支持 `-Encoding`（0.1.5 那轮之后新增，本次首次跑到才暴露）；`upstreamDirty` 误把未跟踪文件算作改动（现在只看跟踪文件的改动）。
- 修复 `22-re-extract.sh` 的两个缺陷：`VARIANTS` 不接受逗号分隔（`build-linux.ps1 -Extract` 传的是逗号分隔，手动调用时曾静默什么都没做、留下旧版本的解压目录）；tarball 缺失时改为报错退出而不是静默跳过。
- `publish-release.ps1` 的英文前言改为不含版本号/格式号的通用措辞（此前硬编码 "0.1.2-rc.1 / V0→V3"，会在后续版本里变成错误信息）。
- 一键打包 / 发布会话流程不变：`scripts/build-linux.ps1`（构建全流程）与 `scripts/publish-release.ps1`（打 tag + GitHub release + 上传资产，含哈希校验）。

### 校验结论

本次构建在 WSL2 Ubuntu 22.04（内核 6.6）上实测：

- **四个变体的 `bin/dsh --version` 均为 `0.1.7-rc.1`**；包内 `check-env.sh` 与 `BUILD-INFO.txt` 齐备。
- **零本地编译**：安装日志中 `node-gyp rebuild` / `gyp ERR` 命中数为 0；全部原生依赖走官方预编译产物。
- **沙箱两 rung**：包内静态 `bin/bwrap` 探测 + 约束执行通过 ✅；`landlock-run`（`@deepseek-ai/node-addon-system-linux-x64@0.1.2`）探测 + 约束执行通过 ✅。
- **Web 启动**：四个变体分别启动 `dsh web`，token URL 跟随重定向返回 **HTTP 200** ✅。
- **GLIBC 符号审计（重要变化）**：多数原生二进制仍 ≤ 2.28（node-pty **2.28**、koffi 2.17、sharp 2.17、rolldown 2.16、lightningcss 2.14、`node-addon-require-builtin` 2.14、`node-addon-system` 的 `bin/glibc/system.node` 2.4、landlock-run/esbuild 静态）。**但本版新增的三个实验能力原生 addon 超过了 2.28 底线**：
  - `sherpa-onnx-linux-x64@1.13.8` → **GLIBC_2.32**（语音转写）
  - `@trycua/cua-driver-linux-x64-gnu@0.28.0` → **GLIBC_2.30**（computer-use）
  - `@ubjs/node-linux-x64-gnu@0.31.0-3` → **GLIBC_2.30**（browser-use 运行时）
  - 这三个包**都不在默认 profile 里**（`packages/bundle/**/*.patch.yml` 无引用），即默认功能（Web GUI、会话、沙箱、模型请求）不会加载它们；但在 **Rocky 8（glibc 2.28）** 上启用这三项实验能力会因缺少符号而失败。Rocky 9（glibc ≥ 2.34）不受影响。
- **产物完整性**：四个 tar.gz 的 gzip 流校验与包内 `BUILD-INFO.txt` 内容校验通过（变体标记与版本正确）。

### 已知限制

- `basic` / `basic-slim` 仍然只裁剪 Claude Code 与 Codex 子代理的 CLI 可执行文件；需要这两个子代理时请用 `full` / `slim`。
- slim 系需要目标机自带 Node ≥ 22.19（推荐 24.x LTS）；full / basic 自带 Node v22.23.2。
- **Rocky 8 上的实验能力限制**：语音转写（sherpa-onnx）、computer-use（cua-driver）、browser-use（ubjs）的原生 addon 需要 glibc 2.30–2.32，**Rocky 8（glibc 2.28）无法加载**；它们不在默认 profile 中，默认功能不受影响。Rocky 9 不受限。
- Rocky 8（内核 4.18）无 Landlock，走 bwrap；个别内核默认关闭非特权 user namespace，需要 `sysctl -w kernel.unprivileged_userns_clone=1`。
- Office 转换为 wasm 路径（libreoffice-kit 无 linux-x64 原生包），未在本次发行中单独实测。

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
