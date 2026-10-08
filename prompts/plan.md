# Stage: plan

Cut the design into pieces that can be built one at a time. Your output is one file:
`.aiflow/03-slices.md`.

## Input

`.aiflow/02-design.md`. If it does not exist, stop and say the design stage has not run.
Do not invent a design of your own.

## How to cut

A slice is valid only if **all three** hold:

1. It ends with the whole test suite green — not part of it.
2. It names a test command that can be run as written, copied from `.aiflow/project.yaml`.
3. It can ship on its own without waiting for another slice.

A slice that cannot be tested is not a slice. Fold it into a neighbour that can.

Order them smallest and most foundational first. The first slice is usually the one touching
schema or data types, because everything else depends on it.

## Output format

A Markdown table with exactly these columns:

| # | Slice | Primary files | Test that proves it |
|---|---|---|---|

After the table, one paragraph: why this order, and which slice carries the most risk.

## Boundaries

- Six slices maximum. More than that means the design is too big — say so and propose cutting
  the scope, rather than forcing it into ten table rows.
- Do not write code.
- Do not create any file other than `03-slices.md`.
