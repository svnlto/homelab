#!/usr/bin/env bash
# shellcheck disable=SC2029  # REMOTE_PATH is intentionally expanded client-side
# Long-running rsync sync script for K8s Deployment.
# Syncs continuously, reconnecting on failure.
# Environment variables from dumper-config Secret:
#   REMOTE_HOST=100.x.x.x
#   REMOTE_USER=admin
#   REMOTE_PATH=/path/to/photos/
# Environment variables for OTLP logging:
#   OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz-otel-collector.signoz.svc:4318
#   OTEL_SERVICE_NAME=dumper
# Environment variables for tuning:
#   SYNC_INTERVAL=3600   (seconds between successful syncs)
#   RETRY_INTERVAL=300   (seconds to wait after a failure)
#   RSYNC_PARALLEL=8     (number of concurrent rsync streams)

set -euo pipefail

DUMP_DIR="/mnt/dump"
STATE_DIR="/cache"
FILE_LIST="${STATE_DIR}/missing-originals.txt"
SYNC_INTERVAL="${SYNC_INTERVAL:-3600}"
RETRY_INTERVAL="${RETRY_INTERVAL:-300}"
RSYNC_PARALLEL="${RSYNC_PARALLEL:-8}"

SSH_OPTS=(-i /secrets/ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30 -o ServerAliveInterval=30 -o ServerAliveCountMax=10 -o Ciphers=aes128-gcm@openssh.com -o IPQoS=throughput)

# Format bytes into a human-readable string (B, KB, MB, GB)
_human_bytes() {
  local bytes=$1
  if [ "$bytes" -ge 1073741824 ]; then
    echo "$(( bytes / 1073741824 )).$(( (bytes % 1073741824) * 10 / 1073741824 )) GB"
  elif [ "$bytes" -ge 1048576 ]; then
    echo "$(( bytes / 1048576 )).$(( (bytes % 1048576) * 10 / 1048576 )) MB"
  elif [ "$bytes" -ge 1024 ]; then
    echo "$(( bytes / 1024 )) KB"
  else
    echo "${bytes} B"
  fi
}

# Send a structured log record to the OTEL collector via HTTP/JSON.
# Usage: otel_log SEVERITY "message" [key=value ...]
otel_log() {
  local severity="$1" body="$2"
  shift 2

  # Map severity text to OTLP severity number
  local severity_number
  case "$severity" in
    INFO)  severity_number=9  ;;
    WARN)  severity_number=13 ;;
    ERROR) severity_number=17 ;;
    *)     severity_number=0  ;;
  esac

  # Build attributes array from remaining key=value arguments
  local attrs="[]"
  if [ $# -gt 0 ]; then
    attrs=$(printf '%s\n' "$@" | jq -Rn '[inputs | split("=") | {key: .[0], value: {stringValue: .[1:] | join("=")}}]')
  fi

  local payload
  payload=$(jq -n \
    --arg body "$body" \
    --arg sev "$severity" \
    --argjson sev_num "$severity_number" \
    --arg svc "${OTEL_SERVICE_NAME:-dumper}" \
    --argjson attrs "$attrs" \
    --arg ts "$(date +%s)000000000" \
    '{
      resourceLogs: [{
        resource: {
          attributes: [
            {key: "service.name", value: {stringValue: $svc}},
            {key: "k8s.deployment.name", value: {stringValue: "dumper"}}
          ]
        },
        scopeLogs: [{
          scope: {name: "dumper-rsync"},
          logRecords: [{
            timeUnixNano: $ts,
            severityNumber: $sev_num,
            severityText: $sev,
            body: {stringValue: $body},
            attributes: $attrs
          }]
        }]
      }]
    }')

  # Fire-and-forget: don't let logging failures break the script
  curl -sf -X POST \
    "${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}/v1/logs" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null 2>&1 || true
}

# Wait for Tailscale sidecar to connect (max 5 minutes)
echo "Waiting for Tailscale sidecar to connect..."
DEADLINE=$((SECONDS + 300))
while [ $SECONDS -lt $DEADLINE ]; do
  if tailscale status >/dev/null 2>&1; then
    echo "Tailscale connected"
    otel_log INFO "Tailscale connected"
    break
  fi
  sleep 5
