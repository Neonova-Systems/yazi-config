#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: compress-video.sh [profile] <video-path> [video-path...]" >&2
  echo "Profiles: 1(light), 2(balanced), 3(strong), 4(tiny), 5(hevc)" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found. Install ffmpeg first." >&2
  exit 1
fi

profile=2
case "${1:-}" in
  1|2|3|4|5|light|balanced|strong|tiny|hevc)
    profile="$1"
    shift
    ;;
esac

if [[ $# -lt 1 ]]; then
  echo "No input video paths provided." >&2
  exit 1
fi

video_codec=libx264
preset=medium
crf=28
audio_bitrate=128k
resize_filter=

case "$profile" in
  1|light)
    preset=veryfast
    crf=25
    audio_bitrate=160k
    profile_label="light"
    ;;
  2|balanced)
    preset=medium
    crf=28
    audio_bitrate=128k
    profile_label="balanced"
    ;;
  3|strong)
    preset=slow
    crf=31
    audio_bitrate=112k
    profile_label="strong"
    ;;
  4|tiny)
    preset=slow
    crf=34
    audio_bitrate=96k
    resize_filter='scale=-2:720:flags=lanczos'
    profile_label="tiny"
    ;;
  5|hevc)
    video_codec=libx265
    preset=medium
    crf=29
    audio_bitrate=112k
    profile_label="hevc"
    ;;
  *)
    echo "Unknown profile: $profile" >&2
    exit 1
    ;;
esac

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
  output="$dir/${stem}-compressed-${profile_label}.mp4"

  if [[ -e "$output" ]]; then
    echo "Skipping (output exists): $output"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  echo "Compressing: $path"

  ffmpeg_cmd=(
    ffmpeg -hide_banner -loglevel error -stats -i "$path"
    -map 0:v:0 -map 0:a?
    -c:v "$video_codec" -preset "$preset" -crf "$crf"
    -c:a aac -b:a "$audio_bitrate"
  )

  if [[ -n "$resize_filter" ]]; then
    ffmpeg_cmd+=(-vf "$resize_filter")
  fi

  ffmpeg_cmd+=(-movflags +faststart "$output")

  if "${ffmpeg_cmd[@]}"; then
    echo "Created: $output"
    compressed_count=$((compressed_count + 1))
  else
    echo "Failed: $path" >&2
    rm -f -- "$output"
    skipped_count=$((skipped_count + 1))
  fi
done

echo "Done ($profile_label profile). Compressed: $compressed_count, Skipped: $skipped_count"
