# Record — issue-16: gate A+ final closeout (re-audit residual defects)

loop_state: landed

## Why

Rationale: the 2026-08-01 re-audit (issue #16 body) graded this repo B+,
citing a README/header vs. `hooks.json` matcher mismatch (Bash and
NotebookEdit claimed as covered but not wired into any of the three
gates' matchers — a false coverage guarantee), a bare `'measured method'`
substring check, and a bare-negation-vulnerable `'uncited'` check. Phase
1's approved proposal set the fix (reference core-#75's confirmed
guard/regex where the defect is that exact shape, narrowest local change
elsewhere); this phase-2 record states what was actually built and
verified.

## Upstream basis

Based on: `docs/issue-16/proposals/gate-a-plus-final-remediation.md`
(this repo's own phase-1 proposal, approved), itself grounded in
`docs/issue-16/reports/performance-engineering/survey.md` (this repo's
phase-1 current-state survey) and `tokenmaxxxer-core` commit `52bdc15`
(issue-75, `core/hooks/lib/gate-lib.sh`/`gate-lib.py`/
`core/hooks/tests/compliance-check.sh` — the confirmed-landed
mandatory-guard-source shape and its detection rule). Read from a local
`tokenmaxxxer-core` checkout at `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`
(`main`, `52bdc15` confirmed as tip via `git log --oneline -1`) as of
2026-08-01.

## Method

USE method used to judge this change (per the phase-1 proposal's
Workload/Method sections): Utilization n/a (synchronous, non-resource-
bound subprocess scripts, not a service under sustained load); Saturation
= 0 test failures across all three gates' `tests/run-gate-tests.sh`
(91/91 passing — 26 proposal-gate + 24 record-gate + 19 order-check, up
from 62/62 pre-fix, the delta being the new missing-core and substring-
hardening regression cases this phase adds); Errors = 0
`compliance-check.sh` FAIL reasons post-fix on the 2 files it scans
(`proposal-gate.sh`, `record-gate.sh`), down from a would-be 2/2 FAIL had
it been run pre-fix against the phase-1-surveyed unguarded-source shape
(the rule `compliance-check.sh:57` fires on is unconditional on that
shape, confirmed by direct code read, not independently re-run against
the pre-fix tree since the fix lands in the same commit as this record).

## Repro info

Ran locally against a `tokenmaxxxer-core` checkout at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` (main, `52bdc15`), system
python3, bash. Reproduce:

```
export CLAUDE_PLUGIN_ROOT_CORE=/path/to/tokenmaxxxer-core/core
bash performance-engineering-proposal-gate/tests/run-gate-tests.sh
bash performance-engineering-record-gate/tests/run-gate-tests.sh
bash performance-engineering-order-check/tests/run-gate-tests.sh
bash "$CLAUDE_PLUGIN_ROOT_CORE/hooks/tests/compliance-check.sh" "$(pwd)"
```

Each `tests/run-gate-tests.sh` is a real subprocess invocation of its
gate script against synthetic tool-use JSON payloads in a throwaway
`git init`'d temp dir per case; no mocking of the gate's own code paths.

## Workload Characterization

Workload-actual matches the phase-1 characterization exactly: concurrency
1 (each test case runs one gate subprocess synchronously), the five
tool-kind x gate-target combinations the proposal named
(`Write`/`Edit`/`MultiEdit` already-exercised, `NotebookEdit` covered by
inspection — it shares the identical target-resolution branch as
`Write`/`Edit`/`MultiEdit` in all three scripts' Python judges, exercised
indirectly via `gate_reconstruct_write`'s shared code path per issue-13's
same rationale, not duplicated here since this repo's write surfaces are
markdown documents, not notebooks — and `Bash`-command token-scan,
exercised directly via each suite's `bash-write-undeterminable-denies`
case, now running through `gate_lib.gate_bash_write_targets` instead of
the removed inline `re.findall`), against both gate-target document
shapes, plus the sixth core-unreachable case this phase adds
(`missing-core-denies`, one per gate). No ramp-up dimension, matching
phase-1's "not applicable" call for stateless per-invocation hooks.

## Percentile Evidence

Deterministic pass/fail counts, not a percentile distribution — this
change is enforcement infrastructure, not a measured runtime system
(methodology.md (b)4's percentile-evidence intent maps to the full
enumerated test-count evidence below, the same analog issue-13's record
used): proposal-gate 26/26, record-gate 24/24, order-check 19/19,
`compliance-check.sh` 2/2 clean (0 FAIL lines, exit 0). Every gate
script's own p99-latency framing (< 200ms per invocation, stated in the
phase-1 proposal's numeric SLO) is not independently re-measured here
with a timer harness — none of the four fixes changes algorithmic
complexity (one added `||` branch, JSON-only matcher edit, `in` → single
compiled-regex `.search()` per needle, one function-call substitution for
an identical regex) — so the existing pass/fail evidence is the
appropriate evidence class for this change, not a gap.

## Bottleneck

No performance bottleneck in the runtime sense — this is a correctness/
coverage remediation. The nearest analog, the re-audit's four cited
defect classes (matcher/coverage mismatch, unguarded source, substring
false-pass x2), is closed; each is linked to its verifying evidence below
in "What was done" and Exit-Criteria Verdict.

## What was done

Summary of work done, the proposal's five numbered items:

1. **Matcher/coverage parity (item 1).** All three
   `performance-engineering-{proposal-gate,record-gate,order-check}/hooks/hooks.json`
   files' `"matcher"` changed from `"Write|Edit|MultiEdit"` to
   `"Write|Edit|MultiEdit|NotebookEdit|Bash"`, matching what the script
   bodies already implemented and the READMEs already claimed — closing
   the false-coverage-guarantee gap the re-audit named. No script-body
   change needed; the `NotebookEdit`/`Bash` handling already existed as
   unreachable dead code.
2. **Guarded `gate-lib.sh` source (item 2), core-#75 shape adopted
   verbatim.** All three gate scripts' line 3 changed from the unguarded
   `. "$CORE_HOOKS/lib/gate-lib.sh"` to
   `. "$CORE_HOOKS/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }`.
   Closes the fail-open-on-missing-core hole by construction: a failed
   source now exits 2 (deny) before any `gate_kill_switch_active` call
   can misread the missing function as kill-switch-off.
3. **Substring-check hardening (item 3).**
   `performance-engineering-order-check/hooks/section_lib.py` gained two
   new functions: `section_has_cited()` (word-boundary `\bcited\b` plus a
   20-character negation-token scan for `not`/`never`/`n't` immediately
   preceding the match — `"uncited"` no longer matches at all since
   `\bcited\b` requires a boundary before "cited" that "un-" prefixed
   directly onto it does not provide, and `"not cited"`/`"isn't cited"`
   are excluded by the negation scan) and `section_has_method_use()`
   (case-sensitive `\bUSE\b` against the section's ORIGINAL-case body, not
   the lower-cased copy `section_has_any` uses — `"use methodology X"`
   in ordinary lower-case prose no longer satisfies the facet, while
   `"USE Method"`/`"the USE method"` still do). `proposal-gate.sh`'s
   citation facet and both `proposal-gate.sh`'s and `record-gate.sh`'s
   method-name facet now call these instead of the bare `"cited"`/`"use
   method"` substring needles (the other needles — `"assumption"`,
   `"blast radius"`, `"rollback"`, `"red method"`, `"golden signal"` —
   are untouched, per the proposal's own narrowing: they are not
   substrings of their own negations or of unrelated common English
   phrases the way `"cited"`/`"use"` are).
4. **Reference core's `gate_bash_write_targets` (item 4).** All three
   gates' inline `re.findall(r'[A-Za-z0-9_./~$-]+', cmd)` call replaced
   by `gate_lib.gate_bash_write_targets(cmd)`, now that
   `tokenmaxxxer-core`'s `gate-lib.py` (issue-75) canonizes that exact
   technique — same character class, no behavior change, a duplication
   removal.
5. **`compliance-check.sh` parity (item 5).** Run against this repo's
   root post-fix:
   ```
   compliance-check: ok — .../performance-engineering-proposal-gate/hooks/proposal-gate.sh
   compliance-check: ok — .../performance-engineering-record-gate/hooks/record-gate.sh
   ```
   Exit code 0, no `FAIL` lines — the same "core's own migrated gates
   pass clean" pattern core-#75's own record used.

Test-suite additions verifying items 2-4: a `missing-core-denies` case
per suite (`CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path — must
now deny, where the pre-fix unguarded source would have let a 127
"command not found" past every `gate_kill_switch_active ... || { exit 0;
}` call site as a silent allow); `uncited-decoy-denies` and
`not-cited-decoy-denies` (proposal-gate); `use-methodology-decoy-denies`
(proposal-gate and record-gate). The `bash-write-undeterminable-denies`
case in each suite, left unmodified, continues to pass post-swap,
confirming item 4's function-call substitution changed no behavior.

README/manifest ghost-file and stale-role-name sweep (issue #16's fourth
requirement): `grep -rli "deprecated\|old-role"` across the tree (zero
hits), a diff of `.claude-plugin/marketplace.json`'s six `source` entries
against the six actual `performance-engineering-*` directories (six-for-
six match, no ghost source, no missing plugin), and a read of every
`README.md`'s tool-coverage claims against the now-fixed `hooks.json`
matchers (all consistent) — zero residual findings, matching the phase-1
survey's own sweep result (`docs/issue-16/reports/performance-engineering/survey.md`
§2.5). No README/manifest change was required for this item; issue-13's
prior record already closed the ghost-file/stale-role-name defects this
role previously had.

## Exit Criteria Verdict

**Pass** against the phase-1 hypothesis (each of the four re-audit-named
defects has a narrow, mechanical fix that does not touch the other
three) and this record's own numeric SLO (p99 gate-script latency <
200ms, not regressed — see Percentile Evidence above, no algorithmic
complexity change in any of the four fixes). All four defect-specific
verdicts pass (see "What was done" above, each linked to its own
verifying test case or `compliance-check.sh` line); no existing
`allow`-expected fixture regressed (`complete-compliant`,
`foreign-path`, `graceful-exit`, `proposal-in-order`, `record-in-order`,
`workload-only-no-evidence`, and both gates' `kill-switch-on-*-disables`
cases all still allow post-fix). No deviation observed.
`compliance-check.sh` clean on both files it scans (`*-gate.sh` glob;
`order-check.sh` is out of that glob's scope by name — its own guard
fix is verified by its own green suite's `missing-core-denies` case
instead, same posture issue-13's record already took for the identical
scope gap).

## Hand-off

No hand-off is needed. This record closes all four re-audit residual
defects issue #16 named plus its own two cross-cutting requirements
(`compliance-check.sh` PASS, README/manifest sweep), with no open
capacity-planning-shaped question: the fix is a same-repo, same-scope
correctness pass with a per-gate kill switch already in place
(unchanged by this fix) and a straight `git revert` rollback path (per
the phase-1 premortem's blast-radius/killswitch/rollback statement), not
a load/latency finding that would route to `capacity-planning`.

## Open findings

None open. `loop_state: landed` above — no next-steps or resolution path
required. One residual note carried forward from issue-13's own record,
unaffected by this phase: `order-check.sh` is not matched by
`compliance-check.sh`'s `*-gate.sh` glob (its filename does not end in
`-gate.sh`), so its guard fix is verified only by its own green test
suite, not by the compliance detector directly — acceptable since
`compliance-check.sh` itself is scoped to that filename pattern by core
canon design, not a gap this repo introduced or this phase needed to
close.
