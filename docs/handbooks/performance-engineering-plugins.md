# Handbook: performance-engineering plugin set

Operational reference for the 6 plugins that implement this role's
methodology enforcement (issue-10), gate-A+-remediated in issue-13. See
`docs/issue-10/proposals/methodology-enforcement.md` for the original
design rationale, `docs/issue-10/reports/performance-engineering.md` for
what was originally built, and
`docs/issue-13/proposals/gate-a-plus-remediation.md` +
`docs/issue-13/reports/performance-engineering.md` for the gate-house
migration (core `gate-lib.sh`/`gate-lib.py` adoption, section-scoped
semantic checks) and what was actually built for it.

## `core` plugin dependency (issue-13)

`performance-engineering-proposal-gate`, `performance-engineering-record-gate`,
and `performance-engineering-order-check` all source
`core/hooks/lib/gate-lib.sh` (bash) and load `core/hooks/lib/gate-lib.py`
(Python, via `importlib`) by reference — never vendored, per
`docs/handbooks/canon-scripts.md` (`tokenmaxxxer-core`). Resolved via
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
