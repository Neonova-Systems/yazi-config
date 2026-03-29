#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Select at least one file or directory first." >&2
  exit 1
fi

if ! command -v dragon-drop >/dev/null 2>&1; then
  echo "dragon-drop not found. Install it first." >&2
  exit 1
fi

# Use NUL delimiters so paths with spaces/newlines are handled safely.
printf '%s\0' "$@" | xargs -0 -- dragon-drop --on-top
