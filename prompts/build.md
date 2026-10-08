# Stage: build

Build the slices in `.aiflow/03-slices.md`, one at a time, until they are done or you are
blocked.

If arguments were passed and `03-slices.md` does not exist, treat the argument as a single
feature description: cut it into slices in your head, then work it with the same rules below.

## The per-slice loop — do not shortcut it

For every slice, in order:

1. **Write the failing test first.** Run it. Confirm it fails for the reason you intended,
   not because of a typo or a missing import.
2. Write the minimum code that makes it pass.
3. Run the **entire** test command from `.aiflow/project.yaml`, not just your new test.
4. Run the lint command if there is one.
5. Only then move to the next slice.

Never move to the next slice on a red suite. If one slice fights back twice in a row, stop
building — report what blocked you and name the slices already finished. An honest partial is
worth more than nine slices nothing can verify.

Follow the installed `tdd` skill for the red-green-refactor details.

## Style

Write code that reads like the code around it: match the naming, layering, error handling, and
test style of the reference module chosen during design.

**Do not write code comments.** This applies to every language and every file type, including
docstrings on new code, marker comments (`TODO`, `FIXME`, `NOTE`), and comments explaining why
a decision was made. If there is a trap or a non-obvious reason worth knowing, put it in the
final report, not in the file. Leave existing comments alone.

## Boundaries

- Deliver what was asked, at the scope that was asked. Do not add abstractions, helpers,
  feature flags, or error handling for cases that cannot happen.
- Do not commit, push, or open a pull request.
- Validate at system boundaries only (user input, external APIs). Trust internal code.

## Final report

One short message, no extra files:

- Slices completed, and the last test command's result verbatim.
- Decisions you made on the user's behalf, and the alternatives not taken.
- Anything deliberately left out, and why.
