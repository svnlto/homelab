#!/usr/bin/env bash
# shellcheck disable=SC2029  # REMOTE_PATH is intentionally expanded client-side
# K8s CronJob variant of rsync-photos.sh
# Environment variables from dumper-config Secret:
#   REMOTE_HOST=100.x.x.x
#   REMOTE_USER=admin
#   REMOTE_PATH=/path/to/photos/
# Environment variables for OTLP logging:
#   OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz-otel-collector.signoz.svc:4318
#   OTEL_SERVICE_NAME=dumper

set -euo pipefail

DUMP_DIR="/mnt/dump"
STATE_DIR="/cache"
FILE_LIST="${STATE_DIR}/rsync-filelist.txt"
FILE_LIST_MAX_AGE=86400 # rebuild if older than 24h

SSH_OPTS=(-i /secrets/ssh/id_ed25519 -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o ServerAliveInterval=15 -o ServerAliveCountMax=3)

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
            {key: "k8s.cronjob.name", value: {stringValue: "dumper"}}
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

# Check if remote host is reachable via Tailscale (DERP relay is fine)
PING_OUT=$(tailscale ping --timeout=30s --c=1 "${REMOTE_HOST}" 2>&1 || true)
if ! echo "$PING_OUT" | grep -q "pong"; then
  echo "Remote host ${REMOTE_HOST} is not reachable, skipping sync"
  otel_log WARN "Remote host unreachable, skipping sync" \
    "sync.status=skipped" "remote.host=${REMOTE_HOST}"
  exit 0
fi

# Rebuild file list if missing or older than threshold
if [ ! -f "${FILE_LIST}" ] ||
  [ "$(($(date +%s) - $(stat -c %Y "${FILE_LIST}")))" -gt ${FILE_LIST_MAX_AGE} ]; then
  echo "Building remote file list..."
  ssh "${SSH_OPTS[@]}" "${REMOTE_USER}@${REMOTE_HOST}" \
    "sudo find '${REMOTE_PATH}' \
      -type f -print" |
    sed "s|^${REMOTE_PATH}||" \
      >"${FILE_LIST}.tmp"
  mv "${FILE_LIST}.tmp" "${FILE_LIST}"
  FILE_COUNT=$(wc -l <"${FILE_LIST}")
  echo "File list rebuilt: ${FILE_COUNT} files"
  otel_log INFO "File list rebuilt" \
    "files.count=${FILE_COUNT}" "remote.host=${REMOTE_HOST}"
else
  echo "File list cached ($(wc -l <"${FILE_LIST}") files, max age ${FILE_LIST_MAX_AGE}s)"
fi

FILE_COUNT=$(wc -l <"${FILE_LIST}")
echo "Starting rsync of ${FILE_COUNT} files to ${DUMP_DIR}${REMOTE_PATH}"
otel_log INFO "Rsync started" \
  "files.count=${FILE_COUNT}" "remote.host=${REMOTE_HOST}"

RSYNC_START=$SECONDS
if rsync -rltv --partial --inplace --omit-dir-times \
  --chmod=D755,F644 \
  --files-from="${FILE_LIST}" \
  --rsync-path="sudo /usr/bin/rsync" \
  -e "ssh ${SSH_OPTS[*]}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}" \
  "${DUMP_DIR}${REMOTE_PATH}"; then
  DURATION=$((SECONDS - RSYNC_START))
  echo "Rsync complete in ${DURATION}s"
  otel_log INFO "Rsync complete" \
    "sync.status=success" "files.count=${FILE_COUNT}" \
    "remote.host=${REMOTE_HOST}" "duration_seconds=${DURATION}"
else
  RSYNC_EXIT=$?
  DURATION=$((SECONDS - RSYNC_START))
  echo "ERROR: Rsync failed with exit code ${RSYNC_EXIT} after ${DURATION}s"
  otel_log ERROR "Rsync failed (exit ${RSYNC_EXIT})" \
    "sync.status=error" "files.count=${FILE_COUNT}" \
    "remote.host=${REMOTE_HOST}" "duration_seconds=${DURATION}"
  exit "${RSYNC_EXIT}"
fi
