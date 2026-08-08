---
code_under_review: HEAD
loop_state: landed
---

# implementation record — issue-19 phase 2: spec-alignment delivery

Subject: issue-19. Basis: `docs/issue-19/proposals/spec-alignment.md`
(approved via the issue-level comment `APPROVE issue-19/implementation`,
single-account mode per contract v3 s19).

## What was done

Applied the approved proposal's "What will be done" steps 1-7 verbatim,
against the frozen write set:

- [x] `performance-engineering-order-check/hooks/heading-vocabulary.md` —
  added an `"sli"` group (`sli`, `service level indicator`) and an
  `"error-budget"` group (`error budget`, `error-budget`,
  `error-budget-remaining`, `error_budget_remaining` — the bare
  `error-budget` phrase was added during implementation so the group
  actually matches an `## Error-Budget` heading; see What did not work).
  Updated the file's intro line documenting which groups each of the
  three gates reads.
- [x] `performance-engineering-record-gate/hooks/record-gate.sh` —
  extended the Python judge with three new section-scoped checks layered
  on the existing (b)4/(b)6 elements: `sli:` (non-placeholder, scoped to
  the Evidence section or an `sli`-headed section), `error_budget_remaining:`
  (scoped to a new Error-Budget section, presence-only per the spec's own
  `TBD (follow-up)` recomputation note), and `verdict:` (exact enum
  `within-budget`/`exhausted`, scoped to the Exit-Criteria section,
  layered on top of the existing pass/fail prose check). Added a
  frontmatter `loop_state:` closed-set check (five spec states) that
  denies when present-but-invalid and is silent when absent.
- [x] `performance-engineering-record-gate/README.md` — documented the
  four new elements/checks in a new "issue-19 spec-alignment" subsection
  of Behavior, and updated the Tests section's case list.
- [x] `performance-engineering-record-gate/tests/run-gate-tests.sh` —
  added fixtures: `missing-sli`, `missing-error-budget`,
  `invalid-verdict`, `loop-state-invalid` (deny), and one `loop-state-*`
  allow case per spec state (5 cases). Extended `full()` and every
  `without_*` fixture to carry the new Error-Budget section so the
  pre-existing (b)-element cases keep testing exactly one missing facet
  each, not incidentally failing on the new checks too.
- [x] `performance-engineering-checklist/checklist.md` — added a "Phase-2
  spec-required fields" subsection mirroring the four spec fields and
  `loop_state`, same checkbox style as the existing seven items.
- [x] `README.md` — updated the Layout section's `record-gate.sh`
  description to mention the new fields/checks, and corrected the stale
  role-card `write_scope: []` line to
  `docs/issue-<n>/reports/performance-engineering.md`, matching the
  spec's declared write surface.
- [x] `performance-engineering/hooks/directive.sh` — added the four
  required field names to the `PRODUCES` text and a new `LOOP_STATE` line
  listing the five-state vocabulary, so a session reading its own
  directive sees the spec vocabulary at SessionStart.

No methodology.md (a)/(b) facet was removed; every new check layers on
top of an existing section-scoped facet or adds a new section
(Error-Budget) alongside the existing ones.

## Why

Per the approved proposal's Rationale: the record-gate's existing (b)4/(b)6
elements already carried the underlying evidence in free-text prose but
under no named, greppable field — the four spec-required fields
(`sli`, `slo_target`, `error_budget_remaining`, `verdict`) needed a named
landing spot the gate could check. Extending the existing section-scoped
Evidence/Exit-Criteria checks (rather than a standalone frontmatter block)
reuses the section-scoping machinery every other facet in this rulebook
already goes through, so a correctly-worded field in the wrong section
still fails, same as the existing seven elements. `loop_state` lands in
frontmatter instead, because it is a document-level state marker, not a
claim tied to one section — matching the shape `implementation`'s own
`record-shape-gate.sh` already uses elsewhere in this repo family.
`slo_target` was left without a new gate check because it already has a
natural home in this rulebook's existing phase-1 `numeric SLO` facet
(`performance-engineering-proposal-gate`'s `slo` group); it is documented
in `README.md`/checklist.md to satisfy the acceptance grep, per the
proposal's own scoping of gate work to phase-2 record checks.

## Upstream

Basis: `docs/issue-19/proposals/spec-alignment.md` (commit 50e6930, merged
via PR #20 / a90535c). Survey: `docs/issue-19/reports/implementation/survey.md`.

## What did not work

- Expected the `"error-budget"` heading-vocabulary group's existing
  phrases (`error budget`, `error-budget-remaining`,
  `error_budget_remaining`) to match an `## Error-Budget` section heading
  via `section_lib`'s substring-containment matching. Actual: none of
  those three phrases is a substring of the lower-cased heading text
  `error-budget` (the phrases have a space or a `-remaining`/`_remaining`
  suffix the bare heading text doesn't contain), so
  `sections_matching_group` returned no match and the
  `error_budget_remaining:` check always denied, even on a fully-compliant
  fixture. Caught immediately by running the gate's own test suite
  (`complete-compliant` failed first). Fixed by adding the bare
  `error-budget` phrase to the group in `heading-vocabulary.md`.
- Ran the new fixtures through the test harness with unmodified
  `without_*`/`full()` helper bodies first; every `loop-state-*` allow
  case failed too, cascading from the same `full()` bug above rather than
  a second defect — resolved by the same fix, confirmed by re-running the
  full 33-case suite (all green) plus the other two gates' unmodified
  suites (26 and 19 passing, no regression).

## Acceptance verification (run this turn)

- `grep -ril "sli\|slo_target\|error_budget_remaining\|verdict" docs/ README.md`
  — every field name has at least one hit (README.md and multiple
  `docs/issue-19/**` files).
- `grep -rio "loop_state" ... ` cross-checked against the vocabulary
  surfaced in `directive.sh`/`record-gate.sh`/this record: exactly the
  five spec states (`landed`, `measuring`, `metric-unreachable`,
  `reviewing`, `slo-undeclared`), no stale/extra state.
- `CLAUDE_PLUGIN_ROOT_CORE=/home/jwjung/tokenmaxxxer-core/core bash performance-engineering-record-gate/tests/run-gate-tests.sh`
  — 33 passed, 0 failed (includes the 10 new issue-19 fixture cases).
- `bash performance-engineering-proposal-gate/tests/run-gate-tests.sh` —
  26 passed, 0 failed (unmodified, unaffected).
- `bash performance-engineering-order-check/tests/run-gate-tests.sh` — 19
  passed, 0 failed (unmodified, unaffected).

## Hunt record

Before-landing hunt dispatched (stance 1/5 — cross-plugin cancelling
pair), tier default, cap 120s (diff 21-200 lines). Result: NO FINDING.
Full record: `docs/reports/2026-08-09-hunt-spec-alignment.md`.

## closed_checks

- acceptance-grep-four-fields (code_under_review: HEAD)
- acceptance-grep-loop-state-vocabulary (code_under_review: HEAD)
- record-gate-test-suite-33-cases (code_under_review: HEAD)
- proposal-gate-test-suite-regression (code_under_review: HEAD)
- order-check-test-suite-regression (code_under_review: HEAD)
- warrant-hunt-before-landing-stance-1 (code_under_review: HEAD)

## Open findings

None.
