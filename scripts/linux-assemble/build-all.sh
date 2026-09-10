#!/usr/bin/env bash
# One-shot driver for the WSL/Linux half of the dsh-linux build.
#
#   bash scripts/linux-assemble/build-all.sh
#
# Steps (each tees to $LOG_DIR/<script>.log, aborts the run on first failure):
#   01-stage.sh            stage the packed tarballs into $STAGE/tarballs
#   34-pnpm-install.sh     pnpm 9 install (linux-x64 glibc resolution)
#   35-platform-prune.sh   drop musl / foreign-platform binding variants
#   03-verify.sh           CLI version, platform binaries, no-compile audit
#   05-glibc-audit.sh      GLIBC symbol audit (Rocky 8 floor: 2.28)
#   04-assemble.sh         full bundle (bundled Node)  -> dsh-linux-x64.tar.gz
#   10-assemble-slim.sh    slim bundle (system Node)   -> dsh-linux-x64-slim.tar.gz
#   11-assemble-basic.sh   pruned bundles              -> dsh-linux-x64-basic*.tar.gz
#   06-smoke.sh            landlock + static bwrap + `dsh web` acceptance (full bundle)
#
# Required environment:
#   OUT_DIR            deliverable directory (e.g. <dsh-linux>/dist/linux)
#   DSH_TGZ_SRC        dsh-family tarball dir  (harness dist/npm-<suffix>)
#   VENDOR_TGZ_SRC     vendor tarball dir      (harness dist/npm-vendor-<suffix>)
#   LANDLOCK_TGZ_SRC   landlock tarball dir    (harness dist/npm-landlock)
#                      the three *_SRC vars are not needed with SKIP_INSTALL=1
# Optional environment:
#   STAGE_DIR          build stage (default $HOME/dsh-linux-build)
#   DSH_LINUX_REPO     dsh-linux checkout; default is this script's repo
#   VARIANTS           subset of "full slim basic basic-slim" (default: all four)
#   SKIP_INSTALL=1     keep the existing $STAGE install (skips 01/34/35)
#   SKIP_SMOKE=1       skip 06-smoke.sh
#   LOG_DIR            step logs (default $STAGE/logs)
#   SYSTEM_NODE        Node dir used to verify the slim bundles (default $STAGE/node24)
#   PACKAGE_VERSION    version stamped into each bundle's BUILD-INFO.txt
#                      (default: the version actually installed under $STAGE/app)
#   UPSTREAM_COMMIT    upstream commit stamped into BUILD-INFO.txt
#   UPSTREAM_TAG       upstream tag stamped into BUILD-INFO.txt
#   BUILD_DATE         build timestamp stamped into BUILD-INFO.txt (default: now, UTC)
set -euo pipefail

# scripts/build-linux.ps1 hands the whole environment over in a file (an env-var
# list is not safe to pass through a Windows -> WSL command line).
if [ -n "${DSH_LINUX_ENV:-}" ]; then
  [ -f "$DSH_LINUX_ENV" ] || { echo "error: DSH_LINUX_ENV=$DSH_LINUX_ENV not found" >&2; exit 1; }
  set -a
  # shellcheck disable=SC1090
  . "$DSH_LINUX_ENV"
  set +a
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
OUT="${OUT_DIR:?set OUT_DIR (directory that receives the deliverables)}"
export OUT_DIR="$OUT"
export STAGE_DIR="$STAGE"
export DSH_LINUX_REPO="${DSH_LINUX_REPO:-$(cd "$HERE/../.." && pwd)}"
export SYSTEM_NODE="${SYSTEM_NODE:-$STAGE/node24}"
export BUILD_DATE="${BUILD_DATE:-$(date -u '+%Y-%m-%dT%H:%M:%SZ')}"
LOGS="${LOG_DIR:-$STAGE/logs}"
mkdir -p "$LOGS" "$OUT"

