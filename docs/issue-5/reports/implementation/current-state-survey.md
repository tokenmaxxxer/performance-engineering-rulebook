# Current-state survey: stub-check.sh vendored copy (issue-5)

## Context

core canon #69 confirms: `stub-check.sh` runs from the core installation
(`core/hooks/tests/stub-check.sh`) by reference; rulebooks must not vendor a
local copy (per `docs/handbooks/canon-scripts.md` — not present in this
repo's checkout; the canon decision is referenced from this repo's own
issue-2 survey/proposal docs and the issue-5 body). Issue-5 asks this
repository to remove its vendored copy and any `hooks.json` registration for
it, then record a core-reference stub-check pass.

## Findings

### 1. Vendored copies found

- `performance-engineering/hooks/tests/stub-check.sh` (89 lines, executable,
  md5 `5ea620382fd9d38f10a2769691aa48c4`).
  - Introduced in commit `b511a0d` ("core canon 참조 전환 실행 (issue-2 phase
    2) (#4)", 2026-07-31), as part of the issue-2 phase-2 execution that
    vendored this file "the way `parse-check.sh` already is" (per the
    file's own header comment) and recorded a passing run in
    `docs/issue-2/reports/implementation.md`.
  - This is the only copy in the repository. No older/stale duplicate
    exists elsewhere (checked full repo tree, single `find -name
    'stub-check.sh'` hit).
  - Content is current as of the issue-2 landing commit (~same day as this
    survey); no drift observed against its own header/self-description.

### 2. hooks.json registration

- `performance-engineering/hooks/hooks.json` registers only one hook today:
  `SessionStart` → `${CLAUDE_PLUGIN_ROOT}/hooks/directive.sh`.
- `stub-check.sh` is **not** referenced from `hooks.json` at all — it has no
  `SessionStart`/other hook entry. It appears to be invoked manually / by a
  CI or review harness outside this repo's own hook wiring (issue-2's
  report shows it invoked directly: `bash
  performance-engineering/hooks/tests/stub-check.sh performance-engineering/hooks`).
- No other JSON config in the repo (`.claude-plugin/marketplace.json`,
  `performance-engineering/.claude-plugin/plugin.json`, `.mcp.json`,
  `.claude/*.json`) references `stub-check.sh`.
- No `.github/` workflows exist in this repo that invoke it either.

### 3. Other stub-check.sh mentions (non-code, documentation only)

- `docs/issue-2/proposals/implementation.md`, `docs/issue-2/reports/implementation.md`,
  `docs/issue-2/reports/implementation/survey.md` — narrative references
  from the issue-2 phase-1/phase-2 work; these are historical record files
  and are out of scope for issue-5's cleanup (not vendored code, not
  hooks.json registrations).

## Summary table

| Item | Location | Canon reference or local copy? | Action needed |
|---|---|---|---|
| Vendored script | `performance-engineering/hooks/tests/stub-check.sh` | Local copy (verbatim vendor) | Delete; run via core reference instead |
| hooks.json entry | `performance-engineering/hooks/hooks.json` | No entry present | None (nothing to remove) — confirm no entry is (re)added when switching to core-reference execution |
| directive.sh | `performance-engineering/hooks/directive.sh` | Already a core-reference stub (issue-2 phase 2) | No change |

## Open question

`docs/handbooks/canon-scripts.md`, the canon decision doc named in the
issue-5 body, does not exist in this repository's checkout (not under
`docs/handbooks/` or anywhere else). It likely lives in the separate core
repo. The phase-2 proposal should state the assumed core-reference
invocation path as a documented assumption pending confirmation from that
doc, rather than block on it.
