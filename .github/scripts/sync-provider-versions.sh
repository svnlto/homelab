#!/usr/bin/env bash
set -euo pipefail

# Detect provider version changes from the latest commit and sync them
# across all infrastructure files using tfupdate.

declare -A PROVIDERS

for file in $(git diff --name-only HEAD~1 HEAD -- 'infrastructure/**'); do
  [[ "$file" == *versions.tf || "$file" == *provider.hcl ]] || continue

  current_source=""
  while IFS= read -r line; do
    if [[ "$line" =~ source[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
      current_source="${BASH_REMATCH[1]}"
    fi
    if [[ "$line" =~ version[[:space:]]*=[[:space:]]*\"[~\>\<\=\!]*[[:space:]]*([0-9][0-9\.]*)\" ]]; then
      if [[ -n "$current_source" ]]; then
        PROVIDERS["$current_source"]="${BASH_REMATCH[1]}"
        current_source=""
      fi
    fi
  done < "$file"
done

for source in "${!PROVIDERS[@]}"; do
  echo "Syncing $source to ${PROVIDERS[$source]}"
  tfupdate provider "$source" -v "${PROVIDERS[$source]}" -r ./infrastructure/
done
