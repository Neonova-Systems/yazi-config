#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: chat-context-pack-budget.sh <budget> <file-path> [file-path...]" >&2
  echo "Budget: 4, 8, or 16 (in thousands of tokens)" >&2
  exit 1
fi

budget_arg=$1
shift

# Estimate tokens (rough: 1 token ≈ 4 characters)
estimate_tokens() {
  local text="$1"
  echo $((${#text} / 4))
}

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

# Set budget from argument
case "$budget_arg" in
  4) budget=4000 ;;
  8) budget=8000 ;;
  16) budget=16000 ;;
  *) echo "Invalid budget: $budget_arg. Use 4, 8, or 16." >&2; exit 1 ;;
esac

# Collect and validate files
declare -a files
declare -A file_contents
declare -A file_sizes

for path in "$@"; do
  if [[ ! -f "$path" ]]; then
    echo "Skipping (not a file): $path" >&2
    continue
  fi

  mime=$(file --mime-type -b -- "$path" 2>/dev/null || true)
  if [[ "$mime" == application/octet-stream ]] || [[ "$mime" =~ binary ]]; then
    echo "Skipping (binary file): $path" >&2
    continue
  fi

  content=$(cat "$path" 2>/dev/null || true)
  if [[ -z "$content" ]]; then
    echo "Skipping (empty file): $path" >&2
    continue
  fi

  files+=("$path")
  file_contents["$path"]=$content
  file_sizes["$path"]=${#content}
done

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No valid files to pack." >&2
  exit 1
fi

# Sort files by size (largest first) for intelligent truncation
IFS=$'\n' sorted_files=($(for f in "${files[@]}"; do echo "${file_sizes[$f]} $f"; done | sort -rn | cut -d' ' -f2-))

# Build bundle with token limits
bundle=""
current_tokens=$(estimate_tokens "# Chat Context Pack")

for path in "${sorted_files[@]}"; do
  content="${file_contents[$path]}"
  lang=$(get_language "$path")
  
  # Calculate tokens needed for this file entry
  file_entry="## $path"$'\n'""\`\`\`$lang"$'\n'"$content"$'\n'""\`\`\`"
  file_tokens=$(estimate_tokens "$file_entry")
  
  # Account for separator between files
  separator_tokens=$(estimate_tokens $'\n\n')
  total_tokens=$((current_tokens + file_tokens + separator_tokens))
  
  if [[ $total_tokens -le $budget ]]; then
    # File fits entirely
    if [[ -n "$bundle" ]]; then
      bundle+=$'\n\n'
    fi
    bundle+="## $path"$'\n'
    bundle+="\`\`\`$lang"$'\n'
    bundle+="$content"$'\n'
    bundle+="\`\`\`"
    current_tokens=$total_tokens
  else
    # File doesn't fit; try truncating it
    available_tokens=$((budget - current_tokens - separator_tokens - 100))  # 100 token buffer for headers
    
    if [[ $available_tokens -gt 500 ]]; then
      # Truncate file to fit
      available_chars=$((available_tokens * 4))
      truncated="${content:0:$available_chars}"
      truncated+=$'\n'"... (truncated)"
      
      if [[ -n "$bundle" ]]; then
        bundle+=$'\n\n'
      fi
      bundle+="## $path"$'\n'
      bundle+="\`\`\`$lang"$'\n'
      bundle+="$truncated"$'\n'
      bundle+="\`\`\`"
      current_tokens=$((budget - 50))  # Mark as nearly full
      break
    else
      # File too large even when truncated; skip and note
      echo "Stopping: remaining budget insufficient for more files" >&2
      break
    fi
  fi
done

# Add summary
final_tokens=$(estimate_tokens "$bundle")
bundle=$'\n'"# Chat Context Pack"$'\n'"## Tokens: ~$final_tokens / $budget"$'\n'"$bundle"

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

echo "Packed with ~$final_tokens / $budget tokens" >&2
