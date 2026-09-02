#!/usr/bin/env bash
T=/home/sinply/dsh-linux-build/tarballs
echo "=== 0-byte or tiny tarballs ==="
find "$T" -name '*.tgz' -size -1k | head
echo "=== validate each tarball parses (tar -tzf exit code) ==="
bad=0
for f in "$T"/*.tgz; do
  tar -tzf "$f" > /dev/null 2>&1 || { echo "BAD: $f"; bad=$((bad+1)); }
done
echo "bad count: $bad (total $(ls "$T"/*.tgz | wc -l))"