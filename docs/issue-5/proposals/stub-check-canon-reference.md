# Proposal: remove vendored stub-check.sh, run by core canon reference

Subject: issue-5
Status: phase 1 (survey + proposal) — no execution in this PR

## Background

core canon #69 establishes that `stub-check.sh` (and equivalent
drift-recurrence detectors) must be referenced from the core installation,
not copied into each rulebook. This repo currently vendors a verbatim copy
at `performance-engineering/hooks/tests/stub-check.sh`, added during
issue-2 phase 2 (commit `b511a0d`) before #69 was decided. This proposal is
the execution plan for bringing this repo in line with #69; see
`docs/issue-5/reports/implementation/current-state-survey.md` for the
underlying findings.

## Proposed changes (phase 2, pending approval)

1. **Delete** the vendored copy:
   - `performance-engineering/hooks/tests/stub-check.sh`
   - If `performance-engineering/hooks/tests/` becomes empty as a result,
     remove the now-empty directory too.

2. **hooks.json**: no edit needed. The survey confirms
   `performance-engineering/hooks/hooks.json` never registered
   `stub-check.sh` as a hook — it is invoked directly (manually or by an
   external harness), not through the hooks pipeline. Phase 2 should
   explicitly confirm no such entry is added back.

3. **Switch invocation to core reference.** Replace the vendored-path
   invocation used in issue-2's record
   (`bash performance-engineering/hooks/tests/stub-check.sh
   performance-engineering/hooks`) with a core-reference invocation, e.g.
   `bash core/hooks/tests/stub-check.sh performance-engineering/hooks`
   (exact path depends on how core is installed/resolved in this repo's
   environment — the checkout does not currently include a `core/`
   directory, so phase 2 must first confirm the resolution mechanism,
   likely the same plugin-root convention `directive.sh` already uses via
   `${CLAUDE_PLUGIN_ROOT}`).

4. **Record the passing run** in `docs/issue-5/reports/implementation.md`
   (phase 2 deliverable, not created in this phase), showing stub-check
   executed against `performance-engineering/hooks` via the core reference
   path and passing.

## Risks

- **Core path resolution unconfirmed.** This checkout has no local `core/`
  directory and `docs/handbooks/canon-scripts.md` (the doc issue-5 points
  to for the canon decision) is not present here either. Phase 2 must
  verify the correct reference path/mechanism before deleting the local
  copy, or stub-check becomes unrunnable in this repo until that's
  resolved — a real risk of temporarily losing the drift check.
- **Directory cleanup side effect.** Deleting `tests/stub-check.sh` may
  leave `performance-engineering/hooks/tests/` empty; confirm no other
  file depends on that directory's existence before removing it.
- **Historical record docs unaffected.** `docs/issue-2/reports/*` mentions
  of stub-check.sh are historical and should not be edited — only the live
  vendored file and hooks.json (if it had an entry, which it does not) are
  in scope.
- **Self-approval prohibited.** Per contract v3, this proposal requires an
  approvers.md-listed APPROVE before phase 2 (deletion + core-reference
  switch + record) executes.

## Out of scope for phase 2

- Any change to `directive.sh` (already a core-reference stub since
  issue-2 phase 2).
- Any change to `docs/issue-2/**` historical records.
