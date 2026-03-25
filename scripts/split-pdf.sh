#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: split-pdf.sh <pdf-file> <chunks>" >&2
  echo "  chunks: number of files to split into (e.g., 2 for splitting in half)" >&2
  exit 1
fi

pdf_path=$1
chunks=$2

if [[ ! -f "$pdf_path" ]]; then
  echo "Error: File not found: $pdf_path" >&2
  exit 1
fi

mime=$(file --mime-type -b -- "$pdf_path" 2>/dev/null || true)
if [[ "$mime" != "application/pdf" ]]; then
  echo "Error: Not a PDF file: $pdf_path" >&2
  exit 1
fi

# Get total pages
if command -v pdfinfo >/dev/null 2>&1; then
  total_pages=$(pdfinfo "$pdf_path" | grep "Pages:" | awk '{print $2}')
elif command -v gs >/dev/null 2>&1; then
  total_pages=$(gs -q -dNODISPLAY -dNOSAFER -c "($pdf_path) (r) file runpdfbegin pdfpagecount = quit" 2>/dev/null || echo "")
else
  echo "Error: pdfinfo or ghostscript not found" >&2
  exit 1
fi

if [[ -z "$total_pages" ]] || [[ $total_pages -le 0 ]]; then
  echo "Error: Could not determine page count" >&2
  exit 1
fi

# Calculate pages per chunk
pages_per_chunk=$(( (total_pages + chunks - 1) / chunks ))

echo "Splitting $total_pages pages into $chunks chunks (~$pages_per_chunk pages each)" >&2

# Get directory and filename
dir=$(dirname "$pdf_path")
filename=$(basename "$pdf_path" .pdf)

# Use pdftk or gs to split
if command -v pdfjam >/dev/null 2>&1; then
  # Use pdfjam (from TeX Live)
  chunk_num=1
  start_page=1

  while [[ $start_page -le $total_pages ]]; do
    end_page=$(( start_page + pages_per_chunk - 1 ))
    if [[ $end_page -gt $total_pages ]]; then
      end_page=$total_pages
    fi

    output="$dir/${filename}_part_${chunk_num}.pdf"
    pdfjam "$pdf_path" "$start_page-$end_page" -o "$output" 2>/dev/null
    echo "Created: ${filename}_part_${chunk_num}.pdf (pages $start_page-$end_page)" >&2

    chunk_num=$((chunk_num + 1))
    start_page=$((end_page + 1))
  done

elif command -v gs >/dev/null 2>&1; then
  # Use ghostscript
  chunk_num=1
  start_page=1

  while [[ $start_page -le $total_pages ]]; do
    end_page=$(( start_page + pages_per_chunk - 1 ))
    if [[ $end_page -gt $total_pages ]]; then
      end_page=$total_pages
    fi

    output="$dir/${filename}_part_${chunk_num}.pdf"
    gs -sDEVICE=pdfwrite \
       -dNOPAUSE \
       -dQUIET \
       -dBATCH \
       -dFirstPage=$start_page \
       -dLastPage=$end_page \
       -sOutputFile="$output" \
       "$pdf_path" 2>/dev/null
    
    echo "Created: ${filename}_part_${chunk_num}.pdf (pages $start_page-$end_page)" >&2

    chunk_num=$((chunk_num + 1))
    start_page=$((end_page + 1))
  done

else
  echo "Error: pdfjam or ghostscript not found" >&2
  exit 1
fi

echo "Split complete!" >&2
