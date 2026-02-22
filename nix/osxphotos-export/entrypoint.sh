#!/usr/bin/env bash
set -euo pipefail

# Install osxphotos via pip on first run (cached in /cache/pip)
if ! command -v osxphotos &>/dev/null; then
  echo "Installing osxphotos..."
  # Downgrade pip first — pip 25.x bundles packaging>=24.2 which strictly
  # rejects non-PEP 440 platform versions like "6.18.5-talos" (Talos kernel).
  pip install --no-cache-dir --break-system-packages 'pip<25'
  pip install --no-cache-dir --break-system-packages osxphotos
fi

exec /bin/bash /app/export-photos.sh
