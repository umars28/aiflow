#!/bin/sh
set -eu

root="${1:-$PWD}"
doc="$root/.aiflow/02-design.md"
fail=0

check() {
  if grep -qiE "^#{2,3}[[:space:]]+$1" "$doc"; then
    printf '  \033[32m✓\033[0m %s\n' "$2"
  else
    printf '  \033[31m✗\033[0m %s\n' "$2"
    fail=1
  fi
}

if [ ! -f "$doc" ]; then
  printf '  \033[31m✗\033[0m .aiflow/02-design.md was never written\n'
  exit 1
fi

check 'Public surface'   'public surface section present'
check 'Modules touched'  'modules touched listed'
check 'Failure mode'     'failure mode named'
check 'Options rejected' 'at least one rejected option'

words=$(wc -w < "$doc" | tr -d ' ')
if [ "$words" -lt 80 ]; then
  printf '  \033[31m✗\033[0m design is only %s words — too thin to judge\n' "$words"
  fail=1
fi

exit "$fail"
