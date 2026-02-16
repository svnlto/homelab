#!/usr/bin/env bash
# shellcheck disable=SC2029  # REMOTE_PATH is intentionally expanded client-side
# Environment variables from /etc/dumper/rsync.env:
#   REMOTE_HOST=100.x.x.x
#   REMOTE_USER=admin
#   REMOTE_PATH=/path/to/photos/

DUMP_DIR="/mnt/dump"
STATE_DIR="/var/lib/dumper"
FILE_LIST="${STATE_DIR}/rsync-filelist.txt"
FILE_LIST_MAX_AGE=86400 # rebuild if older than 24h

SSH_OPTS=(-i "${STATE_DIR}/.ssh/id_ed25519" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=30 -o ServerAliveInterval=15 -o ServerAliveCountMax=3)

# Check if remote host is reachable via Tailscale (DERP relay is fine)
PING_OUT=$(tailscale ping --timeout=30s --c=1 "${REMOTE_HOST}" 2>&1 || true)
if ! echo "$PING_OUT" | grep -q "pong"; then
  echo "Remote host ${REMOTE_HOST} is not reachable, skipping sync"
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
  echo "File list rebuilt: $(wc -l <"${FILE_LIST}") files"
else
  echo "File list cached ($(wc -l <"${FILE_LIST}") files, max age ${FILE_LIST_MAX_AGE}s)"
fi

echo "Starting rsync of $(wc -l <"${FILE_LIST}") files to ${DUMP_DIR}${REMOTE_PATH}"
rsync -rltv --partial --inplace --omit-dir-times \
  --chmod=D755,F644 \
  --files-from="${FILE_LIST}" \
  --rsync-path="sudo /usr/bin/rsync" \
  -e "ssh ${SSH_OPTS[*]}" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}" \
  "${DUMP_DIR}${REMOTE_PATH}"
