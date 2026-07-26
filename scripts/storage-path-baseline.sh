#!/usr/bin/env bash
# Capture CRS310 + cluster storage-path metrics. Run before and after the
# migration to prove the fix worked. Usage: storage-path-baseline.sh <label>
set -euo pipefail

LABEL="${1:?usage: storage-path-baseline.sh <label>}"
OUT="/tmp/storage-path-${LABEL}-$(date +%Y%m%d-%H%M%S).txt"
H="https://192.168.0.1"

: "${MIKROTIK_USERNAME:?run under: op run --env-file=.op-env.tpl -- $0}"
: "${MIKROTIK_PASSWORD:?}"

mt() { curl -sk -m 15 -u "$MIKROTIK_USERNAME:$MIKROTIK_PASSWORD" "$H/rest/$1"; }

{
  echo "=== label: $LABEL  at: $(date -Iseconds) ==="
  echo "--- system/resource ---"
  mt "system/resource"
  echo
  echo "--- system/resource/cpu ---"
  mt "system/resource/cpu"
  echo
  echo "--- interface counters ---"
  mt "interface"
} > "$OUT"

echo "wrote $OUT"
