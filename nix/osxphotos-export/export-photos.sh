#!/usr/bin/env bash
# Long-running osxphotos export script for K8s Deployment.
# Exports photos from a macOS Photos library on NFS to an organized directory structure.
# Runs continuously with incremental updates via osxphotos --update.
#
# Environment variables:
#   LIBRARY_PATH=/mnt/source/Photos Library.photoslibrary
#   EXPORT_DEST=/mnt/export
#   EXPORT_DB_PATH=/cache/osxphotos_export.db
#   SYNC_INTERVAL=3600   (seconds between successful exports)
#   RETRY_INTERVAL=300   (seconds to wait after a failure)
# Environment variables for OTLP logging:
#   OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz-otel-collector.signoz.svc:4318
#   OTEL_SERVICE_NAME=osxphotos-export

set -euo pipefail

LIBRARY_PATH="${LIBRARY_PATH:-/mnt/source/Photos Library.photoslibrary}"
EXPORT_DEST="${EXPORT_DEST:-/mnt/export}"
EXPORT_DB_PATH="${EXPORT_DB_PATH:-/cache/osxphotos_export.db}"
SYNC_INTERVAL="${SYNC_INTERVAL:-3600}"
RETRY_INTERVAL="${RETRY_INTERVAL:-300}"

# Send a structured log record to the OTEL collector via HTTP/JSON.
# Usage: otel_log SEVERITY "message" [key=value ...]
otel_log() {
  local severity="$1" body="$2"
  shift 2

  local severity_number
  case "$severity" in
    INFO)  severity_number=9  ;;
    WARN)  severity_number=13 ;;
    ERROR) severity_number=17 ;;
    *)     severity_number=0  ;;
  esac

  local attrs="[]"
  if [ $# -gt 0 ]; then
    attrs=$(printf '%s\n' "$@" | jq -Rn '[inputs | split("=") | {key: .[0], value: {stringValue: .[1:] | join("=")}}]')
  fi

  local payload
  payload=$(jq -n \
    --arg body "$body" \
    --arg sev "$severity" \
    --argjson sev_num "$severity_number" \
    --arg svc "${OTEL_SERVICE_NAME:-osxphotos-export}" \
    --argjson attrs "$attrs" \
    --arg ts "$(date +%s)000000000" \
    '{
      resourceLogs: [{
        resource: {
          attributes: [
            {key: "service.name", value: {stringValue: $svc}},
            {key: "k8s.deployment.name", value: {stringValue: "osxphotos-export"}}
          ]
        },
        scopeLogs: [{
          scope: {name: "osxphotos-export"},
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

  curl -sf -X POST \
    "${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}/v1/logs" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null 2>&1 || true
}

# ── Startup checks ───────────────────────────────────────────────────
echo "osxphotos-export starting"
echo "  Library:  ${LIBRARY_PATH}"
echo "  Dest:     ${EXPORT_DEST}"
echo "  DB:       ${EXPORT_DB_PATH}"
echo "  Interval: ${SYNC_INTERVAL}s"

if [ ! -d "${LIBRARY_PATH}" ]; then
  echo "ERROR: Photos library not found at ${LIBRARY_PATH}"
  otel_log ERROR "Photos library not found at ${LIBRARY_PATH}" "export.status=error"
  exit 1
fi

otel_log INFO "osxphotos-export starting" \
  "library.path=${LIBRARY_PATH}" "export.dest=${EXPORT_DEST}"

# ── Main export loop ─────────────────────────────────────────────────
while true; do

  echo "Starting osxphotos export..."
  EXPORT_START=$SECONDS

  EXPORT_LOG=$(mktemp)
  EXPORT_EXIT=0
  osxphotos export "${EXPORT_DEST}" \
    --library "${LIBRARY_PATH}" \
    --directory "{created.year}/{created.mm}/{created.dd}" \
    --update \
    --export-db "${EXPORT_DB_PATH}" \
    --verbose \
    2>&1 | tee "$EXPORT_LOG" || EXPORT_EXIT=$?

  DURATION=$((SECONDS - EXPORT_START))

  # Parse export summary from osxphotos output
  EXPORTED=$(grep -oP 'Exported: \K\d+' "$EXPORT_LOG" 2>/dev/null || echo "0")
  SKIPPED=$(grep -oP 'Skipped: \K\d+' "$EXPORT_LOG" 2>/dev/null || echo "0")
  ERRORS=$(grep -oP 'Errors: \K\d+' "$EXPORT_LOG" 2>/dev/null || echo "0")

  rm -f "$EXPORT_LOG"

  if [ "$EXPORT_EXIT" -eq 0 ]; then
    echo "Export complete: ${EXPORTED} exported, ${SKIPPED} skipped in ${DURATION}s"
    otel_log INFO "Export complete: ${EXPORTED} exported, ${SKIPPED} skipped in ${DURATION}s" \
      "export.status=success" "photos.exported=${EXPORTED}" \
      "photos.skipped=${SKIPPED}" "photos.errors=${ERRORS}" \
      "duration_seconds=${DURATION}"
    echo "Next export in ${SYNC_INTERVAL}s"
    sleep "${SYNC_INTERVAL}"
  else
    echo "ERROR: Export failed (exit ${EXPORT_EXIT}) after ${DURATION}s — retrying in ${RETRY_INTERVAL}s"
    otel_log ERROR "Export failed (exit ${EXPORT_EXIT}) after ${DURATION}s" \
      "export.status=error" "photos.exported=${EXPORTED}" \
      "photos.skipped=${SKIPPED}" "photos.errors=${ERRORS}" \
      "duration_seconds=${DURATION}"
    sleep "${RETRY_INTERVAL}"
  fi

done
