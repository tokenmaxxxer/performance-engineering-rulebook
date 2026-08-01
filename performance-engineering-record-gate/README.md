# performance-engineering-record-gate

Single responsibility: gates the performance-engineering role's phase-2
record write surface (`docs/issue-<n>/reports/performance-engineering.md`)
on the 7 `methodology.md` (b) elements (methodology-cite, repro info,
workload-actual, percentile evidence, bottleneck-evidence linkage,
exit-criteria verdict, hand-off rationale). Never touches phase-1
proposals — that surface belongs to `performance-engineering-proposal-gate`.

## Trigger

`PreToolUse` on `Write|Edit|MultiEdit|NotebookEdit|Bash`, scoped by path
regex to `^docs/issue-[0-9]+/reports/performance-engineering\.md$` (a
`Bash` write is matched by scanning path-shaped tokens in
`tool_input.command`).

## Graceful exit

Recognizes a small set of legitimate early hand-off phrases (e.g.
"disproven at hypothesis stage"), checked whole-document on purpose
(a document-level early-exit signal, not a per-facet claim) and, when
present, does not require the elements downstream of that exit point — an
early, honest hand-off is not penalized for the work it correctly chose
not to do.

## Behavior

Sources `core/hooks/lib/gate-lib.sh`/`gate-lib.py` (by reference) for the
fail-closed trap, kill-switch convention, path normalization, and
Write/Edit/MultiEdit/NotebookEdit reconstruction, and this repo's own
`performance-engineering-order-check/hooks/section_lib.py` +
`heading-vocabulary.md` to scope each non-graceful-exit element check to
the section whose heading matches its canonical group. Fails closed:
unparseable payload, missing `python3`, an undeterminable
Edit/MultiEdit/Bash write, or an internal error all deny (exit 2). A
denial names every missing element by name and cites the `methodology.md`
subsection it traces to.

## Composition

Composes with, never replaces: `performance-engineering-order-check`
(intra-document ordering) and core canon's generic `record-fields-gate.sh`.

## Kill switch

`export PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=1` (any other value,
including a typo, leaves the gate active — only a recognized on-spelling
disables it).

## Tests

`tests/run-gate-tests.sh` — element-presence cases, a graceful-exit case,
a section-scoped semantic case (correctly-worded percentile figure in the
wrong section), and the gate-house six-case floor (replace_all
Edit/MultiEdit, malformed JSON, kill-switch garbage value,
absolute/`./`-prefixed path, Bash-write fail-closed). Run:
`CLAUDE_PLUGIN_ROOT_CORE=<core-checkout>/core bash performance-engineering-record-gate/tests/run-gate-tests.sh`
