#!/usr/bin/env bash
# Re-extract the delivered tarballs into the deliverable dir, each into its own
# directory (every tarball has the same top-level name dsh-linux-x64, so each is
# extracted with --strip-components=1 into a variant-named directory).
#
# Optional env:
#   OUT_DIR    deliverable dir (default: <this repo>/dist/linux)
#   VARIANTS   subset of "full slim basic basic-slim" (default: all four)
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${OUT_DIR:-$(cd "$HERE/../.." && pwd)/dist/linux}"
VARIANTS="${VARIANTS:-full slim basic basic-slim}"
cd "$OUT"

extract() { # $1 = tarball, $2 = target dir
  [ -f "$1" ] || { echo "skip (missing): $1"; return 0; }
  local tmp="$2.tmp"
  rm -rf "$tmp" "$2"
  mkdir -p "$tmp"
  tar -xzf "$1" -C "$tmp" --strip-components=1
  mv "$tmp" "$2"
  echo "extracted: $1 -> $2"
}

want() { case " $VARIANTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
if want full; then extract dsh-linux-x64.tar.gz dsh-linux-x64; fi
if want slim; then extract dsh-linux-x64-slim.tar.gz dsh-linux-x64-slim; fi
if want basic; then extract dsh-linux-x64-basic.tar.gz dsh-linux-x64-basic; fi
if want basic-slim; then extract dsh-linux-x64-basic-slim.tar.gz dsh-linux-x64-basic-slim; fi

echo "--- check-env.sh + BUILD-INFO.txt per extracted dir ---"
for d in dsh-linux-x64 dsh-linux-x64-slim dsh-linux-x64-basic dsh-linux-x64-basic-slim; do
  [ -d "$d" ] || continue
  if [ -x "$d/bin/check-env.sh" ]; then echo "OK   $d/bin/check-env.sh"; else echo "MISS $d/bin/check-env.sh"; fi
  if [ -f "$d/BUILD-INFO.txt" ]; then
    echo "     $(grep -m2 'dsh version\|variant' "$d/BUILD-INFO.txt" | tr '\n' ' ')"
  else
    echo "MISS $d/BUILD-INFO.txt"
  fi
done
if [ -x ./dsh-linux-x64/bin/dsh ]; then
  echo "--- full bundle: version + bwrap ---"
  ./dsh-linux-x64/bin/dsh --version
  ./dsh-linux-x64/bin/bwrap --version
fi
