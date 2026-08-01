# issue-13 phase-1 survey: current-state audit

Scope: the three PreToolUse gates in this repo's plugin set —
`performance-engineering-proposal-gate/hooks/proposal-gate.sh`,
`performance-engineering-record-gate/hooks/record-gate.sh`,
`performance-engineering-order-check/hooks/order-check.sh` — plus their
`tests/run-gate-tests.sh` suites and the plugin READMEs, against issue-13's
audit findings (grade B).

## Scout skip record

Skip condition 2 applies: the spec leaves no design decision open. Issue-13
names the prerequisite explicitly — core issue #72 (gate-house standard) is
landed, and its migration checklist
(`docs/handbooks/gate-house-standard.md`, tokenmaxxxer-core) already
prescribes the exact adoption steps (run `compliance-check.sh`, migrate
each flagged gate to source `gate-lib.sh`/load `gate-lib.py`, re-run the
six-case `run-gate-lib-tests.sh` suite adapted locally, re-run
`compliance-check.sh` clean). There is no exemplar field to scout — the
canon reference *is* the target, self-copying it is explicitly forbidden
(`docs/handbooks/canon-scripts.md`, tokenmaxxxer-core), and the whole task
is conformance to a standard already fixed by another issue. No scout pass
run.

## Confirmed defects (read against tokenmaxxxer-core `main`)

All three gate scripts are structurally identical (same header comment
shape, same `_target`/`_plausible`/`_under`/`root=` resolution block, same
inline Python judge heredoc) — this is exactly the "same shapes, 2-3
different idioms" pattern `gate-house-standard.md` describes for the 43
downstream repos, confirming this repo needed its own migration.

1. **Kill switch, fail-open on unrecognized value.** All three gates:
   `proposal-gate.sh:20-23`, `record-gate.sh:21-24`, `order-check.sh:27-30`
   use `case "${X_OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac` — any
   value other than a recognized off-spelling, including a typo, disables
   the gate. This is exactly bug 1 in `gate-house-standard.md`'s "two bugs
   this issue fixed" section, present here as bug 0 (never fixed in this
   repo).
2. **`replace_all` ignored; MultiEdit under-covered.** All three gates'
   Python judge: `Edit` branch does `current.replace(o, n, 1)`
   unconditionally (proposal-gate.sh:130, record-gate.sh:131,
   order-check.sh:171); `MultiEdit` branch does the same per-edit
   (`text.replace(o, n, 1)`), never reading `edits[i].replace_all`. A
   `replace_all: true` Edit that turns a passing document into a failing
   one (or vice versa) is invisible to all three gates.
3. **No NotebookEdit reconstruction.** None of the three gates' `tool in
   (...)` allowlist includes `NotebookEdit`; a write via that tool passes
   through unexamined regardless of content.
4. **No Bash-tool write coverage.** None of the three gates inspect a
   `Bash` `tool_input.command` for a redirect/heredoc write to their
   target path; `gate_bash_write_targets` in `gate-lib.sh` exists
   precisely for this gap and none of the three call anything like it.
5. **Weak semantic checks — substring, not section/adjacency/structure.**
   - `proposal-gate.sh:170` — `method_named = has_any("use method", "
     use ", "use+red", "red method", ...)`. The bare `" use "` token is
     issue-13's cited defect: it is satisfied by any sentence containing
     the common English word "use" in a space-padded context (e.g. "we
     use consistent naming for X"), unrelated to the USE methodology.
   - `proposal-gate.sh:162` — the numeric-SLO regex
     `r'p\d{1,2}\s*[<>=]|(latency|throughput|error\s*rate)[^.\n]{0,40}[<>=]\s*\d'`
     requires a digit-bearing percentile/metric token followed by a
     comparator, but the first alternative (`p\d{1,2}\s*[<>=]`) does not
     require anything *after* the comparator — `"p99 < acceptable
     levels"` matches and passes despite citing no numeric threshold or
     unit. This is issue-13's cited "SLO 검사가 'p99 < acceptable
     levels' 통과" defect exactly.
   - `record-gate.sh`'s seven `(b)N` checks and `proposal-gate.sh`'s
     remaining five `(a)N` checks are all flat `has_any(...)` substring
     tests over the whole lowercased document with no positional,
     section-boundary, or co-occurrence-within-section requirement — a
     document can scatter the required tokens anywhere (e.g. bury
     "percentile evidence" in an unrelated aside) and still pass.
   - `order-check.sh` is comparatively closer to structural already (it
     matches whole canonical phrases loaded from
     `heading-vocabulary.md`, not single words) but still does a flat
     `str.find` over the entire document body, not a per-section index —
     a workload phrase appearing anywhere before an evidence phrase
     appearing anywhere passes, even if neither phrase sits in the
     document's actual "Workload" / "Evidence" heading section.
6. **Path resolution: functionally close to `gate_normalize_path` but not
   sourced from it.** All three gates' `resolve()` (Python) and
   `_under()` (bash, for the `CLAUDE_PROJECT_DIR` fast-path) hand-roll
   `posixpath.normpath` + `os.path.realpath` logic that is very close in
   shape to `gate_lib.gate_normalize_path`, but is a third independent
   reimplementation rather than a call to the canon function — exactly
   the "2-3 different idioms" duplication `gate-house-standard.md`
   documents.
7. **No kill-switch / Edit / MultiEdit / malformed-JSON / absolute-path
   test coverage.** `grep` over all three `tests/run-gate-tests.sh`
   confirms zero references to `MultiEdit`, `replace_all`, or any
   `*_OFF` kill-switch case in any of the three suites; all existing
   cases are `Write`-only missing-element deny/allow cases. This matches
   issue-13's "킬스위치/Edit 무테스트" finding precisely.
8. **README ghost-file risk.** Not yet diffed against the current
   `hooks/` tree in this pass (phase-1 scope is the design proposal, not
   the fix); flagged as phase-2 work item 4 per the issue.

## Compliance-check dry-run (informational only; not run for record —
core's own `compliance-check.sh` requires a local core plugin checkout
this repo does not carry)

Manually applying `compliance-check.sh`'s two grep rules to all three
gates by hand: both rules fire on all three files —
(a) each file's kill-switch `case` matches `\$\{[A-Z_]+_OFF:-` with no
`gate_kill_switch_active` call; (b) each file's `text.replace(o, n, 1)`
call matches the reconstruction-heuristic regex with no
`gate_reconstruct_write` call. All three gates would fail
`compliance-check.sh` today.
