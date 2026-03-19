#!/usr/bin/env bash
set -euo pipefail

preserve_mode=0
if [[ ${1:-} == "--preserve" ]]; then
  preserve_mode=1
  shift
fi

if [[ $# -lt 2 ]]; then
  echo "Select at least 2 images first." >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick is required (magick command not found)." >&2
  exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

meta_file="$tmp_dir/meta.tsv"

# Keep only regular image files and collect width/height metadata.
for path in "$@"; do
  [[ -f "$path" ]] || continue

  mime=$(file --mime-type -b -- "$path" 2>/dev/null || true)
  [[ "$mime" == image/* ]] || continue

  identify_out=$(magick identify -quiet -format "%w %h" -- "$path" 2>/dev/null || true)
  if [[ -z "$identify_out" ]]; then
    continue
  fi

  width=${identify_out%% *}
  height=${identify_out##* }
  if ! [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || [[ "$height" -eq 0 ]]; then
    continue
  fi

  ratio=$(awk -v w="$width" -v h="$height" 'BEGIN { printf "%.10f", w / h }')
  area=$((width * height))

  printf '%s\t%s\t%s\t%s\t%s\n' "$path" "$width" "$height" "$ratio" "$area" >> "$meta_file"
done

if [[ ! -s "$meta_file" ]]; then
  echo "No valid images found in selection." >&2
  exit 1
fi

median() {
  sort -n | awk '
    { a[NR] = $1 }
    END {
      if (NR == 0) exit 1
      if (NR % 2 == 1) {
        print a[(NR + 1) / 2]
      } else {
        print (a[NR / 2] + a[NR / 2 + 1]) / 2
      }
    }
  '
}

median_ratio=$(awk -F '\t' '{ print $4 }' "$meta_file" | median)
median_area=$(awk -F '\t' '{ print $5 }' "$meta_file" | median)
median_width=$(awk -F '\t' '{ print $2 }' "$meta_file" | median)
median_height=$(awk -F '\t' '{ print $3 }' "$meta_file" | median)

accepted_file="$tmp_dir/accepted.tsv"
while IFS=$'\t' read -r path width height ratio area; do
  keep=$(awk -v r="$ratio" -v rm="$median_ratio" -v a="$area" -v am="$median_area" -v preserve="$preserve_mode" '
    BEGIN {
      if (preserve == 1) {
        ratio_ok = (r >= rm * 0.35 && r <= rm * 2.80)
        area_ok = (a >= am * 0.12 && a <= am * 8.00)
      } else {
        ratio_ok = (r >= rm * 0.55 && r <= rm * 1.80)
        area_ok = (a >= am * 0.20 && a <= am * 5.00)
      }
      print (ratio_ok && area_ok) ? 1 : 0
    }
  ')

  if [[ "$keep" == "1" ]]; then
    printf '%s\t%s\t%s\n' "$path" "$width" "$height" >> "$accepted_file"
  fi
done < "$meta_file"

if [[ ! -s "$accepted_file" ]]; then
  awk -F '\t' '{ printf "%s\t%s\t%s\n", $1, $2, $3 }' "$meta_file" > "$accepted_file"
fi

accepted_count=$(wc -l < "$accepted_file" | tr -d ' ')
if (( accepted_count < 2 )); then
  echo "Need at least 2 usable images after filtering." >&2
  exit 1
fi

target_width=$(awk -v w="$median_width" 'BEGIN { v = int(w + 0.5); if (v < 240) v = 240; if (v > 900) v = 900; print v }')
target_height=$(awk -v h="$median_height" 'BEGIN { v = int(h + 0.5); if (v < 180) v = 180; if (v > 900) v = 900; print v }')
preserve_height=$(awk -v h="$median_height" 'BEGIN { v = int(h + 0.5); if (v < 260) v = 260; if (v > 700) v = 700; print v }')

cols=$(awk -v n="$accepted_count" 'BEGIN { c = int(sqrt(n)); if (c * c < n) c++; if (c < 1) c = 1; print c }')

declare -a tiles=()
index=0
while IFS=$'\t' read -r path _w _h; do
  tile="$tmp_dir/tile-$index.png"
  if (( preserve_mode == 1 )); then
    magick -- "$path" \
      -auto-orient \
      -resize "x${preserve_height}" \
      -background '#101418' \
      "$tile"
  else
    magick -- "$path" \
      -auto-orient \
      -resize "${target_width}x${target_height}" \
      -gravity center \
      -background '#101418' \
      -extent "${target_width}x${target_height}" \
      "$tile"
  fi
  tiles+=("$tile")
  index=$((index + 1))
done < "$accepted_file"

output="${XDG_RUNTIME_DIR:-/tmp}/yazi-collage-clipboard.png"
magick montage "${tiles[@]}" \
  -tile "${cols}x" \
  -geometry +8+8 \
  -background '#101418' \
  -bordercolor '#101418' \
  -border 8 \
  "$output"

if command -v wl-copy >/dev/null 2>&1; then
  if ! wl-copy --type image/png < "$output"; then
    echo "wl-copy failed. Check that Wayland clipboard is available." >&2
    exit 1
  fi
elif command -v xclip >/dev/null 2>&1; then
  if ! xclip -selection clipboard -t image/png -i "$output"; then
    echo "xclip failed. Check that X clipboard is available." >&2
    exit 1
  fi
elif command -v xsel >/dev/null 2>&1; then
  if ! xsel --clipboard --input < "$output"; then
    echo "xsel failed. Check that X clipboard is available." >&2
    exit 1
  fi
else
  echo "No clipboard tool found. Install wl-clipboard, xclip, or xsel." >&2
  exit 1
fi

echo "Copied collage to clipboard: $accepted_count images -> $output"
