#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
KEYMAP_FILE=${1:-"$ROOT_DIR/keymap.toml"}
OUTPUT_FILE=${2:-"$ROOT_DIR/yazi-keybind-cheatsheet.png"}
GENERATED_AT=$(date '+%Y-%m-%d %H:%M')

if [ ! -f "$KEYMAP_FILE" ]; then
  echo "Keymap file not found: $KEYMAP_FILE" >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' command not found." >&2
  exit 1
fi

TMP_TEXT=$(mktemp)
trap 'rm -f "$TMP_TEXT"' EXIT

{
  echo "YAZI KEYBIND CHEATSHEET"
  echo "Generated: $GENERATED_AT"
  echo ""
  echo "Custom Keybinds (from keymap.toml prepend_keymap)"
  echo ""

  awk -v key_w=18 -v desc_w=64 '
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

    /^[[:space:]]*\{ on = / {
      line = $0

      on = line
      sub(/^[[:space:]]*\{ on = /, "", on)
      sub(/, run = .*/, "", on)
      gsub(/\[/, "", on)
      gsub(/\]/, "", on)
      gsub(/"/, "", on)
      gsub(/,/, "", on)
      on = trim(on)
      gsub(/[[:space:]]+/, " ", on)

      desc = line
      sub(/.*desc = "/, "", desc)
      sub(/".*/, "", desc)

      row(on, desc)
    }

    END {
      print b
    }
  ' "$KEYMAP_FILE"

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
  echo "Notes"
  echo ""
  echo "  - dd/dr are custom lf-style trash workflows from your keymap."
  echo "  - g-bookmarks include both lf favorites and yazi defaults."
} > "$TMP_TEXT"

magick \
  -background "#0B1220" \
  -fill "#E6EDF3" \
  -font "DejaVu-Sans-Mono" \
  -pointsize 24 \
  -interline-spacing 4 \
  label:@"$TMP_TEXT" \
  -bordercolor "#1F2937" \
  -border 24 \
  "$OUTPUT_FILE"

echo "Wrote cheatsheet image: $OUTPUT_FILE"
