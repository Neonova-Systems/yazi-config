#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: chat-context-pack.sh <file-path> [file-path...]" >&2
  exit 1
fi

get_language() {
  local path=$1
  local ext=${path##*.}
  
  case "$ext" in
    py) echo "python" ;;
    js) echo "javascript" ;;
    ts) echo "typescript" ;;
    tsx) echo "typescript" ;;
    jsx) echo "javascript" ;;
    sh) echo "bash" ;;
    bash) echo "bash" ;;
    zsh) echo "bash" ;;
    c) echo "c" ;;
    cpp|cc|cxx) echo "cpp" ;;
    h|hpp) echo "cpp" ;;
    go) echo "go" ;;
    rs) echo "rust" ;;
    java) echo "java" ;;
    kt) echo "kotlin" ;;
    cs) echo "csharp" ;;
    php) echo "php" ;;
    rb) echo "ruby" ;;
    lua) echo "lua" ;;
    sql) echo "sql" ;;
    json) echo "json" ;;
    yaml|yml) echo "yaml" ;;
    toml) echo "toml" ;;
    xml) echo "xml" ;;
    html|htm) echo "html" ;;
    css) echo "css" ;;
    scss) echo "scss" ;;
    md|markdown) echo "markdown" ;;
    txt) echo "text" ;;
    *) echo "" ;;
  esac
}

bundle=""
file_count=0
skipped_count=0

for path in "$@"; do
  if [[ ! -f "$path" ]]; then
    echo "Skipping (not a file): $path" >&2
    skipped_count=$((skipped_count + 1))
    continue
  fi

  mime=$(file --mime-type -b -- "$path" 2>/dev/null || true)
  if [[ "$mime" == application/octet-stream ]] || [[ "$mime" =~ binary ]]; then
    echo "Skipping (binary file): $path" >&2
    skipped_count=$((skipped_count + 1))
    continue
  fi

  content=$(cat "$path" 2>/dev/null || true)
  if [[ -z "$content" ]]; then
    echo "Skipping (empty file): $path" >&2
    skipped_count=$((skipped_count + 1))
    continue
  fi

  lang=$(get_language "$path")
  
  if [[ -n "$bundle" ]]; then
    bundle+=$'\n\n'
  fi
  
  bundle+="## $path"$'\n'
  bundle+="\`\`\`$lang"$'\n'
  bundle+="$content"$'\n'
  bundle+="\`\`\`"
  
  file_count=$((file_count + 1))
done

if [[ $file_count -eq 0 ]]; then
  echo "No valid files to pack." >&2
  exit 1
fi

if command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$bundle" | wl-copy --type text/plain
elif command -v xclip >/dev/null 2>&1; then
  printf '%s' "$bundle" | xclip -selection clipboard
elif command -v xsel >/dev/null 2>&1; then
  printf '%s' "$bundle" | xsel --clipboard --input
else
  echo "No clipboard tool found. Install wl-clipboard, xclip, or xsel." >&2
  exit 1
fi

echo "Packed $file_count file(s) to clipboard (skipped: $skipped_count)"
