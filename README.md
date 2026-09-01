# dsh-linux

DeepSeek Harness 的 **内网离线 Linux 发行包**：把 dsh CLI、Node.js 运行时、全部依赖、Web 前端与沙箱组件（landlock-run + 静态 bwrap）打包成一个自包含目录，目标机 **解压即用、全程离线、零安装**。

- 产物：`dsh-linux-x64.tar.gz`（约 360 MB，解压后约 1.3 GB）
- 目标平台：Rocky Linux 8 / 9（x86_64），glibc ≥ 2.28
- 上游：dsh = [deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)（MIT）；landlock-run 使用上游发布的平台预编译包（静态 musl）

## 快速开始（内网目标机）

```bash
tar -xzf dsh-linux-x64.tar.gz
cd dsh-linux-x64
./bin/dsh --version        # 0.1.2-alpha.3
./bin/dsh web              # Web GUI：访问启动输出里的 http://127.0.0.1:3080/?token=...
./bin/dsh web --no-open    # 无桌面/内网场景：不尝试自动打开浏览器
```

无需安装 Node.js / npm / 其他系统依赖。沙箱组件已内置：Linux 优先走包内静态 `bin/bwrap`；landlock-run 为备用 rung。

> 个别 RHEL 8 内核默认关闭非特权 user namespace，会让 bwrap 探测失败。此时启用即可：
> `sysctl -w kernel.unprivileged_userns_clone=1`（详见 [docs/usage.md](docs/usage.md#沙箱)）。

## 两种发行变体

| 变体 | 安装包 | 适用条件 | 体积（实测） |
|---|---|---|---|
| 全包版（默认） | `dsh-linux-x64.tar.gz` | 内网机器**没有** Node：自带运行时，零安装 | ~358 MB |
| 精简版（系统 Node） | `dsh-linux-x64-slim.tar.gz` | 内网机器**已有** Node（≥ 22.19，推荐 24.x LTS；已实测 24.14.0） | ~303 MB |

精简版不再内置 Node 运行时，`bin/dsh` 从 PATH（或 `DSH_NODE_BIN` 环境变量）解析系统 node；其余内容（全部依赖、Web 前端、静态 bwrap）与全包版完全一致。切换变体不影响 `DSH_HOME` 数据。

## 文档

- [使用指南 docs/usage.md](docs/usage.md) —— 部署、配置、故障排查、内网 LLM 网关接入
- [构建指南 docs/build.md](docs/build.md) —— 如何从 dsh 源码重新构建本发行包

## 仓库结构

```
dsh-linux/
├── README.md
├── docs/                    # 使用 + 构建文档
├── scripts/linux-assemble/  # 可复现构建脚本（01–09）
└── dist/linux/              # 产物出口（git 忽略，不入库）
```

`dist/` 产物不入库（tar.gz 近 360 MB，且是构建结果而非源码）；发布物通过内网文件传输或其他发布渠道分发。

## License

BSD 3-Clause。上游 dsh 版权归 DeepSeek；本仓库为独立打包与运维工程（协议与署名详见 [LICENSE](LICENSE)）。