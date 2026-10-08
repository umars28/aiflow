#!/bin/sh
set -eu

root="${1:-$PWD}"
adapter="$root/.aiflow/project.yaml"
cd "$root"

testcmd=$(yq -r '.test // ""' "$adapter")
lintcmd=$(yq -r '.lint // ""' "$adapter")

if [ -z "$testcmd" ]; then
  printf '  \033[31m✗\033[0m no test command — a fix cannot be proven here\n'
  exit 1
fi

if [ ! -f "$root/.aiflow/06-fix.md" ]; then
  printf '  \033[31m✗\033[0m .aiflow/06-fix.md was never written\n'
  exit 1
fi

TESTPAT='_test\.(go|py|ts|js)$|\.test\.(ts|js)$|_spec\.rb$'
changed=$( { git diff --name-only HEAD; git ls-files --others --exclude-standard; } | sort -u | grep -v '^\.aiflow/' || true )
tests=$(printf '%s\n' "$changed" | grep -E "$TESTPAT" || true)
code=$(printf '%s\n' "$changed" | grep -vE "$TESTPAT" | grep -v '^$' || true)

if [ -z "$tests" ]; then
  printf '  \033[31m✗\033[0m no test changed — a fix without a reproducing test is not a fix\n'
  exit 1
fi
if [ -z "$code" ]; then
  printf '  \033[31m✗\033[0m only tests changed — nothing was actually fixed\n'
  exit 1
fi
printf '  \033[32m✓\033[0m %s test file(s), %s source file(s)\n' "$(printf '%s\n' "$tests" | grep -c .)" "$(printf '%s\n' "$code" | grep -c .)"

printf '  \033[2m$ %s\033[0m\n' "$testcmd"
if ! sh -c "$testcmd" >/dev/null 2>&1; then
  printf '  \033[31m✗\033[0m suite is red with the fix applied\n'
  exit 1
fi
printf '  \033[32m✓\033[0m green with the fix\n'

stashed=no
# shellcheck disable=SC2086
if git stash push --quiet --include-untracked --message aiflow-fix-probe -- $code 2>/dev/null; then
  stashed=yes
fi

if [ "$stashed" != yes ]; then
  printf '  \033[33m!\033[0m could not set the fix aside, skipping the red-without-fix probe\n'
else
  if sh -c "$testcmd" >/dev/null 2>&1; then
    git stash pop --quiet
    printf '  \033[31m✗\033[0m suite still passes without the fix — the test does not catch this defect\n'
    exit 1
  fi
  git stash pop --quiet
  printf '  \033[32m✓\033[0m red without the fix, so the test really catches it\n'
fi

if [ -n "$lintcmd" ]; then
  if sh -c "$lintcmd" >/dev/null 2>&1; then
    printf '  \033[32m✓\033[0m lint clean\n'
  else
    printf '  \033[31m✗\033[0m lint failed\n'
    exit 1
  fi
fi

exit 0
