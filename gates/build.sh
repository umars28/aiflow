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

TESTPAT='_test\.(go|py|ts|js)$|\.test\.(ts|js)$|_spec\.rb$|(^|/)tests?/'
changed=$( { git -C "$root" diff --name-only HEAD; git -C "$root" ls-files --others --exclude-standard; } \
           | sort -u | grep -v '^\.aiflow/' | grep -v '^$' || true )

base="${GITHUB_BASE_REF:-}"
[ -z "$base" ] && base=$(git -C "$root" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
[ -z "$base" ] && base=main

branch_tests() {
  git -C "$root" diff --name-only "origin/$base...HEAD" 2>/dev/null | grep -qE "$TESTPAT"
}

uncovered=""
for f in $changed; do
  case "$f" in
    *.go|*.py|*.ts|*.tsx|*.js|*.jsx|*.rb) ;;
    *) continue ;;
  esac
  printf '%s\n' "$f" | grep -qE "$TESTPAT" && continue
  d=$(dirname "$f")
  if ! ls "$root/$d" 2>/dev/null | grep -qE "$TESTPAT"; then
    uncovered="$uncovered $f"
  fi
done

if [ -z "$changed" ]; then
  printf '  \033[32m✓\033[0m nothing left to build, every slice was already done\n'
elif printf '%s\n' "$changed" | grep -qE "$TESTPAT"; then
  printf '  \033[32m✓\033[0m test files changed alongside the code\n'
elif [ -z "$uncovered" ]; then
  printf '  \033[32m✓\033[0m source touched, but every package it lives in already has tests\n'
elif branch_tests; then
  printf '  \033[32m✓\033[0m this run wrote no test, but the branch already carries them\n'
else
  printf '  \033[31m✗\033[0m source changed with no test to prove it:\n'
  for f in $uncovered; do printf '      %s\n' "$f"; done
  fail=1
fi

exit "$fail"
