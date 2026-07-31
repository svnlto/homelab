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
#   METRICS_PORT=9184    (Prometheus endpoint; set to 0 to disable)
#   METRICS_DIR=/cache/www
# Environment variables for OTLP logging:
#   OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz-otel-collector.signoz.svc:4318
#   OTEL_SERVICE_NAME=osxphotos-export

set -euo pipefail

LIBRARY_PATH="${LIBRARY_PATH:-/mnt/source/Photos Library.photoslibrary}"
EXPORT_DEST="${EXPORT_DEST:-/mnt/export}"
EXPORT_DB_PATH="${EXPORT_DB_PATH:-/cache/osxphotos_export.db}"
SYNC_INTERVAL="${SYNC_INTERVAL:-3600}"
RETRY_INTERVAL="${RETRY_INTERVAL:-300}"
METRICS_PORT="${METRICS_PORT:-9184}"
METRICS_DIR="${METRICS_DIR:-/cache/www}"

# On the cache PVC so a restart doesn't reset the staleness alert.
LAST_SUCCESS_FILE="${LAST_SUCCESS_FILE:-/cache/.last_success_ts}"
LAST_SUCCESS=$(cat "${LAST_SUCCESS_FILE}" 2>/dev/null || echo 0)

# Written via rename so a scrape never reads a partial file.
write_metrics() {
  local ok="$1" duration="$2" exported="$3" skipped="$4" errors="$5"
  local now tmp
  now=$(date +%s)

  if [ "$ok" -eq 1 ]; then
    LAST_SUCCESS="$now"
    echo "$now" >"${LAST_SUCCESS_FILE}"
  fi

  tmp=$(mktemp "${METRICS_DIR}/.metrics.XXXXXX")
  cat >"$tmp" <<EOF
# HELP osxphotos_export_last_run_timestamp_seconds Unix time of the last completed export attempt.
# TYPE osxphotos_export_last_run_timestamp_seconds gauge
osxphotos_export_last_run_timestamp_seconds ${now}
# HELP osxphotos_export_last_success_timestamp_seconds Unix time of the last successful export.
# TYPE osxphotos_export_last_success_timestamp_seconds gauge
osxphotos_export_last_success_timestamp_seconds ${LAST_SUCCESS}
# HELP osxphotos_export_last_run_success Whether the most recent export attempt succeeded.
# TYPE osxphotos_export_last_run_success gauge
osxphotos_export_last_run_success ${ok}
# HELP osxphotos_export_duration_seconds Duration of the last export attempt.
# TYPE osxphotos_export_duration_seconds gauge
osxphotos_export_duration_seconds ${duration}
# HELP osxphotos_export_photos_exported Photos exported by the last attempt.
# TYPE osxphotos_export_photos_exported gauge
osxphotos_export_photos_exported ${exported}
# HELP osxphotos_export_photos_skipped Photos already up to date at the last attempt.
# TYPE osxphotos_export_photos_skipped gauge
osxphotos_export_photos_skipped ${skipped}
# HELP osxphotos_export_photos_errors Errors reported by osxphotos in the last attempt.
# TYPE osxphotos_export_photos_errors gauge
osxphotos_export_photos_errors ${errors}
EOF
  mv -f "$tmp" "${METRICS_DIR}/metrics"
}

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

mkdir -p "${METRICS_DIR}"
if [ "${METRICS_PORT}" != "0" ]; then
  darkhttpd "${METRICS_DIR}" --port "${METRICS_PORT}" --daemon --no-listing
  echo "  Metrics:  :${METRICS_PORT}/metrics"
fi
# Answer scrapes before the first export finishes.
write_metrics 0 0 0 0 0

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
    --exiftool \
    --exportdb "${EXPORT_DB_PATH}" \
    --ramdb \
    --verbose \
    2>&1 | tee "$EXPORT_LOG" || EXPORT_EXIT=$?

  DURATION=$((SECONDS - EXPORT_START))

  # Parse export summary from osxphotos output
  EXPORTED=$(grep -oP 'Exported: \K\d+' "$EXPORT_LOG" 2>/dev/null || echo "0")
  SKIPPED=$(grep -oP 'Skipped: \K\d+' "$EXPORT_LOG" 2>/dev/null || echo "0")
  ERRORS=$(grep -oP 'Errors: \K\d+' "$EXPORT_LOG" 2>/dev/null || echo "0")

  rm -f "$EXPORT_LOG"

  if [ "$EXPORT_EXIT" -eq 0 ]; then
    write_metrics 1 "$DURATION" "$EXPORTED" "$SKIPPED" "$ERRORS"
    echo "Export complete: ${EXPORTED} exported, ${SKIPPED} skipped in ${DURATION}s"
    otel_log INFO "Export complete: ${EXPORTED} exported, ${SKIPPED} skipped in ${DURATION}s" \
      "export.status=success" "photos.exported=${EXPORTED}" \
      "photos.skipped=${SKIPPED}" "photos.errors=${ERRORS}" \
      "duration_seconds=${DURATION}"
    echo "Next export in ${SYNC_INTERVAL}s"
    sleep "${SYNC_INTERVAL}"
  else
    write_metrics 0 "$DURATION" "$EXPORTED" "$SKIPPED" "$ERRORS"
    echo "ERROR: Export failed (exit ${EXPORT_EXIT}) after ${DURATION}s — retrying in ${RETRY_INTERVAL}s"
    otel_log ERROR "Export failed (exit ${EXPORT_EXIT}) after ${DURATION}s" \
      "export.status=error" "photos.exported=${EXPORTED}" \
      "photos.skipped=${SKIPPED}" "photos.errors=${ERRORS}" \
      "duration_seconds=${DURATION}"
    sleep "${RETRY_INTERVAL}"
  fi

done
