# Current-state survey — issue-2

## Scout: skipped

Skip condition met: the spec leaves no external-exemplar design decision
open — this is a mechanical reference-conversion against a transition path
core issue #66 already prescribes verbatim (reproduced below); there is no
product category or best-in-class exemplar to sweep for an internal
canon-vs-vendored-copy plumbing change.

## This repo's write surface (performance-engineering plugin)

- `performance-engineering/agents/warrant-hunter.md` — local copy, explicitly
  says "adapted from implementation-rulebook's `agents/warrant-hunter.md`"
  (skeleton stance set, never filled in). This is the exact per-repo vendored
  copy core issue #63 targets for stub replacement.
- `performance-engineering/hooks/directive.sh` — SessionStart hook. Mixes
  fixed boilerplate (trap/kill-switch/`CLAUDE_ROLE` guard/opening+closing
  lines) with four role-unique values (YOU DECIDE / USE_WHEN / PRODUCES /
  WRITE_SCOPE+HAND-OFF text). Matches the shape core's `role-directive.sh`
  factors out, plus one extra field this role's copy prints
  (`WRITE_SCOPE: []`) not present in `core_role_directive`'s four-arg
  signature — this role is report-only (empty write_scope), so that line is
  presumably folded into HAND-OFF text or dropped; flagged as an open
  question below rather than decided silently.
