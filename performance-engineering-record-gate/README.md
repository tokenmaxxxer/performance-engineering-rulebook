# performance-engineering-record-gate

Single responsibility: gates the performance-engineering role's phase-2
record write surface (`docs/issue-<n>/reports/performance-engineering.md`)
on the 7 `methodology.md` (b) elements (methodology-cite, repro info,
workload-actual, percentile evidence, bottleneck-evidence linkage,
exit-criteria verdict, hand-off rationale). Never touches phase-1
proposals — that surface belongs to `performance-engineering-proposal-gate`.

## Trigger

`PreToolUse` on `Write|Edit|MultiEdit`, scoped by path regex to
`^docs/issue-[0-9]+/reports/performance-engineering\.md$`.

## Graceful exit

Recognizes a small set of legitimate early hand-off phrases (e.g.
"disproven at hypothesis stage") and, when present, does not require the
elements downstream of that exit point — an early, honest hand-off is not
penalized for the work it correctly chose not to do.

## Behavior

Fails closed: unparseable payload, missing `python3`, or an internal error
all deny (exit 2). A denial names every missing element by name and cites
the `methodology.md` subsection it traces to.

## Composition

Composes with, never replaces: `performance-engineering-order-check`
(intra-document ordering) and core canon's generic `record-fields-gate.sh`.

## Kill switch

`export PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=1`

## Tests

`tests/run-gate-tests.sh` — 7 missing-element cases (exit 2 each), 1
complete-compliant case (exit 0), 1 graceful-exit case (exit 0), 1
foreign-path scope case (exit 0).
Run: `bash performance-engineering-record-gate/tests/run-gate-tests.sh`
