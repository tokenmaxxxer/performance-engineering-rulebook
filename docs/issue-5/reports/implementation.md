# Record — issue-5: stub-check.sh canon 회수

loop_state: landed

## Why

core issue-69 (canon #69) decided that `stub-check.sh` — the
drift-recurrence detector itself — is core canon and is never vendored
into a rulebook, the same as the three role-agnostic gates already
converted in issue-2. This repo added a verbatim copy at
`performance-engineering/hooks/tests/stub-check.sh` during issue-2 phase 2
(commit `b511a0d`), before #69 landed. issue-5 tracks bringing this repo
in line with that later decision.

## Upstream basis

- core issue-69 / PR #71 (`tokenmaxxxer/tokenmaxxxer-core`, merged): pins
  `stub-check.sh` to core, bans rulebook copies, extends the script's own
  canon-file check to cover itself, and moves the checked-file list to
  `core/hooks/tests/canon-manifest.txt`.
- `docs/handbooks/role-gates-tests.md` (core repo) documents the canon
  invocation shape a rulebook uses instead of vendoring:
  `"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."`
- This repo's own phase-1 survey/proposal:
  `docs/issue-5/reports/implementation/current-state-survey.md`,
  `docs/issue-5/proposals/implementation.md`.
- Approval: issue-5 comment `APPROVE issue-5/implementation` by
  JiwonJung94 (single-account mode, contract v3 s19).

## What was done

Executed the approved proposal in one batch:

1. Deleted the vendored copy
   `performance-engineering/hooks/tests/stub-check.sh`. The now-empty
   parent directory `performance-engineering/hooks/tests/` was removed
   along with it.
2. `performance-engineering/hooks/hooks.json` — no edit needed, confirmed
   unchanged: it never registered `stub-check.sh` as a hook (survey
   finding, re-confirmed here), and no such entry was added back.
3. No other file in this repo referenced the vendored path.
4. Ran the core-reference invocation against
   `performance-engineering/hooks` and recorded the passing result below.

## Core-reference invocation and passing run

```
$ bash <core-plugin-root>/hooks/tests/stub-check.sh performance-engineering/hooks
stub-check: ok — no vendored 'trailer-gate.sh' under performance-engineering/hooks
stub-check: ok — no vendored 'record-fields-gate.sh' under performance-engineering/hooks
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under performance-engineering/hooks
stub-check: ok — no vendored 'parse-check.sh' under performance-engineering/hooks
stub-check: ok — no vendored 'stub-check.sh' under performance-engineering/hooks
stub-check: ok — performance-engineering/hooks/directive.sh is a role-directive stub
exit: 0
```

`<core-plugin-root>` was a local checkout of `tokenmaxxxer-core` at its
`issue-69/implementation` branch (containing merged core PR #71, current
with core `origin/main`), since this environment does not install this
rulebook as a plugin alongside core. In a real plugin install the same
invocation resolves via `${CLAUDE_PLUGIN_ROOT}/../core`.

## Open findings

- This checkout has no local `core/` directory (the proposal's noted
  risk). The invocation above therefore ran against an out-of-tree core
  checkout rather than a true plugin-root resolution; the exact
  `${CLAUDE_PLUGIN_ROOT}` sibling-resolution expression should still be
  verified against a real marketplace install before being relied on
  operationally, per core's own documented caveat.
- `docs/issue-2/reports/*` mentions of the old vendored invocation are
  historical and were left unedited, per the proposal's stated scope.
