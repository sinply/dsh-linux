#!/usr/bin/env bash
# Step 35: platform prune — remove redundant musl / foreign-platform variants
# from the STAGE node_modules (pnpm installs both gnu+musl for some bindings;
# this target is glibc-only Rocky, so musl copies are dead weight).
# Run AFTER the pnpm install (34) and BEFORE assembling (04/10/11).
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
P="$STAGE/app/node_modules/.pnpm"
[ -d "$P" ] || { echo "no .pnpm dir: $P (skip)"; exit 0; }

echo "== removing musl-x64 binding variants =="
find "$P" -maxdepth 1 -type d -name '*-linux-x64-musl@*' -printf '%f\n' | sort
find "$P" -maxdepth 1 -type d -name '*-linux-x64-musl@*' -exec rm -rf {} + 2>/dev/null || true

echo "== removing darwin/win32 binding variants (defensive) =="
find "$P" -maxdepth 1 -type d \( -name '*-darwin@*' -o -name '*-win32@*' -o -name '*-win32-x64@*' -o -name '*-win32-arm64@*' \) -printf '%f\n' | sort
find "$P" -maxdepth 1 -type d \( -name '*-darwin@*' -o -name '*-win32@*' -o -name '*-win32-x64@*' -o -name '*-win32-arm64@*' \) -exec rm -rf {} + 2>/dev/null || true

echo "== node-pty foreign prebuilds =="
find "$P" -maxdepth 1 -type d -name '*node-pty*' -print0 2>/dev/null |
  while IFS= read -r -d "" d; do
    find "$d/node_modules/node-pty/prebuilds" -mindepth 1 -maxdepth 1 -type d \
      ! -name 'linux-x64' ! -name 'linux-arm64' -exec rm -rf {} + 2>/dev/null || true
  done

echo "== after =="
du -sh "$STAGE/app/node_modules"