done
if ! tailscale status >/dev/null 2>&1; then
  echo "ERROR: Tailscale did not connect within 5 minutes"
  otel_log ERROR "Tailscale did not connect within 5 minutes" "sync.status=error"
  exit 1
fi

# ── Main sync loop ──────────────────────────────────────────────────
while true; do

  # Check if remote host is reachable via Tailscale (DERP relay is fine)
  PING_OUT=$(tailscale ping --timeout=30s --c=1 "${REMOTE_HOST}" 2>&1 || true)
  if ! echo "$PING_OUT" | grep -q "pong"; then
    echo "Remote host ${REMOTE_HOST} is not reachable, retrying in ${RETRY_INTERVAL}s"
    otel_log WARN "Remote host unreachable — retrying in ${RETRY_INTERVAL}s" \
      "sync.status=skipped" "remote.host=${REMOTE_HOST}"
    sleep "${RETRY_INTERVAL}"
    continue
  fi

  # ── Phase 1: Sync database + resources directories ─────────────────
  LIB_PATH="${REMOTE_PATH%/}"
  LOCAL_LIB="${DUMP_DIR}${REMOTE_PATH}"
  DB="${LOCAL_LIB}/database/Photos.sqlite"

  echo "Phase 1: Syncing database/ and resources/ from remote..."
  otel_log INFO "Phase 1: syncing database/ and resources/" \
    "sync.phase=1" "remote.host=${REMOTE_HOST}"

  PHASE1_EXIT=0
  rsync -rlt --partial --inplace --omit-dir-times \
    --timeout=300 \
    --chmod=D755,F644 \
    --rsync-path="sudo /usr/local/bin/rsync" \
    -e "ssh ${SSH_OPTS[*]}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${LIB_PATH}/database/" \
    "${LOCAL_LIB}/database/" 2>&1 || PHASE1_EXIT=$?

  if [ "$PHASE1_EXIT" -ne 0 ]; then
    echo "ERROR: Phase 1 database sync failed (exit ${PHASE1_EXIT}) — retrying in ${RETRY_INTERVAL}s"
    otel_log ERROR "Phase 1 database sync failed (exit ${PHASE1_EXIT})" \
      "sync.phase=1" "sync.status=error" "remote.host=${REMOTE_HOST}"
    sleep "${RETRY_INTERVAL}"
    continue
  fi

  rsync -rlt --partial --inplace --omit-dir-times \
    --timeout=300 \
    --chmod=D755,F644 \
    --rsync-path="sudo /usr/local/bin/rsync" \
    -e "ssh ${SSH_OPTS[*]}" \
    "${REMOTE_USER}@${REMOTE_HOST}:${LIB_PATH}/resources/" \
    "${LOCAL_LIB}/resources/" 2>&1 || true

  # WAL checkpoint: consolidate SQLite databases so consumers get consistent reads
  while IFS= read -r -d '' db; do
    if sqlite3 "$db" "PRAGMA integrity_check;" >/dev/null 2>&1; then
      sqlite3 "$db" "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true
      rm -f "${db}-wal" "${db}-shm"
    fi
  done < <(find "${LOCAL_LIB}/database" -name '*.sqlite' -print0 2>/dev/null)

  echo "Phase 1 complete: database/ and resources/ synced"
  otel_log INFO "Phase 1 complete" "sync.phase=1" "sync.status=success"

  # ── Phase 2: Build targeted file list from Photos.sqlite ──────────
  echo "Phase 2: Querying Photos.sqlite for missing originals..."

  ALL_ORIGINALS="${STATE_DIR}/all-originals.txt"
  PRESENT="${STATE_DIR}/present-originals.txt"

  if [ -f "$DB" ] && sqlite3 "$DB" "SELECT COUNT(*) FROM ZASSET LIMIT 1;" >/dev/null 2>&1; then
    sqlite3 "$DB" \
      "SELECT 'Photos Library.photoslibrary/originals/' || ZDIRECTORY || '/' || ZFILENAME
       FROM ZASSET
       WHERE ZTRASHEDSTATE = 0 AND ZDIRECTORY IS NOT NULL AND ZFILENAME IS NOT NULL;" \
      | sort > "${ALL_ORIGINALS}"

    TOTAL_ORIGINALS=$(wc -l < "${ALL_ORIGINALS}")
    echo "Photos.sqlite reports ${TOTAL_ORIGINALS} originals"

    # Find originals already present on disk
    ORIGINALS_DIR="${LOCAL_LIB}/originals"
    if [ -d "$ORIGINALS_DIR" ]; then
      find "$ORIGINALS_DIR" -type f \
        | sed "s|^${DUMP_DIR}${REMOTE_PATH}||" \
        | sort > "${PRESENT}"
    else
      : > "${PRESENT}"
    fi

    # Set difference: originals in DB but not on disk
    comm -23 "${ALL_ORIGINALS}" "${PRESENT}" > "${FILE_LIST}"
    FILE_COUNT=$(wc -l < "${FILE_LIST}")

    echo "Missing originals: ${FILE_COUNT} / ${TOTAL_ORIGINALS}"
    otel_log INFO "Phase 2: ${FILE_COUNT} missing originals (${TOTAL_ORIGINALS} total)" \
      "sync.phase=2" "files.missing=${FILE_COUNT}" "files.total_originals=${TOTAL_ORIGINALS}" \
      "remote.host=${REMOTE_HOST}"
  else
    echo "WARN: Photos.sqlite not available or unreadable — falling back to full originals sync"
    otel_log WARN "Photos.sqlite unavailable — falling back to full originals sync" \
      "sync.phase=2" "remote.host=${REMOTE_HOST}"

    # Fallback: sync entire originals directory without a file list
    rsync -rlt --partial --inplace --omit-dir-times \
      --skip-compress=jpg,jpeg,heic,heif,png,mp4,mov,gif,webp,cr2,nef,arw,dng \
      --timeout=300 \
      --chmod=D755,F644 \
      --rsync-path="sudo /usr/local/bin/rsync" \
      -e "ssh ${SSH_OPTS[*]}" \
      "${REMOTE_USER}@${REMOTE_HOST}:${LIB_PATH}/originals/" \
      "${LOCAL_LIB}/originals/" 2>&1 || true

    echo "Fallback sync complete. Next sync in ${SYNC_INTERVAL}s"
    sleep "${SYNC_INTERVAL}"
    continue
  fi

  # Skip rsync if all originals are present
  if [ "$FILE_COUNT" -eq 0 ]; then
    echo "All originals present — nothing to sync"
    otel_log INFO "All originals present — skipping rsync" \
      "sync.phase=2" "sync.status=success" "files.missing=0" \
      "files.total_originals=${TOTAL_ORIGINALS}" "remote.host=${REMOTE_HOST}"
    echo "Next sync in ${SYNC_INTERVAL}s"
    sleep "${SYNC_INTERVAL}"
    continue
  fi

  # ── Phase 2b: Parallel rsync of missing originals ────────────────
  echo "Starting rsync of ${FILE_COUNT} missing originals to ${DUMP_DIR}${REMOTE_PATH}"
  otel_log INFO "Rsync started: ${FILE_COUNT} missing originals from ${REMOTE_HOST}" \
    "files.count=${FILE_COUNT}" "remote.host=${REMOTE_HOST}"

  RSYNC_START=$SECONDS
  CHUNK_DIR="${STATE_DIR}/chunks"
  PROGRESS_INTERVAL=60 # send progress OTel log every 60 seconds

  # Split file list into N chunks for parallel rsync streams
  rm -rf "$CHUNK_DIR"
  mkdir -p "$CHUNK_DIR"
  split -n "l/${RSYNC_PARALLEL}" "${FILE_LIST}" "${CHUNK_DIR}/chunk-"

  # Background progress reporter: aggregates across all per-stream log files.
  # --out-format '%i %l %n' produces: <itemize-flags> <file-size-bytes> <filename>
  _progress_reporter() {
    local last_checked=0
    while true; do
      sleep "${PROGRESS_INTERVAL}"
      local checked=0 transferred=0 xfer_bytes=0 last_file=""
      for log in "${CHUNK_DIR}"/rsync-transfer-*.log; do
        [ -f "$log" ] || continue
        local c t b
        c=$(wc -l <"$log" 2>/dev/null) || c=0
        checked=$((checked + ${c:-0}))
        t=$(grep -c '^>' "$log" 2>/dev/null) || t=0
        transferred=$((transferred + ${t:-0}))
        b=$(grep '^>' "$log" 2>/dev/null | awk '{s+=$2} END {print s+0}') || b=0
        xfer_bytes=$((xfer_bytes + ${b:-0}))
        local lf
        lf=$(tail -1 "$log" 2>/dev/null | awk '{$1=$2=""; sub(/^  /,""); print}' || echo "")
        [ -n "$lf" ] && last_file="$lf"
      done
      if [ "$checked" -gt "$last_checked" ]; then
        local pct=0
        if [ "${FILE_COUNT}" -gt 0 ]; then
          pct=$(( (checked * 100) / FILE_COUNT ))
        fi
        local elapsed=$((SECONDS - RSYNC_START))
        local speed="0.0"
        if [ "$elapsed" -gt 0 ] && [ "$xfer_bytes" -gt 0 ]; then
          speed=$(awk "BEGIN {printf \"%.1f\", ${xfer_bytes} / 1048576 / ${elapsed}}")
        fi
        local xfer_bytes_human
        xfer_bytes_human=$(_human_bytes "$xfer_bytes")
        echo "Progress: ${checked}/${FILE_COUNT} (${pct}%), ${xfer_bytes_human} transferred, ${speed} MB/s [${RSYNC_PARALLEL} streams] | ${last_file}"
        otel_log INFO "Rsync progress: ${checked}/${FILE_COUNT} (${pct}%), ${xfer_bytes_human} transferred, ${speed} MB/s [${RSYNC_PARALLEL} streams] | ${last_file}" \
          "sync.status=in_progress" \
          "files.checked=${checked}" "files.transferred=${transferred}" \
          "files.total=${FILE_COUNT}" "sync.percent=${pct}" \
          "bytes.transferred=${xfer_bytes}" "transfer.speed_mbps=${speed}" \
          "rsync.streams=${RSYNC_PARALLEL}" \
          "current.file=${last_file}" "remote.host=${REMOTE_HOST}" \
          "duration_seconds=${elapsed}"
        last_checked=$checked
      fi
    done
  }

  _progress_reporter &
  PROGRESS_PID=$!

  # Launch parallel rsync streams, one per chunk file.
  # --out-format '%i %l %n': itemize flags, file size in bytes, filename.
  # Lines starting with ">" are transferred; lines starting with "." are skipped.
  RSYNC_PIDS=()
  STREAM_IDX=0
  for chunk in "${CHUNK_DIR}"/chunk-*; do
    [ -f "$chunk" ] || continue
    # Skip empty chunks (can happen if file list < RSYNC_PARALLEL)
    [ -s "$chunk" ] || continue
    STREAM_LOG="${CHUNK_DIR}/rsync-transfer-${STREAM_IDX}.log"
    STREAM_ERR="${CHUNK_DIR}/rsync-error-${STREAM_IDX}.log"
    : >"$STREAM_LOG"
    : >"$STREAM_ERR"
    rsync -rlt --partial --inplace --omit-dir-times \
      --skip-compress=jpg,jpeg,heic,heif,png,mp4,mov,gif,webp,cr2,nef,arw,dng \
      --timeout=300 \
      --chmod=D755,F644 \
      --itemize-changes \
      --out-format='%i %l %n' \
      --files-from="$chunk" \
      --rsync-path="sudo /usr/local/bin/rsync" \
      -e "ssh ${SSH_OPTS[*]}" \
      "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}" \
      "${DUMP_DIR}${REMOTE_PATH}" \
      >>"$STREAM_LOG" 2>>"$STREAM_ERR" &
    RSYNC_PIDS+=($!)
    STREAM_IDX=$((STREAM_IDX + 1))
    # Stagger stream starts to avoid overwhelming Tailscale
    sleep 2
  done

  # Wait for all rsync streams and collect exit codes
  RSYNC_EXIT=0
  for pid in "${RSYNC_PIDS[@]}"; do
    STREAM_EXIT=0
    wait "$pid" || STREAM_EXIT=$?
    if [ "$STREAM_EXIT" -ne 0 ] && [ "$RSYNC_EXIT" -eq 0 ]; then
      RSYNC_EXIT=$STREAM_EXIT
    fi
  done

  kill $PROGRESS_PID 2>/dev/null || true
  wait $PROGRESS_PID 2>/dev/null || true

  # Aggregate stats across all stream logs
  CHECKED=0
  TRANSFERRED=0
  TOTAL_BYTES=0
  for log in "${CHUNK_DIR}"/rsync-transfer-*.log; do
    [ -f "$log" ] || continue
    local_checked=$(wc -l <"$log" 2>/dev/null) || local_checked=0
    CHECKED=$((CHECKED + ${local_checked:-0}))
    local_transferred=$(grep -c '^>' "$log" 2>/dev/null) || local_transferred=0
    TRANSFERRED=$((TRANSFERRED + ${local_transferred:-0}))
    local_bytes=$(grep '^>' "$log" 2>/dev/null | awk '{s+=$2} END {print s+0}') || local_bytes=0
    TOTAL_BYTES=$((TOTAL_BYTES + ${local_bytes:-0}))
  done
  DURATION=$((SECONDS - RSYNC_START))
  AVG_SPEED="0.0"
  if [ "$DURATION" -gt 0 ] && [ "$TOTAL_BYTES" -gt 0 ]; then
    AVG_SPEED=$(awk "BEGIN {printf \"%.1f\", ${TOTAL_BYTES} / 1048576 / ${DURATION}}")
  fi
  TOTAL_BYTES_HUMAN=$(_human_bytes "$TOTAL_BYTES")

  rm -rf "$CHUNK_DIR"

  if [ "$RSYNC_EXIT" -eq 0 ]; then
    echo "Rsync complete: ${TRANSFERRED} files, ${TOTAL_BYTES_HUMAN} in ${DURATION}s (${AVG_SPEED} MB/s)"
    otel_log INFO "Rsync complete: ${TRANSFERRED} files, ${TOTAL_BYTES_HUMAN} in ${DURATION}s (${AVG_SPEED} MB/s)" \
      "sync.status=success" "files.total=${FILE_COUNT}" \
      "files.checked=${CHECKED}" "files.transferred=${TRANSFERRED}" \
      "bytes.transferred=${TOTAL_BYTES}" "transfer.speed_mbps=${AVG_SPEED}" \
      "remote.host=${REMOTE_HOST}" "duration_seconds=${DURATION}"
    echo "Next sync in ${SYNC_INTERVAL}s"
    sleep "${SYNC_INTERVAL}"
  else
    echo "ERROR: Rsync failed (exit ${RSYNC_EXIT}): ${CHECKED} checked, ${TRANSFERRED} transferred in ${DURATION}s — retrying in ${RETRY_INTERVAL}s"
    otel_log ERROR "Rsync failed (exit ${RSYNC_EXIT}): ${CHECKED} checked, ${TRANSFERRED} transferred in ${DURATION}s — retrying in ${RETRY_INTERVAL}s" \
      "sync.status=error" "files.total=${FILE_COUNT}" \
      "files.checked=${CHECKED}" "files.transferred=${TRANSFERRED}" \
      "bytes.transferred=${TOTAL_BYTES}" "transfer.speed_mbps=${AVG_SPEED}" \
      "remote.host=${REMOTE_HOST}" "duration_seconds=${DURATION}"
    sleep "${RETRY_INTERVAL}"
  fi

done
