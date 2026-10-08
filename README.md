# aiflow

A reusable AI workflow harness shared across projects. Prompts, gates, and CI workflows live
here; each project keeps only two files.

## Shape

```
Cowork           intent & spec       write the goal, read the design
   │ git
Claude Code      parallel execution  worktrees + subagents, on your laptop
   │ PR
GitHub Actions   verification        tests, review, gates — runs with the laptop closed
   │ event
n8n              orchestration       external triggers, retries, notifications
   │ json
Dashboard        display             one page, every project
```

Handoff between layers happens through git and webhooks. There is no shared state store.

## Install

```sh
git clone https://github.com/umars28/aiflow ~/Documents/Portfolio/aiflow
ln -sf ~/Documents/Portfolio/aiflow/bin/flow ~/.local/bin/flow
```

Tell `flow status` which repos to watch:

```sh
mkdir -p ~/.config/flow
cat > ~/.config/flow/repos <<'TXT'
umars28/marspay
umars28/sshm
umars28/observability-platform
TXT
```

## Use

```sh
flow init                          detect the stack, write .aiflow/project.yaml
flow run design "secret rotation"  decide the shape of the change
flow run plan                      cut it into slices
flow run build                     build it, TDD per slice
flow run review                    read the diff as someone else
flow fan "feature a" "feature b"   up to three worktrees in parallel
flow fan-clean                     remove worktrees that are already clean
flow status                        summary of every watched repo
```

Every `flow run` ends in a gate. A failed gate stops the chain — that is what replaces
watching the agent yourself.

## Add a new project

Two files, two one-time grants.

```sh
cd <project>
flow init
mkdir -p .github/workflows
curl -sL https://raw.githubusercontent.com/umars28/aiflow/main/templates/ai.yml \
  -o .github/workflows/ai.yml
```

For an infra repo, fetch `templates/ai-review-only.yml` instead. It drops the `build` job
entirely, so no run can ever write to the repository.

`ai.yml` only calls the reusable workflows here. It needs no edits — everything
project-specific lives in `.aiflow/project.yaml`. Commit it to the **default branch** before
opening any pull request against it (see Troubleshooting).

Then grant the two things that are per-repository and easy to forget:

```sh
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo umars28/<repo>
```

and add the repository to the Claude GitHub App at
[github.com/settings/installations](https://github.com/settings/installations). Installing the
app on one repository does not cover the others; a missing grant fails the run with
"Claude Code is not installed on this repository".

## Per-project adapter

```yaml
stack: go
test: go test ./...
lint: go vet ./...
build: go build ./...
migrations: ""
chain: full
terraform_dir: terraform
```

`chain` decides how far the chain is allowed to run:

| Value | Meaning |
|---|---|
| `full` | design → plan → build → review → PR |
| `review` | design and review only. Stages that modify code are blocked |

Infra repos are always `review`. Never `apply`.

## Gates

| Stage | What it checks |
|---|---|
| `design` | Four required sections, including a failure mode and a rejected option |
| `plan` | Six slices maximum, each referencing the test command |
| `build` | Tests green, lint clean, and a test file actually changed |
| `review` | Every finding carries a location, a confidence, and a severity |
| `infra` | `terraform validate`, `fmt`, and no stateful resource destroyed |

No gate is an AI judging another AI's output. Every one of them is an exit code.

## Quota brakes

CI usage and interactive usage draw from the same pool. These are a requirement, not a
tuning pass:

| Brake | Value |
|---|---|
| PR trigger | `[opened, ready_for_review]` — no `synchronize` |
| Drafts | Skipped |
| Concurrency | `cancel-in-progress` per ref |
| Model | `claude-sonnet-5` for review · `claude-opus-5` for build |
| `--max-turns` | 12 review · 40 build |
| Timeout | 10 min review · 45 min build |
| Nightly | Skipped when `main` has been idle for 24 hours |

## Credentials

`umars28` is a personal account, not an organization, so Actions secrets are per repository —
there is no org-wide secret to share. Run this once per repo:

```sh
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo umars28/<repo>
```

Then install the [Claude GitHub App](https://github.com/apps/claude) on that repository.

## Troubleshooting

Three failures cost real time on the first rollout. All three are expected behaviour, not bugs.

| Symptom | Cause | Fix |
|---|---|---|
| `startup_failure`, "workflow file issue", no logs | The repo's default workflow permission is read-only, and a called workflow may not request more than its caller holds. The caller job declared no `permissions` at all. | Declare `permissions` on every caller job in `ai.yml`. `templates/ai.yml` already does. |
| Action logs "Workflow validation failed … identical content to the version on the default branch", then skips | Deliberate safeguard: otherwise any pull request could edit the workflow and make the agent do anything. | Land `ai.yml` on the default branch first. The pull request that introduces the workflow can never be reviewed by it. |
| `error_max_turns` with a high `permission_denials_count` | `--allowedTools` was too narrow, so turns were spent hitting denials instead of working. | Grant `Bash(git:*)` rather than per-subcommand patterns. Check `permission_denials_count` in the run log before raising `--max-turns`. |

Re-running a review without loosening the triggers: toggle the pull request to draft and back
to ready, which fires `ready_for_review`. Pushing another commit deliberately does not
re-trigger.

## Kill switch

```sh
gh workflow disable AI --repo umars28/<repo>                   stop one repo
gh secret delete CLAUDE_CODE_OAUTH_TOKEN --repo umars28/<repo> revoke one repo
```
