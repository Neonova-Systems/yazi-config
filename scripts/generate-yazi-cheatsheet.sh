#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  generate-yazi-cheatsheet.sh [keymap.toml] [output.png]
  generate-yazi-cheatsheet.sh --watch [keymap.toml] [output.png]

Options:
  -w, --watch    Auto-regenerate when keymap file changes.
  -h, --help     Show this help.
EOF
}

WATCH_MODE=0
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--watch)
      WATCH_MODE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}"

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
KEYMAP_FILE=${1:-"$ROOT_DIR/keymap.toml"}
OUTPUT_FILE=${2:-"$ROOT_DIR/yazi-keybind-cheatsheet.png"}

if [ ! -f "$KEYMAP_FILE" ]; then
  echo "Keymap file not found: $KEYMAP_FILE" >&2
  exit 1
fi

if ! command -v tomlq >/dev/null 2>&1; then
  echo "'tomlq' command (from kislyuk/yq) not found." >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' command not found." >&2
  exit 1
fi

generate_once() {
  local generated_at tmp_text tmp_binds

  generated_at=$(date '+%Y-%m-%d %H:%M')
  tmp_text=$(mktemp)
  tmp_binds=$(mktemp)

  tomlq -r '
    (.mgr.prepend_keymap // [])[]
    | [
        ((.on | if type == "array" then join(" ") else . end) // ""),
        (.desc // "")
      ]
    | @tsv
  ' "$KEYMAP_FILE" > "$tmp_binds"

  {
    echo "YAZI KEYBIND CHEATSHEET"
    echo "Generated: $generated_at"
    echo ""
    echo "Custom Keybinds (from keymap.toml prepend_keymap)"
    echo ""

  awk -F'\t' -v key_w=18 -v desc_w=64 '
    function trim(s) {
      sub(/^[[:space:]]+/, "", s)
      sub(/[[:space:]]+$/, "", s)
      return s
    }

    function border(ch, i, s) {
      s = "+"
      for (i = 0; i < key_w + 2; i++) s = s ch
      s = s "+"
      for (i = 0; i < desc_w + 2; i++) s = s ch
      s = s "+"
      return s
    }

    function row(k, d, words, n, i, line, first, candidate) {
      k = trim(k)
      d = trim(d)
      gsub(/[[:space:]]+/, " ", d)

      n = split(d, words, / /)
      line = ""
      first = 1

      for (i = 1; i <= n; i++) {
        candidate = (line == "" ? words[i] : line " " words[i])
        if (length(candidate) > desc_w) {
          printf("| %-*s | %-*s |\n", key_w, (first ? k : ""), desc_w, line)
          line = words[i]
          first = 0
        } else {
          line = candidate
        }
      }

      if (line == "") line = d
      printf("| %-*s | %-*s |\n", key_w, (first ? k : ""), desc_w, line)
    }

    BEGIN {
      b = border("-")
      print b
      printf("| %-*s | %-*s |\n", key_w, "KEY", desc_w, "DESCRIPTION")
      print b
    }

    {
      on = $1
      desc = $2
      row(on, desc)
    }

    END {
      print b
    }
  ' "$tmp_binds"

  echo ""
  echo "Important Default Yazi Keys You Kept"
  awk -v key_w=18 -v desc_w=64 '
    function border(ch, i, s) {
      s = "+"
      for (i = 0; i < key_w + 2; i++) s = s ch
      s = s "+"
      for (i = 0; i < desc_w + 2; i++) s = s ch
      s = s "+"
      return s
    }

    BEGIN {
      b = border("-")
      print b
      printf("| %-*s | %-*s |\n", key_w, "KEY", desc_w, "DESCRIPTION")
      print b

      printf("| %-*s | %-*s |\n", key_w, ".", desc_w, "Toggle hidden files")
      printf("| %-*s | %-*s |\n", key_w, "<Tab>", desc_w, "Spot hovered file")
      printf("| %-*s | %-*s |\n", key_w, "D", desc_w, "Permanently delete selected files")
      printf("| %-*s | %-*s |\n", key_w, "r", desc_w, "Rename selected file(s)")
      printf("| %-*s | %-*s |\n", key_w, "m + key", desc_w, "Line info mode family")
      printf("| %-*s | %-*s |\n", key_w, ", + key", desc_w, "Sorting family")

      print b
    }
  '

  echo ""
  } > "$tmp_text"

  magick \
    -background "#0B1220" \
    -fill "#E6EDF3" \
    -font "DejaVu-Sans-Mono" \
    -pointsize 24 \
    -interline-spacing 4 \
    label:@"$tmp_text" \
    -bordercolor "#0B1220" \
    -border 24 \
    "$OUTPUT_FILE"

  rm -f "$tmp_text" "$tmp_binds"
  echo "Wrote cheatsheet image: $OUTPUT_FILE"
}

generate_once

if [[ "$WATCH_MODE" -eq 1 ]]; then
  echo "Watching for changes: $KEYMAP_FILE"

  if command -v inotifywait >/dev/null 2>&1; then
    while inotifywait -qq -e close_write,create,move,delete "$KEYMAP_FILE"; do
      if [[ -f "$KEYMAP_FILE" ]]; then
        generate_once || true
      fi
    done
  else
    echo "inotifywait not found; using polling fallback (2s interval)."

    last_hash=$(sha256sum "$KEYMAP_FILE" | awk '{print $1}')
    while true; do
      sleep 2
      if [[ ! -f "$KEYMAP_FILE" ]]; then
        continue
      fi

      current_hash=$(sha256sum "$KEYMAP_FILE" | awk '{print $1}')
      if [[ "$current_hash" != "$last_hash" ]]; then
        last_hash="$current_hash"
        generate_once || true
      fi
    done
  fi
fi
