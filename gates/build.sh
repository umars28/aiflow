#!/bin/sh
set -eu

root="${1:-$PWD}"
adapter="$root/.aiflow/project.yaml"
fail=0

cd "$root"

testcmd=$(yq -r '.test // ""' "$adapter")
lintcmd=$(yq -r '.lint // ""' "$adapter")

if [ -z "$testcmd" ]; then
  printf '  \033[31m✗\033[0m .aiflow/project.yaml has no test command — nothing can prove this\n'
  exit 1
fi

printf '  \033[2m$ %s\033[0m\n' "$testcmd"
if sh -c "$testcmd"; then
  printf '  \033[32m✓\033[0m tests green\n'
else
  printf '  \033[31m✗\033[0m tests red\n'
  fail=1
fi

if [ -n "$lintcmd" ]; then
  printf '  \033[2m$ %s\033[0m\n' "$lintcmd"
  if sh -c "$lintcmd"; then
    printf '  \033[32m✓\033[0m lint clean\n'
  else
    printf '  \033[31m✗\033[0m lint failed\n'
    fail=1
  fi
fi

if git -C "$root" diff --name-only HEAD | grep -qE '_test\.(go|py|ts|js)$|\.test\.(ts|js)$|_spec\.rb$'; then
  printf '  \033[32m✓\033[0m test files changed alongside the code\n'
else
  printf '  \033[31m✗\033[0m no test file changed — new code without a test does not pass\n'
  fail=1
fi

exit "$fail"
