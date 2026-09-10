#!/usr/bin/env bash
# dsh-linux 环境自检脚本（随包分发，内网主机直接运行）
#
# 用法:
#   ./bin/check-env.sh                     # 用 DEEPSEEK_BASE_URL / DEEPSEEK_API_KEY（若无则测默认 api.deepseek.com）
#   ./bin/check-env.sh http://内网网关/v1  # 或直接给 base URL
#
# 说明: 模型配置页的绿点只代表"配置有效"，不代表端点真实可达;
#       本脚本做真实探测, 区分 DNS / 连通 / TLS 证书 / 路径 / 凭据 问题。
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd 2>/dev/null || pwd)"
BASE="${DEEPSEEK_BASE_URL:-${1:-https://api.deepseek.com}}"
KEY="${DEEPSEEK_API_KEY:-}"
pass=0; fail=0
ok()  { echo "  [OK]   $1"; pass=$((pass+1)); }
warn(){ echo "  [WARN] $1"; }
err() { echo "  [FAIL] $1"; fail=$((fail+1)); }

echo "=============================================="
echo " dsh-linux 环境自检"
echo "=============================================="

echo
echo "== 1. 基础组件 =="
if "$ROOT/bin/dsh" --version >/dev/null 2>&1; then
  ok "dsh 可执行: $("$ROOT/bin/dsh" --version)"
else
  err "dsh 无法运行 (bin/dsh)"
fi
if [ -x "$ROOT/bin/bwrap" ]; then
  "$ROOT/bin/bwrap" --version >/dev/null 2>&1 && ok "bwrap (包内静态): $("$ROOT/bin/bwrap" --version)" || err "bwrap 无法运行"
else
  warn "包内无 bwrap（basic 以外的变体应包含）"
fi
# Native primitives moved from @deepseek-ai/node-addon-landlock-run-linux-x64
# (<= 0.1.2) to @deepseek-ai/node-addon-system-linux-x64 (>= 0.1.5), and the
# pnpm layout also stores a real copy under .pnpm; resolve by file name.
LL="$(find "$ROOT/app/node_modules" -name landlock-run -type f 2>/dev/null | head -1)"
if [ -n "$LL" ] && [ -x "$LL" ]; then
  V=$("$LL" --probe 2>&1)
  case "$V" in
    *enforced*) ok "landlock-run 探测: $V" ;;
    *) warn "landlock-run: $V （Rocky 8 无 Landlock 属预期，沙箱走 bwrap）" ;;
  esac
else
  warn "包内未找到 landlock-run（原生 system 包缺失？）"
fi
if ! command -v node >/dev/null 2>&1; then
  if [ -x "$ROOT/node/bin/node" ]; then
    ok "node (包内): $("$ROOT/node/bin/node" --version)"
  else
    warn "未找到 node：slim/basic-slim 变体需要系统 node >= 22.19"
  fi
else
  ok "node (系统): $(node --version)"
fi

echo
echo "== 2. LLM 端点真实探测 =="
echo "    base URL: $BASE"
HOST="${BASE#*://}"; HOST="${HOST%%/*}"
PORT="${HOST##*:}"; if [ "$PORT" = "$HOST" ]; then PORT=443; [ "${BASE%%:*}" = "http" ] && PORT=80; fi
HOSTNAME="${HOST%:*}"; [ -z "$HOSTNAME" ] && HOSTNAME="$HOST"

# 2.1 DNS
if command -v getent >/dev/null 2>&1; then
  getent hosts "$HOSTNAME" >/dev/null 2>&1 && ok "DNS 解析: $HOSTNAME" || err "DNS 无法解析: $HOSTNAME"
else
  warn "无 getent，跳过 DNS 检查"
fi

# 2.2 连通 + TLS（先不加 -k，失败再用 -k 区分证书问题）
PROBE_URL="${BASE%/}/models"
code=$(curl -sS -m 8 -o /dev/null -w '%{http_code}' "$PROBE_URL" 2>/dev/null)
code=${code:-000}
if [ "$code" != "000" ]; then
  ok "端点可达 (${PROBE_URL} -> HTTP $code)"
else
  code_k=$(curl -sS -k -m 8 -o /dev/null -w '%{http_code}' "$PROBE_URL" 2>/dev/null)
  code_k=${code_k:-000}
  if [ "$code_k" != "000" ]; then
    err "端点不可达且为 TLS 证书问题（-k 后 HTTP $code_k）"
    echo "      解决: 把内网 CA 证书导入 dsh 的 Node 信任链；或测试期 NODE_TLS_REJECT_UNAUTHORIZED=0"
  else
    err "端点完全不可达: ${HOST}:${PORT} (DNS/防火墙/端口/证书)"
  fi
fi

# 2.3 真实 chat 请求（有 key 时）
if [ -n "$KEY" ]; then
  BODY='"model":"probe","messages":[{"role":"user","content":"hi"}]'
  cr=$(curl -sS -m 20 -o /dev/null -w '%{http_code}' \
       -X POST "${BASE%/}/chat/completions" \
       -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
       -d "{$BODY}" 2>/dev/null)
  cr=${cr:-000}
  case "$cr" in
    2*) ok "chat/completions 带凭据 -> HTTP $cr（端点/凭据/路径正常）" ;;
    401|403) err "chat/completions -> HTTP $cr：凭据无效（检查 API key）" ;;
    404)     err "chat/completions -> HTTP 404：base URL 路径前缀不对（网关可能要 /v1 等）" ;;
    000)     err "chat/completions 无法发起请求（连通/TLS/超时，见上）" ;;
    *)       warn "chat/completions -> HTTP $cr（服务端响应，需人工判断）" ;;
  esac
else
  warn "未设置 DEEPSEEK_API_KEY，跳过真实 chat 请求（只验证了连通性）"
fi

echo
echo "=============================================="
echo " 结果: $pass 项通过, $fail 项失败"
if [ "$fail" -eq 0 ]; then echo " ✅ 环境就绪"; else echo " ❌ 存在失败项，按上面 [FAIL] 提示处理"; fi
echo " 提示: 模型配置页的绿点 = 配置有效；本脚本 = 端点真实可达。"
echo "=============================================="
[ "$fail" -eq 0 ]