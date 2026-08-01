# performance-engineering-rulebook

Rulebook for the `performance-engineering` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-3 promotion and
generated as skeleton scaffolding by issue-170.

- **decides**: 부하/지연 목표를 만족하는가
- **use_when**: 성능 예산이 걸린 설계/회귀일 때
- **produces**: performance budget, profiling evidence, bottleneck list
- **write_scope**: []
- **hand-off**: 용량 증설 타이밍이 걸리면 → capacity-planning

## Install

```
claude plugin marketplace add tokenmaxxxer/performance-engineering-rulebook
claude plugin install performance-engineering
```

## Layout

This repo ships one plugin set: a session-informer, three PreToolUse
enforcement gates, and a plain checklist doc, one plugin directory each.

- `performance-engineering/.claude-plugin/plugin.json` — plugin manifest
- `performance-engineering/hooks/hooks.json` — SessionStart wiring
- `performance-engineering/hooks/directive.sh` — SessionStart role directive
  (sources `hooks/lib/role-directive.sh` from the `core` plugin, referenced
  never vendored)
- `performance-engineering-session-informer/hooks/hooks.json` +
  `hooks/state.sh` — SessionStart repo/issue-state briefing (branch, issue
  number, existing PRs, phase-1/phase-2 file presence)
- `performance-engineering-checklist/checklist.md` — plain-text methodology
  checklist, not a gate
- `performance-engineering-proposal-gate/hooks/proposal-gate.sh` —
  PreToolUse gate on `docs/issue-<n>/proposals/*.md`: enforces the 6
  methodology.md (a) facets (numeric SLO, falsifiable hypothesis, named
  method, workload characterization, premortem, evidence-citation), each
  checked inside the section whose heading matches that facet's group in
  `heading-vocabulary.md`. Kill switch:
  `PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF`.
- `performance-engineering-record-gate/hooks/record-gate.sh` — PreToolUse
  gate on `docs/issue-<n>/reports/performance-engineering.md`: enforces
  the 7 methodology.md (b) elements (methodology-cite, repro info,
  workload-actual, percentile evidence, bottleneck-evidence linkage,
  exit-criteria verdict, hand-off rationale), same section-scoped
  checking, with a graceful-exit phrase set that legitimately skips the
  downstream elements. Kill switch:
  `PERFORMANCE_ENGINEERING_RECORD_GATE_OFF`.
- `performance-engineering-order-check/hooks/order-check.sh` — PreToolUse
  gate firing on both write surfaces above: when both a workload-group and
  an evidence-group section exist in a document, the workload section must
  come first. Kill switch: `PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF`.
- `performance-engineering-order-check/hooks/heading-vocabulary.md` —
  single-sourced heading-phrase-group list, loaded at runtime by all three
  gates above (never duplicated).
- `performance-engineering-order-check/hooks/section_lib.py` —
  private, role-specific document-section-splitting helper (not core
  canon) shared by all three gates' Python judges.
- `performance-engineering-*/tests/run-gate-tests.sh` — each gate's own
  test suite, run as a real subprocess against fixture payloads.
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

### `core` plugin dependency

All three gates above source `core/hooks/lib/gate-lib.sh` (bash) and load
`core/hooks/lib/gate-lib.py` (Python, via `importlib`) for the fail-closed
trap, kill-switch convention, path normalization, and
Write/Edit/MultiEdit/NotebookEdit reconstruction — by reference, per
`docs/handbooks/canon-scripts.md`'s reference-not-copy rule, never
vendored into this repo. Resolved via
`${CLAUDE_PLUGIN_ROOT_CORE:-<repo-root>/../../core}` at runtime (the same
convention `performance-engineering/hooks/directive.sh` already uses for
`role-directive.sh`); the test suites set `CLAUDE_PLUGIN_ROOT_CORE`
directly to a local `tokenmaxxxer-core` checkout. Requires the
`tokenmaxxxer-core` marketplace/plugin installed alongside this repo.

This is a working rulebook, not scaffolding: the gates above are the
role-specific progress enforcement; further doctrine/handoff detail can
still be layered on top.
