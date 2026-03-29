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

upload_0x0() {
  local path=$1
  local response http_code body
  response=$(curl -sS -m 90 -w $'\n%{http_code}' -F "file=@${path}" https://0x0.st || true)
  http_code=${response##*$'\n'}
  body=${response%$'\n'*}
  body=$(printf '%s' "$body" | tr -d '\r\n')

  if [[ "$http_code" == "200" && "$body" == https://* ]]; then
    printf '%s\n' "$body"
    return 0
  fi

  return 1
}

upload_catbox() {
  local path=$1
  local body
  body=$(curl -sS -m 90 -F "reqtype=fileupload" -F "fileToUpload=@${path}" https://catbox.moe/user/api.php || true)
  body=$(printf '%s' "$body" | tr -d '\r\n')

  if [[ "$body" == https://* ]]; then
    printf '%s\n' "$body"
    return 0
  fi

  return 1
}

upload_ix() {
  local path=$1
  local body
  body=$(curl -sS -m 90 -F "f:1=@${path}" https://ix.io || true)
  body=$(printf '%s' "$body" | tr -d '\r\n')

  if [[ "$body" == https://* || "$body" == http://* ]]; then
    printf '%s\n' "$body"
    return 0
  fi

  return 1
}

upload_pasters() {
  local path=$1
  local body
  body=$(curl -sS -m 90 --data-binary "@${path}" https://paste.rs/ || true)
  body=$(printf '%s' "$body" | tr -d '\r\n')

  if [[ "$body" == https://* || "$body" == http://* ]]; then
    printf '%s\n' "$body"
    return 0
  fi

  return 1
}

upload_tmpfiles() {
  local path=$1
  local body url
  body=$(curl -sS -m 90 -F "file=@${path}" https://tmpfiles.org/api/v1/upload || true)
  url=$(printf '%s' "$body" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

  if [[ "$url" == https://* ]]; then
    printf '%s\n' "$url"
    return 0
  fi

  return 1
}

upload_with_fallback() {
  local path=$1
  local link

  if link=$(upload_0x0 "$path"); then
    printf '%s\n' "$link"
    return 0
  fi

  if link=$(upload_catbox "$path"); then
    printf '%s\n' "$link"
    return 0
  fi

  if link=$(upload_ix "$path"); then
    printf '%s\n' "$link"
    return 0
  fi

  if link=$(upload_pasters "$path"); then
    printf '%s\n' "$link"
    return 0
  fi

  if link=$(upload_tmpfiles "$path"); then
    printf '%s\n' "$link"
    return 0
  fi

  return 1
}

links=()
skipped_count=0

for path in "$@"; do
  if [[ ! -f "$path" ]]; then
    echo "Skipping (not a regular file): $path" >&2
    skipped_count=$((skipped_count + 1))
    continue
  fi

  if ! link=$(upload_with_fallback "$path"); then
    echo "Upload failed on all providers: $path" >&2
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
