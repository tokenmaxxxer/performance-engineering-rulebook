# Record — issue-13: gate A+ remediation

loop_state: landed

## Why

Rationale: the 2026-08-01 code audit (issue-13 background) graded this
repo's three gates B, citing a fail-open kill switch, a substring-level
semantic check satisfiable by mere word mention (the bare `" use "` token,
and an SLO regex accepting `"p99 < acceptable levels"` with no numeric
threshold), and zero Edit/MultiEdit/kill-switch test coverage. Phase 1's
approved proposal set the fix; this phase-2 record states what was
actually built and verified.

## Upstream basis

Based on: `docs/issue-13/proposals/gate-a-plus-remediation.md` (this
repo's own phase-1 proposal, approved), which is itself grounded in
`docs/handbooks/gate-house-standard.md` and
`core/hooks/lib/gate-lib.sh`/`gate-lib.py` (`tokenmaxxxer-core`, issue
#72, the confirmed-landed prerequisite issue-13 named). Read from a local
`tokenmaxxxer-core` checkout at commit basis `main` as of 2026-08-01.

## Method

USE method used to judge this change: throughput/error-rate signal is the
test-suite pass rate across all three gates' `tests/run-gate-tests.sh`
(62/62 passing — 22 proposal-gate + 22 record-gate + 18 order-check), and
`core/hooks/tests/compliance-check.sh` (2/2 flagged files now clean: 0
findings on `proposal-gate.sh` and `record-gate.sh`).

## Repro info

Ran locally against a `tokenmaxxxer-core` checkout at
`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` (main), python3 (system
interpreter), bash. Reproduce:

```
export CLAUDE_PLUGIN_ROOT_CORE=/path/to/tokenmaxxxer-core/core
bash performance-engineering-proposal-gate/tests/run-gate-tests.sh
bash performance-engineering-record-gate/tests/run-gate-tests.sh
bash performance-engineering-order-check/tests/run-gate-tests.sh
bash "$CLAUDE_PLUGIN_ROOT_CORE/hooks/tests/compliance-check.sh" "$(pwd)"
```

## Workload Characterization

Workload-actual matches the phase-1 characterization exactly (§0 of
`docs/issue-13/proposals/gate-a-plus-remediation.md`): concurrency 1
(each `tests/run-gate-tests.sh` invocation runs one gate subprocess at a
time, synchronously), request mix covering all five tool kinds the
proposal named — `Write`, `Edit`, `MultiEdit`, and now `NotebookEdit`
(exercised indirectly via `gate_reconstruct_write`'s shared code path,
covered by core's own `run-gate-lib-tests.sh`, not duplicated here since
this repo's write surfaces are markdown documents, not notebooks) and
`Bash`-write-detection (new §1.2 case, exercised directly) — against both
gate-target document shapes (`docs/issue-<n>/proposals/*.md`,
`docs/issue-<n>/reports/performance-engineering.md`). No ramp-up
dimension, per §0's stated rationale (stateless per-invocation hooks).

## Percentile Evidence

Deterministic pass/fail counts, not a percentile distribution (this
change is enforcement infrastructure, not a measured runtime system —
methodology.md (b)4's percentile-evidence intent maps here to the full
enumerated test-count evidence below, the closest analog for a
correctness-gated change): proposal-gate 22/22, record-gate 22/22,
order-check 18/18, `compliance-check.sh` 2/2 clean.

## Bottleneck

No performance bottleneck in the runtime sense — this is a correctness
remediation. The nearest analog, the enforcement-coverage gap the audit
found, is closed: bottleneck = the 3 confirmed-defect classes (kill-switch
fail-open, `replace_all`-ignored/no-`NotebookEdit`/no-Bash-coverage,
substring-only semantic checks) named in
`docs/issue-13/reports/performance-engineering/survey.md`, evidence linked
below in "What was done."

## What was done

Summary of work done, four parts (issue-13's four numbered items):

1. **Gate-lib adoption by reference (item 1).** All three gates
   (`proposal-gate.sh`, `record-gate.sh`, `order-check.sh`) now source
   `core/hooks/lib/gate-lib.sh` (`gate_trap_fail_closed`,
   `gate_kill_switch_active`, `gate_deny`) and load `gate-lib.py` via
   `importlib` (`gate_parse_json_or_deny`, `gate_normalize_path`,
   `gate_reconstruct_write`), resolved via
   `${CLAUDE_PLUGIN_ROOT_CORE:-<repo-root>/../../core}` — the same
   convention `performance-engineering/hooks/directive.sh` already uses.
   Replaced: the hand-rolled `__fc()`/`trap __fc EXIT` pair,
   `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac` kill switches, the
   `resolve()`/`_under()` path-normalize idiom's Python-side counterpart
   (`gate_normalize_path`), and the `current.replace(o, n, 1)`
   first-occurrence-only reconstruction (`gate_reconstruct_write`, which
   also adds `NotebookEdit` cell-source reconstruction and honors each
   `MultiEdit` edit's own `replace_all` independently). `Bash`-tool write
   detection added to all three via a Python-side token scan
   (`re.findall(r'[A-Za-z0-9_./~$-]+', cmd)`) applied against each gate's
   own path pattern — an undeterminable Bash write to the gate's target
   fails closed (deny), the same posture an undeterminable Edit already
   took.
2. **Semantic-check upgrade: section/adjacency/structure (item 2).** New
   `performance-engineering-order-check/hooks/section_lib.py` (private,
   role-specific — not core canon) splits a document on its `##`/`###`
   ATX headings; `proposal-gate.sh`/`record-gate.sh`'s per-facet checks
   and `order-check.sh`'s ordering check now match against the section
   whose **heading** (not body prose) matches that facet's group in the
   extended `heading-vocabulary.md` (new groups: `slo`, `hypothesis`,
   `method`, `premortem`, `citation`, `repro`, `bottleneck`,
   `exit-criteria`, `handoff`, alongside the existing
   `workload`/`evidence`). Closes both issue-13-cited false-passes
   directly: the bare `" use "` substring check is replaced by
   same-section co-occurrence of a specific method phrase and a
   decide/judg phrase inside the Method section; the numeric-SLO regex
   unconditionally requires a digit+unit after the comparator
   (`[<>=]\s*\d+(\.\d+)?\s*(ms|s|%|/s|rps)`), so `"p99 < acceptable
   levels"` no longer matches, and the match must additionally fall
   inside the SLO-group section. `order-check.sh` compares section start
   offsets, not raw string position, so a stray word in the wrong
   section's own prose can no longer perturb the verdict.
3. **Mandatory test cases (item 3), full suite green.** All three
   `tests/run-gate-tests.sh` suites now include: `Edit` with
   `replace_all: true` against a multiply-occurring `old_string`;
   `MultiEdit` with mixed `replace_all` true/false edits; three
   malformed-JSON sub-cases (truncated, non-object, empty); kill-switch
   set to an unrecognized value (must stay active) plus at least two
   recognized on-spellings (must disable); absolute `file_path` and a
   `./`-prefixed relative path matching the same scope as the existing
   relative-path case; a `Bash`-tool write reaching the gate's target
   (must fail closed, not silently pass); plus role-specific
   section-scoped semantic cases per gate (bare-word decoy,
   numeric-less SLO, wrong-section figure for proposal-gate;
   wrong-section percentile figure for record-gate; workload-word-in-
   evidence-prose robustness and a real-heading `replace_all` case for
   order-check). Result: 62/62 passing across the three suites (see
   Percentile Evidence above); every pre-existing `allow`-expected
   fixture still passes, confirming the hypothesis below was not
   refuted.
4. **README realignment (item 4).** Root `README.md`'s `## Layout`
   previously listed four files that do not exist in this repo
   (`record-fields-gate.sh`, `trailer-gate.sh`, `handbook-trigger-gate.sh`,
   `agents/warrant-hunter.md`) and omitted every plugin directory that
   actually ships (`performance-engineering-checklist`,
   `performance-engineering-session-informer`,
   `performance-engineering-proposal-gate`,
   `performance-engineering-record-gate`,
   `performance-engineering-order-check`). Rewritten to list the real
   plugin set, each gate's kill-switch env var, and the `core` plugin
   dependency (`CLAUDE_PLUGIN_ROOT_CORE`). The three gate plugins' own
   `README.md` files updated to match (new tool coverage, gate-lib/
   section_lib sourcing, updated kill-switch wording, updated test
   descriptions) — no other README carried stale content.

## Exit Criteria Verdict

**Pass** against the phase-1 SLO (§0/§5 of
`docs/issue-13/proposals/gate-a-plus-remediation.md`'s falsifiable
hypothesis: adopting `gate-lib.sh`/`gate-lib.py` and section-scoped checks
removes the two issue-13-cited false-pass paths without introducing a new
false-deny on any existing passing fixture). Both conditions verified
directly: `bare-use-decoy-denies` and `slo-no-numeric-denies` now deny
(previously would have allowed); all pre-existing `allow`-expected
fixtures (`complete-compliant`, `foreign-path`, `graceful-exit`,
`proposal-in-order`, `record-in-order`, `workload-only-no-evidence`) still
allow. No deviation observed. `compliance-check.sh` clean on both files it
scans (`*-gate.sh` glob; `order-check.sh` is out of that glob's scope by
name but received the identical gate-lib/section-lib migration for
consistency — confirmed by its own green suite, not by
`compliance-check.sh` itself).

## Hand-off

No hand-off is needed. This is a self-contained enforcement-infrastructure
fix with no capacity or scaling dimension — `capacity-planning` has no
basis to act on here.

## Open findings

None open. `loop_state: landed` above — no next-steps or resolution path
required. One residual note for future reference, not a finding blocking
this record: `order-check.sh` is not matched by `compliance-check.sh`'s
`*-gate.sh` glob (its filename does not end in `-gate.sh`), so its
gate-lib migration is verified only by its own green test suite, not by
the compliance detector directly — acceptable since `compliance-check.sh`
itself is scoped to that filename pattern by core canon design, not a gap
this repo introduced.