VARIANTS="${VARIANTS:-full slim basic basic-slim}"
VARIANTS="${VARIANTS//,/ }"   # accept comma-separated as well as space-separated
want() { case " $VARIANTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
# The basic variants are pruned copies of the full/slim bundles, so their sources
# are build prerequisites even when they are not requested themselves.
if want basic && ! want full; then VARIANTS="$VARIANTS full"; fi
if want basic-slim && ! want slim; then VARIANTS="$VARIANTS slim"; fi

fail() { echo "error: $*" >&2; exit 1; }

step() {
  local name="$1"
  local t0=$SECONDS
  local log="$LOGS/$name.log"
  echo ""
  echo "=== $name  $(date '+%H:%M:%S') ==="
  if ! bash "$HERE/$name" 2>&1 | tee "$log"; then
    fail "$name failed — see $log"
  fi
  echo "--- $name ok in $((SECONDS - t0))s (log: $log)"
}

echo "=============================================="
echo " dsh-linux assembly"
echo "   repo       : $DSH_LINUX_REPO"
echo "   stage      : $STAGE"
echo "   out        : $OUT"
echo "   variants   : $VARIANTS"
echo "   logs       : $LOGS"
echo "=============================================="

[ -d "$STAGE" ] || mkdir -p "$STAGE"
if [ "${SKIP_INSTALL:-0}" = "1" ]; then
  [ -d "$STAGE/app/node_modules" ] || fail "SKIP_INSTALL=1 but $STAGE/app/node_modules is missing"
  echo "SKIP_INSTALL=1 — reusing the existing install under $STAGE/app"
else
  for v in DSH_TGZ_SRC VENDOR_TGZ_SRC; do
    d="${!v:-}"
    [ -n "$d" ] || fail "set $v (or run with SKIP_INSTALL=1)"
    [ -d "$d" ] || fail "$v=$d is not a directory"
  done
  # Optional: the landlock entry tarball set used up to dsh 0.1.2. From 0.1.5 the
  # native primitives (@deepseek-ai/node-addon-system) come from the registry.
  if [ -n "${LANDLOCK_TGZ_SRC:-}" ] && [ ! -d "$LANDLOCK_TGZ_SRC" ]; then
    fail "LANDLOCK_TGZ_SRC=$LANDLOCK_TGZ_SRC is not a directory"
  fi
fi
if [ -x "$STAGE/bwrap/bwrap" ]; then
  echo "static bwrap: $("$STAGE/bwrap/bwrap" --version 2>/dev/null || echo present)"
else
  echo "WARN: no static bwrap at $STAGE/bwrap/bwrap — bundles will ship without bin/bwrap"
  echo "      build it once with:  STAGE_DIR=$STAGE wsl -u root -e bash $HERE/09-build-bwrap.sh"
fi
if want slim; then
  [ -x "$SYSTEM_NODE/bin/node" ] || fail "SYSTEM_NODE=$SYSTEM_NODE has no bin/node (needed by 10/11)"
  echo "system node (slim verification): $("$SYSTEM_NODE/bin/node" --version)"
fi

if [ "${SKIP_INSTALL:-0}" = "1" ]; then
  :
else
  step 01-stage.sh
  step 34-pnpm-install.sh
  step 35-platform-prune.sh
fi
step 03-verify.sh
step 05-glibc-audit.sh

if want full; then step 04-assemble.sh; fi
if want slim; then step 10-assemble-slim.sh; fi
if want basic || want basic-slim; then step 11-assemble-basic.sh; fi
if want full && [ "${SKIP_SMOKE:-0}" != "1" ]; then step 06-smoke.sh; fi

echo ""
echo "=============================================="
echo " deliverables in $OUT"
echo "=============================================="
ls -lh "$OUT"/dsh-linux-x64*.tar.gz 2>/dev/null | awk '{print "  " $9 "  " $5}' || true
if [ -n "${PACKAGE_VERSION:-}" ]; then
  echo " package version: $PACKAGE_VERSION"
else
  "$STAGE/node/bin/node" -p 'require(process.argv[1]).version' \
    "$STAGE/app/node_modules/@deepseek-ai/dsh/package.json" 2>/dev/null |
    sed 's/^/ installed dsh version: /' || true
fi
echo " done in $((SECONDS / 60))m$((SECONDS % 60))s"
