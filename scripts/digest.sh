#!/usr/bin/env bash
# Print a stable sha256 digest of a directory: hash of each file's path and
# content, sorted. Works on Linux runners (sha256sum) and macOS (shasum).
set -euo pipefail

dir="${1:?usage: digest.sh <dir>}"

if command -v sha256sum >/dev/null 2>&1; then
  sha() { sha256sum; }
else
  sha() { shasum -a 256; }
fi

digest=$(
  cd "$dir"
  find . -type f -print | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s  %s\n' "$(sha < "$f" | cut -d' ' -f1)" "$f"
  done | sha | cut -d' ' -f1
)
echo "sha256:${digest}"
