#!/usr/bin/env bash
# Re-extract the four tarballs into dist/linux, each into its own dir
# (all tarballs share the top dir name dsh-linux-x64 -> --strip-components=1).
cd /mnt/d/Exercise/AI/dsh/dsh-linux/dist/linux || exit 1
extract() { # $1 = tarball, $2 = target dir
  local tmp="$2.tmp"
  rm -rf "$tmp" "$2"
  mkdir -p "$tmp"
  tar -xzf "$1" -C "$tmp" --strip-components=1
  mv "$tmp" "$2"
}
extract dsh-linux-x64.tar.gz dsh-linux-x64
extract dsh-linux-x64-slim.tar.gz dsh-linux-x64-slim
extract dsh-linux-x64-basic.tar.gz dsh-linux-x64-basic
extract dsh-linux-x64-basic-slim.tar.gz dsh-linux-x64-basic-slim
ls -d dsh-linux-x64*
echo "--- check-env + smoke per extracted dir ---"
for d in dsh-linux-x64 dsh-linux-x64-slim dsh-linux-x64-basic dsh-linux-x64-basic-slim; do
  if [ -x "$d/bin/check-env.sh" ]; then echo "OK   $d/bin/check-env.sh"; else echo "MISS $d"; fi
done
echo "--- full dir version + bwrap ---"
./dsh-linux-x64/bin/dsh --version
./dsh-linux-x64/bin/bwrap --version