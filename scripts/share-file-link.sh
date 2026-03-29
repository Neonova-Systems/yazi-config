#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: share-file-link.sh <file-path> [file-path...]" >&2
  echo "Select at least one file in yazi first." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found. Install curl first." >&2
  exit 1
fi

links=()
skipped_count=0

for path in "$@"; do
  if [[ ! -f "$path" ]]; then
    echo "Skipping (not a regular file): $path" >&2
    skipped_count=$((skipped_count + 1))
    continue
  fi

  link=$(curl -fsS -F "file=@${path}" https://0x0.st || true)
  link=$(printf '%s' "$link" | tr -d '\r\n')

  if [[ -z "$link" ]]; then
    echo "Upload failed: $path" >&2
    skipped_count=$((skipped_count + 1))
    continue
  fi

  links+=("$link")
done

if [[ ${#links[@]} -eq 0 ]]; then
  echo "No files were uploaded." >&2
  exit 1
fi

output=$(printf '%s\n' "${links[@]}")

if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$output" | wl-copy --type text/plain
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$output" | xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
  printf '%s' "$output" | xsel --clipboard --input
else
  echo "No clipboard tool found. Install wl-clipboard, xclip, or xsel." >&2
  exit 1
fi

uploaded_count=${#links[@]}
echo "Uploaded $uploaded_count file(s) (skipped: $skipped_count). Link(s) copied to clipboard:"
printf '%s\n' "${links[@]}"
