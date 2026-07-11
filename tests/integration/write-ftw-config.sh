#!/usr/bin/env bash
set -euo pipefail

backend="${1:?backend name required}"
port="${2:?port required}"
logfile="tests/logs/${backend}/audit.log"

sed -E \
    -e "s|^logfile: tests/logs/[^/]+/audit\\.log$|logfile: ${logfile}|" \
    -e "s|^    port: [0-9]+$|    port: ${port}|" \
    tests/integration/.ftw.yml > tests/integration/.ftw.yml.new
mv tests/integration/.ftw.yml.new tests/integration/.ftw.yml
cat tests/integration/.ftw.yml
