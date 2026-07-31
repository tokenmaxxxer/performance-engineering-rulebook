# Proposal — issue-2: core canon 참조 전환

Phase 1 only. No execution work below is done in this PR; it lands in
phase 2 after an approvers.md Approve.

## Mapping to the issue's 5 작업 항목

### 1. warrant-hunter 복사본 제거 → core canon 참조

Delete `performance-engineering/agents/warrant-hunter.md`. Core's `warrant`
plugin now owns the agent definition (`core/warrant/agents/warrant-hunter.md`)
plus the proportional hunt cadence in `core/warrant/hooks/directive.sh`
(3-tier wall-clock cap by diff size, docs-only fast path, miss-streak tier
drop) and its mechanical guards (`hunt-guard.sh`, `scope-gate.sh`,
`state.sh`). This role's local copy carried no stances beyond an unfilled
skeleton and a hand-off line already duplicated in `directive.sh`'s
HAND-OFF field — nothing role-unique is lost by deleting it. Rollout is
picking up the `warrant` plugin from `tokenmaxxxer-core`'s marketplace
(see item 3's open question — same mechanism `directive.sh`'s stub needs).

### 2. 3종 게이트 복사본 + 훅 등록 제거

Delete `performance-engineering/hooks/{trailer-gate.sh,
record-fields-gate.sh,handbook-trigger-gate.sh}` and remove their three
entries from `performance-engineering/hooks/hooks.json`'s `PreToolUse`
block (the `directive.sh` SessionStart entry stays — item 3 replaces its
target file's content, not its registration). Core's `core/hooks/hooks.json`
now fires all three globally for every plugin install (issue-66's approver
decision: core-side registration, not per-rulebook) — no replacement entry
is added here.

One behavior change to flag, not silently absorb: this role's vendored
`record-fields-gate.sh` checks only produces-field presence
(`performance-budget`/`profiling-evidence`/`bottleneck-list`) against the
literal path suffix `/reports/performance-engineering.md`. Core's canon
version checks a different, broader §20 field set (what-was-done / why /
upstream-basis / loop_state / open-findings, plus next-steps +
resolution-path when `loop_state` is non-terminal) against
`docs/issue-<n>/reports/${CLAUDE_ROLE}.md` — a strict superset in rigor
but it does **not** know this role's specific three produces fields at all.
Those three fields are role content, not gate logic; item 3's directive
stub carries them forward in its PRODUCES value, which is what a future
record author reads, but nothing mechanically re-enforces "these three
literal words must appear in the record" after this deletion. Flagging as
accepted per the issue's own instruction ("복사본과 그 훅 등록 제거 → core
쪽 등록이 대체") rather than deciding unilaterally to keep a narrower local
gate alongside the canon one.

The role-specific `handbook-trigger-gate.sh` placeholder comment already
questioned whether a report-only role (`write_scope: []`) needs this gate
at all — moot after deletion; core's canon copy runs for every role
uniformly and this role's empty write_scope means it will essentially never
match an operational-surface file.

### 3. directive.sh → stub 형식 교체

Replace `performance-engineering/hooks/directive.sh` body with:

```sh
#!/usr/bin/env bash
trap 'rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then exit 2; fi' EXIT
set -uo pipefail
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive \
  "YOU DECIDE: 부하/지연 목표를 만족하는가" \
  "USE_WHEN: 성능 예산이 걸린 설계/회귀일 때" \
  "PRODUCES (required record fields): performance budget, profiling evidence, bottleneck list" \
  "WRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)
HAND-OFF: 용량 증설 타이밍이 걸리면 → capacity-planning"
```

This keeps the `trap`/`set -uo pipefail` pair local per
`core/docs/issue-66/reports/implementation.md`'s explicit note that a trap
inside the sourced function cannot catch the sourcing script's own abnormal
exit — the one piece core's factoring could not remove. The two role-unique
lines this role's old output had beyond core's four-arg shape
(`WRITE_SCOPE` and `BOUNDARY CASE`) are folded: `WRITE_SCOPE` into the
fourth (`hand_off`) argument alongside `HAND-OFF` since
`core_role_directive` takes exactly four values — the `BOUNDARY CASE`
paragraph is dropped as it restates contract v3 boilerplate already in
core's own protocol text (SessionStart's `[core] Interaction protocol`
block), not role-unique content.

**Open question for the approver**: `role-directive.sh`'s own usage comment
resolves the core plugin's path via
`${CLAUDE_PLUGIN_ROOT_CORE:-$(...)/../../core}` — an env var with a
sibling-directory fallback. This repo's `.claude-plugin/marketplace.json`
lists only the `performance-engineering` plugin; there is no visible
declaration here of a dependency on `tokenmaxxxer-core`'s marketplace, and
survey found no local evidence for how the `[core] Interaction protocol`
text this session's own SessionStart printed was actually sourced. Two
resolutions:
(a) the harness/user has installed the `tokenmaxxxer-core` marketplace
    alongside this one out-of-band (nothing to change in this repo), and
    the stub above is correct as written once `CLAUDE_PLUGIN_ROOT_CORE` is
    set at runtime; or
(b) this repo's own `.claude-plugin/marketplace.json` (or a project
    `.claude/settings.json`) needs an explicit reference to
    `tokenmaxxxer-core` added so the sibling-fallback path resolves.
Phase 1 does not decide between these — needs approver confirmation before
phase 2 writes the stub, since (b) would add a file this proposal does not
currently scope.

### 4. RECORD_FIELDS_TERMINAL_STATES

Survey found this role's current `record-fields-gate.sh` copy has no
loop_state/terminal-state concept at all (checks produces-fields only), so
there is no existing divergent terminal-state value to preserve. Proposed:
do not set `RECORD_FIELDS_TERMINAL_STATES` — accept core's default
(`landed`). This role's own directive stub's `RECORD:` line (rendered by
`core_role_directive`) and this repo's role-handoff contract both already
use `loop_state: delivered`/`landed`-shaped terminal values consistent with
core's default; no role-specific override is warranted unless the approver
knows otherwise.

### 5. stub-check.sh 통과 확인

Phase 2 fetches `core/hooks/tests/stub-check.sh` (distributed the same way
`parse-check.sh` already is, per its own header) into this repo's
`performance-engineering/hooks/tests/`, runs it against
`performance-engineering/hooks/`, and records the pass/fail output in
`docs/issue-2/reports/implementation.md` per item 5. This repo currently
has no `hooks/tests/` directory at all — phase 2 also needs to confirm
whether `parse-check.sh` (already core canon per issue-66's implementation
record) should be vendored locally too, or whether stub-check's own
absence-based check for `parse-check.sh` as a *rulebook-local* file means
one should exist here that source-references core rather than duplicating
logic. Not resolved in phase 1 — flagged for phase 2 investigation since it
does not block the proposal decision above.

## Sequencing note

Issue-2's own 순서 제약 (전환 완료 후 '룰북 성숙화' phase 2) is
orthogonal to this repo's contract v3 phase-1/phase-2 split — noted, not
acted on, since no 룰북 성숙화 issue is open in this repo currently.