- `performance-engineering/hooks/trailer-gate.sh` — vendored copy, header
  says "Adapted from implementation-rulebook's trailer-gate.sh, role name
  substituted only (this file's logic is role-agnostic)" — self-documents as
  exactly the drift core issue #66 fixes. Registered in `hooks.json`'s
  `PreToolUse`/Bash matcher.
- `performance-engineering/hooks/record-fields-gate.sh` — vendored copy,
  header cites "adapted per issue-170 from roles/performance-engineering.json's
  `produces`". Required fields here: `performance-budget`,
  `profiling-evidence`, `bottleneck-list` — these three map onto this
  role's directive PRODUCES line and are role-specific content, not
  role-agnostic gate logic. Terminal-state handling: this copy has **no**
  loop_state/terminal-state logic at all (it only checks produces-field
  presence) — core's canon version adds a §20 loop_state / next-steps /
  open-findings check that this copy lacks entirely. Registered in
  `hooks.json`'s Write/Edit/MultiEdit matcher.
- `performance-engineering/hooks/handbook-trigger-gate.sh` — vendored copy,
  explicit placeholder (`exit 0 # placeholder verdict`), comments say the
  path heuristics are unhardened and a report-only role with empty
  write_scope "may not need this gate at all — reassess before shipping."
  Registered in `hooks.json`'s Bash matcher.
- `performance-engineering/hooks/hooks.json` — registers all three gates
  above plus `directive.sh`, per-plugin (not core-side).
- No `hooks/tests/` directory exists in this repo yet — no
  `parse-check.sh`, `deny-only-check.sh`, or `stub-check.sh` present.
- `.claude-plugin/marketplace.json` lists exactly one plugin
  (`performance-engineering`) — no `core`/`terse`/`freelunch`/`scout`/
  `warrant` entries. How this repo's session obtains the `[core] Interaction
  protocol` directive text seen in this session's SessionStart output (it
  matches `core/hooks/directive.sh`'s output verbatim) is not resolved by
  anything in this repo's tree — core plugin installation is evidently
  external to this marketplace.json. This is the key unknown the proposal's
  open question below hangs on.

## Core canon state (tokenmaxxxer/tokenmaxxxer-core, main, read via clone)

Confirms issue-2's background: both core #63 and #66 have **landed**
(`loop_state: delivered` in both `docs/issue-63/reports/implementation.md`
and `docs/issue-66/reports/implementation.md`), though the GitHub issues
themselves remain open (tracking the per-rulebook follow-up, not closed).

- `core/warrant/` — fifth plugin dir: `agents/warrant-hunter.md`,
  `hooks/directive.sh` (proportional hunt cadence: 3-tier wall-clock cap by
  `git diff --stat` size, docs-only fast path, miss-streak tier drop),
  `hooks/{hunt-guard.sh,hunt-state.sh,scope-gate.sh,state.sh,hooks.json}`.
  Registered in core's own `.claude-plugin/marketplace.json`.
- `core/hooks/lib/role-directive.sh` — sourceable lib exposing
  `core_role_directive(you_decide, use_when, produces, hand_off)`; renders
  the fixed preamble/kill-switch/guard/RECORD line around the four
  role-unique values. Usage comment shows the exact stub shape expected:
  source the lib via
  `${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh`,
  then call `core_role_directive` with the four values. Kill switch derives
  from `CLAUDE_ROLE` uppercased (`<ROLE>_CYCLE_OFF`), matching this repo's
  existing `PERFORMANCE_ENGINEERING_CYCLE_OFF` convention exactly.
- `core/hooks/{trailer-gate.sh,record-fields-gate.sh,handbook-trigger-gate.sh}`
  — promoted, `CLAUDE_ROLE`-parameterized, registered in `core/hooks/hooks.json`
  so they fire for every plugin install automatically. No per-rulebook
  `hooks.json` entry needed for these three once the local copies are
  deleted (issue-66's approver decision, recorded in
  `core/docs/issue-66/reports/implementation.md`).
  - `record-fields-gate.sh`'s canon version checks §20 fields (what/why/
    upstream-basis/loop_state/open-findings) against **the acting role's
    own record** `docs/issue-<n>/reports/${CLAUDE_ROLE}.md` generically —
    it does NOT know about this role's specific PRODUCES fields
    (performance-budget/profiling-evidence/bottleneck-list). Those are a
    directive-level concern (PRODUCES text), not a gate-level one in the
    canon design — confirms item 3's "role-unique content stays local"
    split.
  - Terminal-state divergence found in core's own survey (issue-66):
    canon default is `{"landed"}`, configurable via
    `RECORD_FIELDS_TERMINAL_STATES` (space-separated) in a rulebook's own
    `hooks.json` env when a role's real terminal set differs. This repo's
    vendored copy has no loop_state concept at all today, so there is no
    existing divergent value to preserve — default `landed` applies as-is
    (see proposal item 4).
- `core/hooks/tests/stub-check.sh` — drift-recurrence detector, distributed
  per-rulebook like `parse-check.sh`. Two check modes:
  - absence-based for `trailer-gate.sh`/`record-fields-gate.sh`/
    `handbook-trigger-gate.sh`/`parse-check.sh`: any file by that name under
    the rulebook's `hooks/` tree (maxdepth 3) is a FAIL, since core now
    fires them globally.
  - structural for `directive.sh`: every non-blank/non-comment line must be
    the source line, a plain variable assignment, or the
    `core_role_directive` call — anything else (case statement, guard, raw
    echo/cat) fails as regrown boilerplate.
  Takes an optional `[hooks-dir]` arg (defaults to its own parent dir).
- `core/docs/issue-66/reports/implementation.md`'s "Transition path (batches
  with #63)" section is the authoritative per-rulebook checklist issue-2
  is executing against — reproduced in the proposal.

## Open question (unresolved by survey, needs approver input before phase 2)

How this plugin's `directive.sh` resolves the core plugin's install path at
runtime is not decidable from this repo alone: `role-directive.sh`'s own
usage comment suggests
`${CLAUDE_PLUGIN_ROOT_CORE:-$(cd .../../../core && pwd -P)}`, i.e. an
env var the harness sets when both plugins are enabled together, with a
relative-sibling-directory fallback. This repo's `marketplace.json` lists no
core dependency today, so the fallback path assumption ("core plugin
installed as a `core/` sibling of this plugin's directory") is unverified
for this repo's actual install layout. Proposal marks this as the one item
needing approver confirmation before phase 2 writes the stub.
