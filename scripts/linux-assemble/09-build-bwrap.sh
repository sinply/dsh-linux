#!/usr/bin/env bash
# Step 9: static musl build of bubblewrap (for bundling into the offline package).
# bwrap 0.11.0 hard-requires libcap, so first build libcap statically with musl.
# Runs inside WSL (needs root for apt). Output: $STAGE_DIR/bwrap (static ELF).
set -e
BWRAP_VER="0.11.0"
LIBCAP_VER="2.66"
WORK="/opt/dsh-bwrap-build"
OUT_DIR="${STAGE_DIR:-/opt/dsh-bwrap-build/out}"
LIBCAP_PREFIX="$WORK/libcap-musl"
mkdir -p "$OUT_DIR"

echo "== apt tools =="
apt-get update -qq
apt-get install -y -qq musl-tools meson ninja-build curl make
command -v pkg-config >/dev/null || apt-get install -y -qq pkg-config

echo "== fetch sources =="
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
curl -fsSLo libcap.tar.gz "https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-${LIBCAP_VER}.tar.gz" || \
  curl -fsSLo libcap.tar.gz "https://github.com/iputils/libcap/archive/refs/tags/v${LIBCAP_VER}.tar.gz"
mkdir libcap && tar -xzf libcap.tar.gz -C libcap --strip-components=1
curl -fsSLo bwrap.tar.gz "https://github.com/containers/bubblewrap/archive/refs/tags/v${BWRAP_VER}.tar.gz"
tar -xzf bwrap.tar.gz

echo "== static musl build of libcap =="
cd "$WORK/libcap"
make CC=musl-gcc BUILD_CC=gcc -j4 >/dev/null
make install CC=musl-gcc DESTDIR="$LIBCAP_PREFIX" PREFIX=/usr >/dev/null
# Static link only: drop the shared objects so -lcap resolves to libcap.a.
rm -f "$LIBCAP_PREFIX"/lib64/libcap.so*
find "$LIBCAP_PREFIX" \( -name "libcap.a" -o -name "libcap.pc" \) | sort
file "$LIBCAP_PREFIX/lib64/libcap.a"

echo "== static musl build of bubblewrap =="
cd "$WORK/bubblewrap-${BWRAP_VER}"
# The staged libcap .pc declares prefix=/usr; sysroot rewrites -I/-L into the stage.
export PKG_CONFIG_LIBDIR="$LIBCAP_PREFIX/lib64/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$LIBCAP_PREFIX"
# musl-gcc does not search /usr/include: add idirafter dirs for the staged
# libcap headers and a kernel-UAPI symlink farm (linux/*.h from linux-libc-dev).
KHEADERS="$WORK/kheaders"
mkdir -p "$KHEADERS"
ln -sfn /usr/include/linux "$KHEADERS/linux"
ln -sfn /usr/include/asm-generic "$KHEADERS/asm-generic"
ln -sfn /usr/include/x86_64-linux-gnu/asm "$KHEADERS/asm"
C_ARGS="-idirafter $LIBCAP_PREFIX/usr/include -idirafter $KHEADERS"
CC=musl-gcc LDFLAGS="-static -L$LIBCAP_PREFIX/lib64" meson setup _build \
  -Dc_args="$C_ARGS" \
  -Dselinux=disabled -Dman=disabled -Dtests=false \
  -Dbash_completion=disabled -Dzsh_completion=disabled \
  -Dbuildtype=release
ninja -C _build

echo "== artifact =="
file _build/bwrap
ldd _build/bwrap 2>&1 | head -2 || true
_build/bwrap --version
install -Dm755 _build/bwrap "$OUT_DIR/bwrap"
ls -lh "$OUT_DIR/bwrap"
echo "== done: $OUT_DIR/bwrap =="