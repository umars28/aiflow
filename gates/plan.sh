#!/bin/sh
set -eu

root="${1:-$PWD}"
doc="$root/.aiflow/03-slices.md"
adapter="$root/.aiflow/project.yaml"
fail=0

if [ ! -f "$doc" ]; then
  printf '  \033[31m✗\033[0m .aiflow/03-slices.md was never written\n'
  exit 1
fi

rows=$(grep -cE '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$doc" || true)

if [ "$rows" -eq 0 ]; then
  printf '  \033[31m✗\033[0m no slice rows readable in the table\n'
  fail=1
else
  printf '  \033[32m✓\033[0m %s slices readable\n' "$rows"
fi

if [ "$rows" -gt 6 ]; then
  printf '  \033[31m✗\033[0m %s slices — the cap is 6, the design is too big\n' "$rows"
  fail=1
fi

testcmd=$(yq -r '.test // ""' "$adapter")
if [ -n "$testcmd" ]; then
  word=$(printf '%s' "$testcmd" | awk '{print $1}')
  if grep -q "$word" "$doc"; then
    printf '  \033[32m✓\033[0m slices reference the test command\n'
  else
    printf '  \033[31m✗\033[0m no slice mentions "%s" — a slice without a test is not a slice\n' "$word"
    fail=1
  fi
fi

exit "$fail"
