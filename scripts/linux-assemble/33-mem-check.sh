#!/usr/bin/env bash
echo "=== cgroup memory limit ==="
cat /sys/fs/cgroup/memory.max 2>/dev/null || cat /sys/fs/cgroup/memory.limit_in_bytes 2>/dev/null || echo "(cgroup v1/v2 均不可读)"
echo "=== meminfo ==="
head -3 /proc/meminfo
echo "=== 磁盘 ==="
df -h /home | tail -1