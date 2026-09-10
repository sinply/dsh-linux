#!/usr/bin/env bash
# Stage the packed tarballs into the WSL build stage.
# Required env (paths must NOT be baked into this repo):
#   DSH_TGZ_SRC      dir containing the dsh-family tarballs (e.g. <harness>/dist/npm-a3)
#   VENDOR_TGZ_SRC   dir containing the vendor tarballs        (e.g. <harness>/dist/npm-vendor)
#   LANDLOCK_TGZ_SRC dir containing the landlock entry tarball (e.g. <harness>/dist/npm-landlock)
# Optional:
#   STAGE_DIR        build stage dir (default $HOME/dsh-linux-build)
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
TARS="$STAGE/tarballs"
: "${DSH_TGZ_SRC:?set DSH_TGZ_SRC (directory of dsh-family tarballs)}"
: "${VENDOR_TGZ_SRC:?set VENDOR_TGZ_SRC (directory of vendor tarballs)}"
# LANDLOCK_TGZ_SRC carried the landlock entry package (<= 0.1.2). From 0.1.5 the
# native primitives ship as @deepseek-ai/node-addon-system, which is published on
# the registry and resolved during the install, so this stage is optional.
mkdir -p "$TARS"
rm -f "$TARS"/*.tgz
echo "staging into: $TARS"
cp "$DSH_TGZ_SRC"/*.tgz "$TARS/"
cp "$VENDOR_TGZ_SRC"/*.tgz "$TARS/"
if [ -n "${LANDLOCK_TGZ_SRC:-}" ]; then
  cp "$LANDLOCK_TGZ_SRC"/*.tgz "$TARS/"
else
  echo "note: LANDLOCK_TGZ_SRC unset — native primitives come from the registry"
fi
echo "tarballs staged: $(ls "$TARS"/*.tgz | wc -l)"
ls "$TARS" | head -4
ls "$TARS" | tail -3