#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
KEYMAP_FILE=${1:-"$ROOT_DIR/keymap.toml"}
OUTPUT_FILE=${2:-"$ROOT_DIR/yazi-keybind-cheatsheet.png"}

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
  echo "Generated: $(date '+%Y-%m-%d %H:%M')"
  echo ""
  echo "Custom Keybinds (from keymap.toml prepend_keymap)"
  echo ""
  printf "  %-16s %s\n" "KEY" "DESCRIPTION"
  printf "  %-16s %s\n" "----------------" "----------------------------------------------"

  awk '
    /^[[:space:]]*\{ on = / {
      line = $0

      on = line
      sub(/^[[:space:]]*\{ on = /, "", on)
      sub(/, run = .*/, "", on)
      gsub(/\[/, "", on)
      gsub(/\]/, "", on)
      gsub(/"/, "", on)
      gsub(/,/, "", on)
      gsub(/[[:space:]]+/, " ", on)
      sub(/^ /, "", on)
      sub(/ $/, "", on)

      desc = line
      sub(/.*desc = "/, "", desc)
      sub(/".*/, "", desc)

      printf("  %-16s %s\\n", on, desc)
    }
  ' "$KEYMAP_FILE"

  echo ""
  echo "Important Default Yazi Keys You Kept"
  echo ""
  echo "  .                Toggle hidden files"
  echo "  <Tab>            Spot hovered file"
  echo "  D                Permanently delete selected files"
  echo "  r                Rename selected file(s)"
  echo "  m + key          Line info mode family"
  echo "  , + key          Sorting family"
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
  -interline-spacing 6 \
  -size 1800x \
  caption:@"$TMP_TEXT" \
  -bordercolor "#1F2937" \
  -border 24 \
  "$OUTPUT_FILE"

echo "Wrote cheatsheet image: $OUTPUT_FILE"
