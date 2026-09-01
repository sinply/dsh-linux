#!/usr/bin/env bash
# Step 8: inspect the real exports of dsh-sandbox-local (installed bundle app)
set -e
STAGE="${STAGE_DIR:-$HOME/dsh-linux-build}"
APP="$STAGE/app/node_modules"
export PATH="$STAGE/node/bin:$PATH"
node -e '
const m = require(process.argv[1]);
console.log("exports:", Object.keys(m));
' "$APP/@deepseek-ai/dsh-sandbox-local/lib/index.js"