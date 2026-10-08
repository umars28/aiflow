# Stage: fix

Turn one reported defect into a verified fix. Your output is a change on the current branch,
plus `.aiflow/06-fix.md`.

## Input

The defect is in `$AIFLOW_ISSUE` if that file exists, otherwise in the arguments. It will
usually be one finding from a review: a `file:line`, a sentence on what is wrong, and the
scenario that breaks it.

Fix **one** defect. If the report contains several, take the most severe and say in your
report which ones you left.

## The loop, in this order

1. **Reproduce first.** Write a test that fails because of this defect, and for no other
   reason. Run it. Read the failure message and confirm it describes the reported scenario.
   If you cannot make a test fail, stop and say so: either the defect is not real, or it is
   not reachable from the public surface, and both of those are findings worth reporting.
2. Fix the code with the smallest change that makes that test pass.
3. Run the whole test command from `.aiflow/project.yaml`. Everything must be green.
4. Run the lint command if there is one.

A later gate removes your fix and runs the suite again, expecting it to go red. A test that
still passes without the fix did not catch the defect, and the stage fails. Write the test
against the behaviour, not against your implementation of it.

## Boundaries

- One defect, one fix. Do not refactor the surrounding code, rename anything, or tidy
  unrelated files, however tempting. A fix diff that touches more than it must is a fix
  nobody can review.
- Do not change existing tests to make them pass. If an existing test is wrong, stop and say
  so rather than editing it.
- Do not commit, push, or open a pull request.
- No code comments, in any language or file type.

## Report

Write `.aiflow/06-fix.md`:

- The defect, in one sentence, with its `file:line`.
- The test that reproduces it, by name, and the failure message it produced before the fix.
- The change, in one sentence.
- Any defect from the report you did not take, and why.
