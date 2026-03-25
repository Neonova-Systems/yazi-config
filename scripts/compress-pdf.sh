#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: compress-pdf.sh <pdf-file> [pdf-file...]" >&2
  exit 1
fi

for pdf_path in "$@"; do
  if [[ ! -f "$pdf_path" ]]; then
    echo "Skipping (not a file): $pdf_path" >&2
    continue
  fi

  mime=$(file --mime-type -b -- "$pdf_path" 2>/dev/null || true)
  if [[ "$mime" != "application/pdf" ]]; then
    echo "Skipping (not a PDF): $pdf_path" >&2
    continue
  fi

  # Get original file size
  original_size=$(stat -f%z "$pdf_path" 2>/dev/null || stat -c%s "$pdf_path" 2>/dev/null || true)

  # Create output filename
  dir=$(dirname "$pdf_path")
  filename=$(basename "$pdf_path" .pdf)
  output="$dir/${filename}_compressed.pdf"

  # Compress with ghostscript
  if command -v gs >/dev/null 2>&1; then
    gs -sDEVICE=pdfwrite \
       -dCompatibilityLevel=1.4 \
       -dPDFSETTINGS=/ebook \
       -dNOPAUSE \
       -dQUIET \
       -dBATCH \
       -dDetectDuplicateImages \
       -r150 \
       -o "$output" \
       "$pdf_path" 2>/dev/null || {
      echo "Error compressing: $pdf_path" >&2
      continue
    }

    # Get compressed file size
    if [[ -n "$original_size" ]]; then
      compressed_size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null || true)
      ratio=$((compressed_size * 100 / original_size))
      echo "Compressed: $pdf_path -> ${filename}_compressed.pdf ($ratio% of original)" >&2
    else
      echo "Compressed: $pdf_path -> ${filename}_compressed.pdf" >&2
    fi
  else
    echo "ghostscript not found. Install gs to compress PDFs." >&2
    exit 1
  fi
done
