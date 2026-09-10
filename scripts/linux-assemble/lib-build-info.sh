#!/usr/bin/env bash
# Shared helper: stamp a BUILD-INFO.txt into an assembled bundle so an operator
# can read the dsh version / upstream commit of a tarball without extracting it.
# Sourced by 04-assemble.sh and 10-assemble-slim.sh.

# write_build_info <bundle_dir> <variant> <runtime_line>
#   bundle_dir    bundle root (receives BUILD-INFO.txt)
#   variant       human-readable variant name, e.g. "full (bundled Node.js)"
#   runtime_line  runtime description, e.g. "v22.23.2 (bundled)"
write_build_info() {
  local bundle="$1" variant="$2" runtime="$3"
  local installed=""
  if [ -f "$STAGE/app/node_modules/@deepseek-ai/dsh/package.json" ]; then
    installed="$("$STAGE/node/bin/node" -p \
      'require(process.argv[1]).version' \
      "$STAGE/app/node_modules/@deepseek-ai/dsh/package.json" 2>/dev/null || true)"
  fi
  # Written through a temp file + rename: 11-assemble-basic.sh hardlinks its
  # source bundle, and an in-place truncate would rewrite the source's file too.
  cat > "$bundle/BUILD-INFO.txt.tmp" <<EOF
dsh-linux — offline DeepSeek Harness distribution
variant         : $variant
dsh version     : ${PACKAGE_VERSION:-${installed:-unknown}}
upstream commit : ${UPSTREAM_COMMIT:-unknown}${UPSTREAM_TAG:+ ($UPSTREAM_TAG)}
runtime node    : $runtime
built (UTC)     : ${BUILD_DATE:-unknown}
source          : https://github.com/sinply/dsh-linux
EOF
  mv -f "$bundle/BUILD-INFO.txt.tmp" "$bundle/BUILD-INFO.txt"
  echo "BUILD-INFO.txt written ($bundle/BUILD-INFO.txt)"
}
