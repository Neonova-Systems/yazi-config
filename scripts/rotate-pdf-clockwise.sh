#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: rotate-pdf-clockwise.sh <pdf-path>" >&2
  exit 1
fi

path="$1"
if [[ ! -f "$path" ]]; then
  echo "Not a file: $path" >&2
  exit 1
fi

mime=$(file --mime-type -b -- "$path" 2>/dev/null || true)
if [[ "$mime" != application/pdf && ! "${path##*.}" =~ [Pp][Dd][Ff] ]]; then
  echo "Not a PDF: $path" >&2
  exit 1
fi

dir=${path%/*}
if [[ "$dir" == "$path" ]]; then
  dir="$PWD"
fi
out="$dir/rotated-$(basename "$path" .pdf)-$(date +%Y%m%d-%H%M%S).pdf"

if command -v qpdf >/dev/null 2>&1; then
  qpdf "$path" --rotate=+90:1-z -- "$out"
  echo "Created: $out"
  exit 0
fi

if command -v pdftk >/dev/null 2>&1; then
  pdftk "$path" cat 1-endeast output "$out"
  echo "Created: $out"
  exit 0
fi

echo "qpdf or pdftk is required to rotate PDFs. Install one of them." >&2
exit 1
