# Record — issue-2: core canon 참조 전환

loop_state: landed

## Why

Core landed a single canon for the warrant-hunt agent (core issue-63) and
the three role-agnostic gates (core issue-66), registered core-side. This
role's own vendored copies were drift risk from that point on — issue-2
tracks the one-time conversion to reference canon instead of carrying local
copies. The issue's own sequencing note requires this conversion to land
before any '룰북 성숙화' phase-2 work in this repo (none currently open, so
nothing was blocked).

## Upstream basis

- core issue-63: `warrant` plugin (agent + proportional hunt cadence +
  mechanical guards) landed at `tokenmaxxxer-core/core/warrant/`.
- core issue-66: `core/hooks/hooks.json` registers `trailer-gate.sh`,
  `record-fields-gate.sh`, `handbook-trigger-gate.sh` globally for every
  plugin install; `core/hooks/lib/role-directive.sh` factors the
  directive.sh boilerplate into `core_role_directive`; `core/hooks/tests/
  stub-check.sh` is the drift-recurrence detector every rulebook vendors.
- This repo's own phase-1 survey/proposal:
  `docs/issue-2/reports/implementation/survey.md`,
  `docs/issue-2/proposals/implementation.md`.
- Approval: issue-2 comment `APPROVE issue-2/implementation` by
  JiwonJung94 (single-account mode, contract v3 s19).

## What was done

Executed the approved proposal in one batch:

1. Deleted `performance-engineering/agents/warrant-hunter.md`. Core's
   `warrant` plugin now owns the agent and hunt cadence; this role's copy
   carried no stances beyond an unfilled skeleton.
2. Deleted `performance-engineering/hooks/{trailer-gate.sh,
   record-fields-gate.sh,handbook-trigger-gate.sh}` and removed their
   `PreToolUse` entries from `performance-engineering/hooks/hooks.json`.
   `hooks.json` now registers only the `SessionStart` → `directive.sh`
   entry; core's `core/hooks/hooks.json` fires all three gates globally
   for every plugin install.
3. Replaced `performance-engineering/hooks/directive.sh` with the stub
   form: sources `core/hooks/lib/role-directive.sh` and calls
   `core_role_directive` with this role's four unique values (`you_decide`,
   `use_when`, `produces`, `hand_off`). `WRITE_SCOPE` (role-unique) was
   folded into the `produces` argument alongside `PRODUCES`, since
   `core_role_directive` takes exactly four values. The old `BOUNDARY CASE`
   paragraph was dropped — it restated contract v3 boilerplate already
   covered by core's own `[core] Interaction protocol` SessionStart text,
   not role-unique content. The phase-1 proposal's open question (whether
   a `trap`/`set -uo pipefail` pair is still needed locally) is resolved by
   `stub-check.sh`'s own structural check: it rejects any non-stub line,
   including a local trap/pipefail pair, so the stub carries none —
   matching the pattern already landed in other converted rulebooks (e.g.
   `qa/hooks/directive.sh` in the execution-observation rulebook).
4. `RECORD_FIELDS_TERMINAL_STATES`: not set. This role's prior
   `record-fields-gate.sh` copy had no loop_state/terminal-state concept at
   all (produces-field presence only), so there is no divergent
   terminal-state value to preserve — core's default (`landed`) applies,
   consistent with this record's own `loop_state` line above.
5. Vendored `core/hooks/tests/stub-check.sh` into
   `performance-engineering/hooks/tests/stub-check.sh` (copied verbatim
   from `tokenmaxxxer-core`, per its own header — distributed the same way
   as `parse-check.sh`) and ran it against `performance-engineering/hooks/`.

## stub-check.sh result

```
$ bash performance-engineering/hooks/tests/stub-check.sh performance-engineering/hooks
stub-check: ok — no vendored 'trailer-gate.sh' under performance-engineering/hooks
stub-check: ok — no vendored 'record-fields-gate.sh' under performance-engineering/hooks
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under performance-engineering/hooks
stub-check: ok — no vendored 'parse-check.sh' under performance-engineering/hooks
stub-check: ok — performance-engineering/hooks/directive.sh is a role-directive stub
exit 0
```

PASS.

## Open findings

- Not vendored in this pass: `parse-check.sh` under
  `performance-engineering/hooks/tests/`. The repo had no pre-existing
  `hooks/tests/` directory and `parse-check.sh` is not one of this issue's
  five action items. Flagged for a future issue if this repo comes to need
  it — not blocking, `stub-check.sh` already checks its absence
  correctly (reports "ok" either way).
- No other open findings; all five action items from the issue and the
  approved proposal are complete and verified.
