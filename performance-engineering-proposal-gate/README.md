# performance-engineering-proposal-gate

Single responsibility: gates `docs/issue-<n>/proposals/*.md` writes for the
performance-engineering role's phase-1 proposal-norm — the 6
`methodology.md` (a) facets (numeric SLO, falsifiable telemetry-grounded
hypothesis, named method tied to this role's `YOU DECIDE` line, workload
characterization, premortem, evidence-citation format). Never touches
phase-2 records — that surface belongs to `performance-engineering-record-gate`.

## Trigger

`PreToolUse` on `Write|Edit|MultiEdit`, scoped by path regex to
`^docs/issue-[0-9]+/proposals/.*\.md$`; any other path is not this gate's
business and passes through untouched.

## Behavior

Fails closed: unparseable payload, missing `python3`, or an internal error
all deny (exit 2) rather than silently allow. A denial names every missing
facet by name and cites the `methodology.md` subsection it traces to.

## Composition

Composes with, never replaces: `performance-engineering-order-check`
(intra-document facet ordering) and core canon's generic
`record-fields-gate.sh`. Does not duplicate their logic.

## Kill switch

`export PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=1`

## Tests

`tests/run-gate-tests.sh` — 6 missing-facet cases (exit 2 each), 1
complete-compliant case (exit 0), 1 foreign-path scope case (exit 0).
Run: `bash performance-engineering-proposal-gate/tests/run-gate-tests.sh`
