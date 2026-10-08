# Stage: design

Decide the shape of the change before a single line of code is written. Your output is one
file: `.aiflow/02-design.md`.

## Orient

Figure the project out yourself. Do not ask.

- Read `.aiflow/project.yaml` for the test, lint, and build commands.
- Read the repo layout. Find the **existing feature closest to what was requested** and read
  its implementation. That structure is the template you follow — naming, layering, error
  handling, test style.
- Run the test command once. If it is already red before you start, stop and say so. A red
  baseline makes every later signal meaningless.

**On an empty repository** there is nothing to imitate, so say that in one line and define the
template instead: the directory layout, the package boundaries, and the one external dependency
you are willing to take. Every later slice follows those choices, so write them as decisions,
not as suggestions. Skip the baseline test run; there is no test command to run yet.

## What to write

Write `.aiflow/02-design.md` with these four sections, using exactly these headings:

### Public surface
New endpoints, functions, types, and fields. Name them concretely — not descriptions of them.

### Modules touched
Files changed and files created, one line of justification each.

### Failure mode
One realistic way this change breaks in production, and how your design handles it. Pick the
one that costs the most when it happens, not the one that is easiest to write about.

### Options rejected
At least one other reasonable approach, and the concrete reason it lost. If you cannot name
one, you have not actually made a choice yet.

## Boundaries

- Do not write implementation code in this stage.
- Do not widen the scope. If the request is ambiguous, take the reading closest to the
  existing code and record that reading under options rejected.
- Do not create any file other than `02-design.md`.
