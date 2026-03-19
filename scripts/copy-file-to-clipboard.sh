#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: copy-file-to-clipboard.sh <path>" >&2
  exit 1
fi

path=$1
if [[ ! -f "$path" ]]; then
  echo "Not a regular file: $path" >&2
  exit 1
fi

mime=$(file --mime-type -b -- "$path" 2>/dev/null || echo "application/octet-stream")

if command -v wl-copy >/dev/null 2>&1; then
  wl-copy --type "$mime" < "$path"
elif command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard -t "$mime" -i "$path"
elif command -v xsel >/dev/null 2>&1; then
  xsel --clipboard --input < "$path"
else
  echo "No clipboard tool found. Install wl-clipboard, xclip, or xsel." >&2
  exit 1
fi

echo "Copied to clipboard: $path ($mime)"
