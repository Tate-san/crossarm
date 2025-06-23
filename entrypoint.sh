#!/usr/bin/env bash
set -e

for f in /etc/profile.d/*.sh; do
  [ -r "$f" ] && source "$f"
done

rsync -avrq "${TOOLCHAIN_DIR}/" "${CROSS_SYSROOT_DIR}/"

if [ $# -eq 0 ]; then
  exec bash -i
else
  exec bash -i -c "$*"
fi