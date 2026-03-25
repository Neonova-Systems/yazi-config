#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: compress-video.sh <video-path> [video-path...]" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found. Install ffmpeg first." >&2
  exit 1
fi

compressed_count=0
skipped_count=0

for path in "$@"; do
  if [[ ! -f "$path" ]]; then
    echo "Skipping (not a file): $path"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  mime=$(file --mime-type -b -- "$path" 2>/dev/null || true)
  if [[ "$mime" != video/* ]]; then
    echo "Skipping (not a video): $path"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  dir=${path%/*}
  base=${path##*/}
  stem=${base%.*}
  output="$dir/${stem}-compressed.mp4"

  if [[ -e "$output" ]]; then
    echo "Skipping (output exists): $output"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  echo "Compressing: $path"

  if ffmpeg -hide_banner -loglevel error -stats -i "$path" \
    -map 0:v:0 -map 0:a? \
    -c:v libx264 -preset medium -crf 28 \
    -c:a aac -b:a 128k \
    -movflags +faststart \
    "$output"; then
    echo "Created: $output"
    compressed_count=$((compressed_count + 1))
  else
    echo "Failed: $path" >&2
    rm -f -- "$output"
    skipped_count=$((skipped_count + 1))
  fi
done

echo "Done. Compressed: $compressed_count, Skipped: $skipped_count"
