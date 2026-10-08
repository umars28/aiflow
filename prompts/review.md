# Stage: review

Read the change as a reviewer who did not write it. Your output is a comment on the pull
request, plus `.aiflow/05-review.md`.

## Scope — this is what drives the cost

Read the **diff**, not the whole repo:

```
git diff origin/main...HEAD
```

Open a full file only when the diff is not enough to judge something, and only that file.
Exploring the whole repo at this stage is the single most wasteful thing you can do here.

## What to look for

| Class | Concrete examples |
|---|---|
| Swallowed errors | `_ =` on an error, empty `catch`, `defer tx.Rollback()` shadowed by an earlier `return` |
| System boundary | Input from HTTP, files, or external APIs reaching a query or the filesystem unvalidated |
| Queries in loops | DB or HTTP calls inside an iteration that could be batched |
| Money and time | Money as float, timestamps without a timezone, rounding left implicit |
| File modes and secrets | Credentials, keys, or config written with a mode wider than `0600`, directories wider than `0700`, secrets reaching logs or argv |
| Destructive writes | Truncating a file in place with no backup and no temp-file-then-rename, so a crash or an empty input destroys the original |
| Diverges from neighbours | A pattern that differs from comparable modules in the same repo |
| Concurrency | Shared state without a lock, goroutines with no stop path, context not propagated |

## How to report

**Report every finding, including ones you are unsure about and ones you consider minor.** Do
not filter by importance at this stage — a human filters afterwards. Better that one finding
gets filtered out than one bug silently disappears.

Every finding needs:

- `file:line`
- One sentence: what is wrong
- One sentence: the concrete scenario that breaks it — what input, what result
- `confidence`: high | medium | low
- `severity`: high | medium | low

Order worst first. If there is nothing, say so in one sentence — do not invent minor findings
to look busy.

## Boundaries

- Fix nothing. This stage reads; it does not change.
- Do not comment on formatting or naming unless it diverges from the repo's own pattern —
  a linter is cheaper and never hallucinates.
- Do not commit or push.
