#!/usr/bin/env bash
set -euo pipefail

# Install osxphotos via pip on first run (cached in /cache/pip)
if ! command -v osxphotos &>/dev/null; then
  echo "Installing osxphotos..."
  pip install --no-cache-dir --break-system-packages osxphotos
fi

exec /bin/bash /app/export-photos.sh
