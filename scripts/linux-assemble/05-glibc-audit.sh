#!/usr/bin/env bash
# Step 5: audit the maximum GLIBC symbol version each native binary requires
# (Rocky 8 floor is 2.28) and show the size distribution of node_modules.
N="${STAGE_DIR:-$HOME/dsh-linux-build}/app/node_modules"

echo "== objdump available? =="
command -v objdump || { echo "BINUTILS_MISSING"; exit 0; }

echo "== max GLIBC symbol version per native binary (Rocky8 floor: 2.28) =="
find "$N" \( -name "*.node" -o -path "*esbuild*" -name esbuild -type f \) -print0 2>/dev/null |
while IFS= read -r -d "" f; do
  v=$(objdump -T "$f" 2>/dev/null | grep -oE "GLIBC_[0-9.]+" | sort -V | tail -1)
  [ -z "$v" ] && v="(no glibc syms)"
  printf "%s  <-  %s\n" "$v" "${f#$N/}"
done

echo "== top 12 biggest packages in node_modules =="
du -sh "$N"/* 2>/dev/null | sort -rh | head -12

echo "== total =="
du -sh "$N" 2>/dev/null