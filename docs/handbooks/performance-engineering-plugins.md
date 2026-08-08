# Handbook: performance-engineering plugin set

Operational reference for the 6 plugins that implement this role's
methodology enforcement (issue-10), gate-A+-remediated in issue-13 and
re-audit-closed out in issue-16. See
`docs/issue-10/proposals/methodology-enforcement.md` for the original
design rationale, `docs/issue-10/reports/performance-engineering.md` for
what was originally built,
`docs/issue-13/proposals/gate-a-plus-remediation.md` +
`docs/issue-13/reports/performance-engineering.md` for the gate-house
migration (core `gate-lib.sh`/`gate-lib.py` adoption, section-scoped
semantic checks), and
`docs/issue-16/proposals/gate-a-plus-final-remediation.md` +
`docs/issue-16/reports/performance-engineering.md` for the re-audit
closeout (hooks.json matcher/coverage parity, core-#75's guarded
gate-lib.sh source, word-boundary/negation-aware section_lib.py
substring checks, `gate_lib.gate_bash_write_targets` referenced instead
of duplicated).

## `core` plugin dependency (issue-13)

`performance-engineering-proposal-gate`, `performance-engineering-record-gate`,
and `performance-engineering-order-check` all source
`core/hooks/lib/gate-lib.sh` (bash) and load `core/hooks/lib/gate-lib.py`
(Python, via `importlib`) by reference — never vendored, per
`docs/handbooks/canon-scripts.md` (`tokenmaxxxer-core`). Per issue-16, all
three gates' source line is `||`-guarded
(`. ".../gate-lib.sh" || { echo "...: cannot source gate-lib.sh" >&2; exit 2; }`,
core-#75's confirmed shape) so a missing/unreachable core fails closed
(deny) instead of silently letting every downstream `gate_kill_switch_active`
call misread the missing function as kill-switch-off; all three also call
`gate_lib.gate_bash_write_targets(cmd)` for Bash-write token scanning
instead of duplicating the regex inline. Resolved via
`${CLAUDE_PLUGIN_ROOT_CORE:-<repo-root>/../../core}` at runtime, the same
convention `performance-engineering/hooks/directive.sh` already uses for
`role-directive.sh`. Requires the `tokenmaxxxer-core` marketplace/plugin
installed alongside this repo; the test suites below set
`CLAUDE_PLUGIN_ROOT_CORE` directly to a local checkout.

The same three gates also load
`performance-engineering-order-check/hooks/section_lib.py` (private to
this repo, not core canon) and the extended
`performance-engineering-order-check/hooks/heading-vocabulary.md` to scope
each facet/order check to the document section whose heading matches that
facet's canonical group, instead of a whole-document substring search.

## Plugins and their kill switches

| Plugin | Purpose | Kill switch |
|---|---|---|
| `performance-engineering` | Role identity + SessionStart orientation | `PERFORMANCE_ENGINEERING_CYCLE_OFF=1` |
| `performance-engineering-proposal-gate` | Phase-1 proposal facet gate | `PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=1` |
| `performance-engineering-record-gate` | Phase-2 record element gate | `PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=1` |
| `performance-engineering-order-check` | Intra-document section-order check | `PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=1` |
| `performance-engineering-checklist` | Human-facing authoring checklist (no gate) | n/a — never blocks |
| `performance-engineering-session-informer` | Non-blocking SessionStart informer | `PERFORMANCE_ENGINEERING_SESSION_INFORMER_OFF=1` |

## issue-19 spec-alignment (`roles/specs/performance-engineering.spec.json`)

`performance-engineering-record-gate/hooks/record-gate.sh` also enforces
the marketplace spec's four required phase-2 record fields and its
`loop_state` vocabulary, layered on the 7 methodology.md (b) elements
above, none replaced: `sli:` and `error_budget_remaining:` (new
`sli`/`error-budget` heading-vocabulary.md groups scope them to the
Evidence and a new Error-Budget section respectively), `verdict:`
(`within-budget`/`exhausted`, Exit-Criteria section), and frontmatter
`loop_state:` closed to `landed`/`measuring`/`metric-unreachable`/
`reviewing`/`slo-undeclared` (denies only when present-and-invalid).
`slo_target` maps onto the existing phase-1 `numeric SLO` facet
(`performance-engineering-proposal-gate`'s `slo` group) rather than a new
phase-2 check — see `docs/issue-19/proposals/spec-alignment.md`'s
Rationale. `run-gate-tests.sh` carries matching fixture cases.

## Running each plugin's gate tests

```
bash performance-engineering-proposal-gate/tests/run-gate-tests.sh
bash performance-engineering-record-gate/tests/run-gate-tests.sh
bash performance-engineering-order-check/tests/run-gate-tests.sh
```

Each script spawns its own gate as a real subprocess against synthetic
tool-call payloads in a disposable temp git repo; no shared fixtures, no
repo-root `tests/` directory — each plugin owns its own.

## Adding a new plugin to this set

1. New top-level dir sibling to the existing `performance-engineering-*`
   dirs, with its own `.claude-plugin/plugin.json`, `hooks/` (if it gates
   or informs), `tests/` (if it gates), and `README.md`.
2. Register it in the repo-root `.claude-plugin/marketplace.json`.
3. If the plugin owns a gate, give it its own kill-switch env var,
   documented in its own `README.md` and added to the table above.
4. Do not place plugin-local content under a nested `docs/` — this repo's
   `docs/` tree is reserved for the standing six buckets and per-issue
   trees at repo root (`board-gate.sh` enforces this); put plugin-local
   reference content at the plugin's own root instead (see
   `performance-engineering-checklist/checklist.md`).
