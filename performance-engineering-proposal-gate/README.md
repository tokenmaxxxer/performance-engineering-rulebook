# performance-engineering-proposal-gate

Single responsibility: gates `docs/issue-<n>/proposals/*.md` writes for the
performance-engineering role's phase-1 proposal-norm — the 6
`methodology.md` (a) facets (numeric SLO, falsifiable telemetry-grounded
hypothesis, named method tied to this role's `YOU DECIDE` line, workload
characterization, premortem, evidence-citation format). Never touches
phase-2 records — that surface belongs to `performance-engineering-record-gate`.

## Trigger

`PreToolUse` on `Write|Edit|MultiEdit|NotebookEdit|Bash`, scoped by path
regex to `^docs/issue-[0-9]+/proposals/.*\.md$` (a `Bash` write is matched
by scanning path-shaped tokens in `tool_input.command`); any other path is
not this gate's business and passes through untouched.

## Behavior

Sources `core/hooks/lib/gate-lib.sh`/`gate-lib.py` (by reference, per
`docs/handbooks/canon-scripts.md`) for the fail-closed trap, kill-switch
convention, path normalization, and
Write/Edit/MultiEdit/NotebookEdit reconstruction, and this repo's own
`performance-engineering-order-check/hooks/section_lib.py` +
`heading-vocabulary.md` to scope each facet check to the document section
whose heading matches that facet's canonical group — a decoy word
elsewhere in the document, or a correctly-worded figure placed under the
wrong heading, no longer satisfies the check. Fails closed: unparseable
payload, missing `python3`, an undeterminable Edit/MultiEdit/Bash write,
or an internal error all deny (exit 2) rather than silently allow. A
denial names every missing facet by name and cites the `methodology.md`
subsection it traces to.

## Composition

Composes with, never replaces: `performance-engineering-order-check`
(intra-document section ordering) and core canon's generic
`record-fields-gate.sh`. Does not duplicate their logic.

## Kill switch

`export PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=1` (any other value,
including a typo, leaves the gate active — only a recognized on-spelling
disables it).

## Tests

`tests/run-gate-tests.sh` — facet-presence cases, section-scoped semantic
cases (bare-word decoy, numeric-less SLO, wrong-section figure), and the
gate-house six-case floor (replace_all Edit/MultiEdit, malformed JSON,
kill-switch garbage value, absolute/`./`-prefixed path, Bash-write
fail-closed). Run:
`CLAUDE_PLUGIN_ROOT_CORE=<core-checkout>/core bash performance-engineering-proposal-gate/tests/run-gate-tests.sh`
