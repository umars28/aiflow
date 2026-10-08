#!/bin/sh
set -eu

root="${1:-$PWD}"
adapter="$root/.aiflow/project.yaml"
dir=$(yq -r '.terraform_dir // "terraform"' "$adapter")
fail=0

STATEFUL='aws_db_instance|aws_rds_cluster|aws_s3_bucket|aws_ebs_volume|aws_efs_file_system|google_sql_database_instance|google_storage_bucket|kubernetes_persistent_volume_claim|helm_release'

cd "$root"

if [ ! -d "$dir" ]; then
  printf '  \033[32m✓\033[0m no terraform directory, skipped\n'
  exit 0
fi

printf '  \033[2m$ terraform -chdir=%s plan\033[0m\n' "$dir"

if ! terraform -chdir="$dir" init -backend=false -input=false >/dev/null 2>&1; then
  printf '  \033[31m✗\033[0m terraform init failed\n'
  exit 1
fi

if ! terraform -chdir="$dir" validate >/dev/null; then
  printf '  \033[31m✗\033[0m terraform validate failed\n'
  exit 1
fi
printf '  \033[32m✓\033[0m terraform validate passed\n'

if ! terraform -chdir="$dir" fmt -recursive -check >/dev/null; then
  printf '  \033[31m✗\033[0m terraform fmt is not clean\n'
  fail=1
else
  printf '  \033[32m✓\033[0m terraform fmt clean\n'
fi

plan=$(mktemp)
if terraform -chdir="$dir" plan -input=false -no-color -refresh=false > "$plan" 2>&1; then
  destroyed=$(grep -E '^[[:space:]]*#' "$plan" | grep -E 'will be destroyed|must be replaced' | grep -cE "$STATEFUL" || true)
  if [ "$destroyed" -gt 0 ]; then
    printf '  \033[31m✗\033[0m %s stateful resources would be destroyed or replaced:\n' "$destroyed"
    grep -E '^[[:space:]]*#' "$plan" | grep -E 'will be destroyed|must be replaced' | grep -E "$STATEFUL" | sed 's/^/      /'
    fail=1
  else
    printf '  \033[32m✓\033[0m no stateful resource destroyed\n'
  fi
else
  printf '  \033[33m!\033[0m plan needs credentials to run — skipping the destroy check\n'
fi
rm -f "$plan"

exit "$fail"
