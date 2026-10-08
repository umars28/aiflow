#!/bin/sh
set -eu

root="${1:-$PWD}"
doc="$root/.aiflow/05-review.md"

if [ ! -f "$doc" ]; then
  printf '  \033[31m✗\033[0m .aiflow/05-review.md was never written\n'
  exit 1
fi

if grep -qiE 'no findings|nothing found|nothing to flag' "$doc"; then
  printf '  \033[32m✓\033[0m clean, no findings\n'
  exit 0
fi

located=$(grep -coE '[A-Za-z0-9_./-]+\.[A-Za-z]+:[0-9]+' "$doc" || true)
conf=$(grep -ciE 'confidence' "$doc" || true)
sev=$(grep -ciE 'severity' "$doc" || true)

if [ "$located" -eq 0 ]; then
  printf '  \033[31m✗\033[0m no file:line reference anywhere — findings cannot be acted on\n'
  exit 1
fi


if [ "$conf" -eq 0 ] || [ "$sev" -eq 0 ]; then
  printf '  \033[31m✗\033[0m findings carry no confidence (%s) or severity (%s)\n' "$conf" "$sev"
  exit 1
fi

if [ "$conf" -ne "$sev" ]; then
  printf '  \033[31m✗\033[0m %s confidence markers but %s severity markers — some findings are unrated\n' "$conf" "$sev"
  exit 1
fi

printf '  \033[32m✓\033[0m %s findings, each rated, %s file references\n' "$conf" "$located"
exit 0
