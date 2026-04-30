#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Select at least two PDF files to join." >&2
  exit 1
fi

paths=()
for p in "$@"; do
  [[ -f "$p" ]] || continue
  mime=$(file --mime-type -b -- "$p" 2>/dev/null || true)
  if [[ "$mime" == application/pdf || "${p##*.}" =~ [Pp][Dd][Ff] ]]; then
    paths+=("$p")
  fi
done

if (( ${#paths[@]} < 2 )); then
  echo "Need at least 2 PDF files after filtering." >&2
  exit 1
fi

out_dir=${paths[0]%/*}
if [[ "$out_dir" == "$paths[0]" ]]; then
  out_dir="$PWD"
fi
out_file="$out_dir/combined-$(date +%Y%m%d-%H%M%S).pdf"

if command -v pdfunite >/dev/null 2>&1; then
  pdfunite "${paths[@]}" "$out_file"
  echo "Created: $out_file"
elif command -v gs >/dev/null 2>&1; then
  gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile="$out_file" "${paths[@]}"
  echo "Created: $out_file"
else
  echo "pdfunite or ghostscript (gs) is required to join PDFs." >&2
  exit 1
fi
