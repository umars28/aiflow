#!/bin/sh
set -eu

root="${1:-$PWD}"
doc="$root/.aiflow/05-review.md"

if [ ! -f "$doc" ]; then
  printf '  \033[31m✗\033[0m .aiflow/05-review.md was never written\n'
  exit 1
fi

if grep -qiE 'no findings|nothing found|clean' "$doc"; then
  printf '  \033[32m✓\033[0m clean, no findings\n'
  exit 0
fi

findings=$(grep -ciE '^[[:space:]]*[-*0-9].*:[0-9]+' "$doc" || true)
rated=$(grep -ciE 'confidence' "$doc" || true)

if [ "$findings" -eq 0 ]; then
  printf '  \033[31m✗\033[0m does not declare clean, but no located findings are readable\n'
  exit 1
fi

printf '  \033[33m!\033[0m %s findings\n' "$findings"

if [ "$rated" -lt "$findings" ]; then
  printf '  \033[31m✗\033[0m %s of %s findings have no confidence/severity\n' "$((findings - rated))" "$findings"
  exit 1
fi

printf '  \033[32m✓\033[0m every finding carries confidence and severity\n'
exit 0
