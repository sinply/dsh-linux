#!/usr/bin/env bash
# WSL verification: check-env.sh present in all variants and runnable from the bundle.
STAGE="$HOME/dsh-linux-build"
echo "=== 1. check-env.sh presence per variant bundle ==="
for v in bundle bundle-slim basic-bundled basic-slim; do
  f="$STAGE/$v/dsh-linux-x64/bin/check-env.sh"
  if [ -x "$f" ]; then echo "  OK   $v: $(wc -c < "$f") bytes"
  else echo "  MISS $v"; fi
done

echo
echo "=== 2. run check-env.sh from the FULL bundle (as a file) ==="
"$STAGE/bundle/dsh-linux-x64/bin/check-env.sh"
echo "check-env exit=$?"