# Current-state survey — issue-1

## This repo's write surface (performance-engineering plugin)

- `performance-engineering/hooks/directive.sh` — sources core's
  `role-directive.sh` (already converted per issue-2 phase 2, commit
  `b511a0d`) and calls `core_role_directive` with four values:
  - YOU DECIDE: "부하/지연 목표를 만족하는가"
  - USE_WHEN: "성능 예산이 걸린 설계/회귀일 때"
  - PRODUCES (required record fields): "performance budget, profiling
    evidence, bottleneck list"
  - WRITE_SCOPE: `[]` (report-only role) + HAND-OFF to capacity-planning
  None of these four values name a diagnostic methodology, a numeric
  target, a workload-characterization requirement, or an evidence
  standard (percentile vs. average) — they state *that* a budget/evidence
  /bottleneck-list must exist, not *how* to produce or validate them.
- `performance-engineering/.claude-plugin/plugin.json` — description
  string mirrors directive.sh's four values verbatim; no methodology
  content beyond that.
- `performance-engineering/hooks/hooks.json` — registers only
  `directive.sh` as a SessionStart hook (issue-2 phase 2 removed the
  vendored `trailer-gate.sh`/`record-fields-gate.sh`/
  `handbook-trigger-gate.sh` copies in favor of core-side canon
  registration — those gates now run from core, not this repo, per
  `docs/issue-2/proposals/implementation.md` item 2). This repo's
  `hooks.json` has no local gate enforcing record-field *content*.
- `docs/specs/approvers.md` — single-account mode, `JiwonJung94` is the
  sole listed approver.
- No `docs/handbooks/` or `docs/specs/` content in this repo defines a
  proposal-document methodology or a record-document methodology for any
  role yet — issue-2 and issue-5 (the only prior issues) are both
  plumbing/canon-reference conversions, not methodology-content
  proposals. issue-1 is the first issue in this repo to define
  substantive domain methodology rather than infrastructure wiring.
- No `core/` directory is vendored locally (consistent with issue-2's
  survey finding); this proposal does not touch core files — core canon
  references (warrant-hunter, the three gates, stub-check.sh) are already
  handled by issue-2/issue-5 and are out of scope here per the issue's own
  constraint ("warrant-hunter는 core canon 참조로").

## Prior proposal-document conventions in this repo (issue-2, issue-5)

Both existing phase-1 proposals (`docs/issue-2/proposals/implementation.md`,
`docs/issue-5/proposals/stub-check-canon-reference.md`) follow the same
implicit shape: a background/mapping section per work item, explicit
"Proposed changes (phase 2, pending approval)" section, a "Risks" section
flagging unresolved dependencies and the self-approval prohibition, and an
"Out of scope" section. Neither states a domain methodology or cites
external sources — both are mechanical plumbing conversions, so this is
the first proposal in the repo that needs a methodology-adoption format at
all. This survey treats that gap as the reason scouting (see
`scout-brief.md`) was warranted here, unlike issue-2/issue-5 where the
scout step was explicitly skipped as a mechanical no-exemplar change.

## Gate/mechanism inventory relevant to phase-2 enforcement plan

- `record-fields-gate.sh` (core canon, per issue-2's conversion) checks
  produces-field *presence* only against
  `docs/issue-<n>/reports/${CLAUDE_ROLE}.md`; it does not validate field
  *content* (e.g., that "performance budget" is a number, that
  "profiling evidence" cites a percentile). Any phase-2 plugin change from
  this proposal that wants content-level enforcement, not just
  presence-level, needs a role-local addition (directive.sh's PRODUCES
  text is descriptive guidance to the writer, not machine-checked) or a
  new local gate script — this is the concrete plugin surface item (d) of
  the proposal must resolve.
- `directive.sh`'s `core_role_directive` signature (from issue-2's survey
  of `core/hooks/lib/role-directive.sh`) accepts exactly 4 arguments
  (you_decide, use_when, produces, hand_off) — so any methodology text
  added to directive.sh must fit inside these 4 fields, not introduce a
  5th argument, unless a role-local addition outside the core call is
  used instead.
