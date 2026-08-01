# issue-13 phase-1 proposal: gate A+ remediation design

Status: phase-1 proposal only. No code changes in this PR. Phase 2 (the
actual fix) opens only after an approvers.md Approve per contract v3 s19.

Survey backing this proposal:
[`docs/issue-13/reports/performance-engineering/survey.md`](../reports/performance-engineering/survey.md).

## 0. Workload characterization for this gate change

Stated up front because it governs how phase 2's mandatory test cases
(§3) are sized: the workload characterization for this change is the
gate-invocation workload itself, not an application workload. Concurrency
level is fixed at 1 (PreToolUse hooks run synchronously, one per tool
call, never concurrently within a session). Request/transaction mix is
the five tool kinds this proposal's test matrix must cover —
`Write`/`Edit`/`MultiEdit` (already exercised today) plus `NotebookEdit`
and `Bash`-write-detection (newly added by §1.2) — against the two
gate-target document shapes (`docs/issue-<n>/proposals/*.md`,
`docs/issue-<n>/reports/performance-engineering.md`). Ramp-up profile:
not applicable — each hook invocation is a fresh, stateless process, so
there is no warm/cold or ramp dimension to characterize. Full detail,
plus the hypothesis and premortem facets, is in §5; this section exists
only to establish workload framing before the evidence-shaped discussion
in §2-3 below, per this repo's own order-check.sh convention (workload
characterization before percentile/profiling evidence within the same
document).

## 1. Adopt core's gate-house standard by reference, not reimplementation

Prerequisite confirmed landed: `tokenmaxxxer-core` `main` carries
`core/hooks/lib/gate-lib.sh` + `gate-lib.py` and
`docs/handbooks/gate-house-standard.md` (issue #72). Per
`canon-scripts.md`'s reference-not-copy rule, this repo's three gates will
**source/import, never vendor**, that library.

### 1.1 Runtime wiring

Each of the three gate scripts (`proposal-gate.sh`, `record-gate.sh`,
`order-check.sh`) gains, near the top, before any kill-switch check:

```bash
CORE_HOOKS="${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks"
. "$CORE_HOOKS/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
```

replacing the current hand-rolled `__fc()`/`trap __fc EXIT` pair (identical
in all three files today) with the one canonical fail-closed trap.

The Python judge heredoc in each gate loads `gate-lib.py` the documented
way:

```python
import importlib.util, os
_spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)
```

`GATE_LIB_PY` is exported by `gate-lib.sh` itself (already resolves to its
sibling `gate-lib.py`), so no extra env plumbing is needed beyond sourcing
`gate-lib.sh` in the bash wrapper before invoking `python3`.

### 1.2 Per-defect mapping (survey → adopted function)

| Survey defect | Fix | Adopted call |
|---|---|---|
| 1. Kill-switch fail-open on unrecognized value (all 3 gates) | Replace hand-rolled `case` with `gate_kill_switch_active` | `gate_kill_switch_active "${PERFORMANCE_ENGINEERING_<X>_GATE_OFF:-}" \|\| { trap - EXIT; exit 0; }` |
| 2. `replace_all` ignored on Edit/MultiEdit (all 3 gates) | Replace `current.replace(o, n, 1)` / per-edit loop with `gate_reconstruct_write` | `gate_lib.gate_reconstruct_write(tool, ti, current)` |
| 3. NotebookEdit unreconstructed (all 3 gates) | Add `"NotebookEdit"` to the `tool in (...)` allowlist; `gate_reconstruct_write` already returns the edited cell's `new_source` for `insert`/`replace` edit_mode | same call as above, extended tool set |
| 4. No Bash-tool write coverage (all 3 gates) | Add a `tool == "Bash"` branch: scan `ti.get("command", "")` with `gate_bash_write_targets`, apply each gate's own path-pattern regex to every candidate token, and treat a match as reaching this gate's target path — but with content undeterminable (see 2.1) | `gate_bash_write_targets "$command"` (bash) or an equivalent one-line reimplementation in the Python judge (regex is trivial enough to inline in Python without a second cross-language call — see 2.1) |
| 6. Hand-rolled path resolve, third idiom | Replace `resolve()` (Python) with `gate_lib.gate_normalize_path(root, path)` | `gate_lib.gate_normalize_path(root, path)` — note: contract is pure string algebra, no symlink resolution; each gate's bash-side `root` must still be realpath'd before passing in (§1.3) |
| Malformed JSON / empty / non-object payload (already handled ad hoc, correctly, in all 3 — kept, but re-routed through the canon check for one code path) | Replace the inline `json.loads`/`isinstance(ev, dict)` pair with `gate_parse_json_or_deny` | `gate_lib.gate_parse_json_or_deny(raw, deny)` |
| stderr-only deny / exit 2 (already correct in all 3 per issue-13's own item 1 — kept as-is, optionally routed through `gate_deny`/`gate_allow` for consistency) | No behavior change; cosmetic unification only, not required for A+ | `gate_lib.gate_deny` (bash side already has its own `deny()`; no change forced) |

### 1.3 `gate_normalize_path` boundary — root still needs a realpath

`gate_normalize_path`'s docstring is explicit: it does **not** touch the
filesystem or resolve symlinks; callers needing symlink-safe resolution
must realpath their own `root` first. Each gate's bash preamble already
computes `root="$(cd "$CLAUDE_PROJECT_DIR" ... && pwd -P)"` or
`git rev-parse --show-toplevel`, both of which are already
symlink-resolved absolute paths — so passing that `root` straight into
`gate_lib.gate_normalize_path(root, path)` in the Python judge preserves
today's symlink-safety with no extra step. The target file's own
existence check (`os.path.isfile(r)`) stays a separate, later step exactly
as today — `gate_normalize_path` only computes the root-relative tail, it
does not stat anything.

### 1.4 Compliance-check as the phase-2 acceptance gate

Phase 2 closes only when `core/hooks/tests/compliance-check.sh` run
against this repo's `hooks/` trees reports clean on all three gates. This
proposal does not run it now (referenced only; see survey §"Compliance-check
dry-run") because phase 1 makes no code change, but phase 2's PR
description must cite the clean output as evidence, per
`gate-house-standard.md`'s migration checklist step 4-5.

## 2. Semantic-check upgrade: substring → section/adjacency/structure

Issue-13 item 2 requires the semantic judge to stop being satisfiable by
"word mention" alone. Design, without reimplementing gate-lib (this is
role-specific judgment logic, not house infrastructure — gate-lib does not
attempt document-semantics checks):

### 2.1 Section extraction as a shared internal helper

Add one small helper, private to this repo (not core canon — it is
specific to this role's document shape), defined once and imported by
all three gates' Python judges — e.g.
`performance-engineering-order-check/hooks/section_lib.py` (co-located
with `order-check.sh`, which already owns the only cross-document
structural concept in this plugin set, `heading-vocabulary.md`) so
`proposal-gate.sh` and `record-gate.sh` load it the same
`importlib.spec_from_file_location` way they load `gate-lib.py`:

```python
def split_sections(text):
    """Split a markdown document on ATX headings (## or ###) into an
    ordered list of (heading_text, heading_lower, start_offset, body)
    tuples. Body runs from the end of the heading line to the next
    heading of the same or shallower level, or end of document."""
```

This is a ~20-line regex-and-scan function (heading regex
`r'^(#{2,3})\s+(.+)$'` over `text.splitlines(keepends=True)`, tracking
running offsets) — no external dependency, testable in isolation the same
way `gate_normalize_path` is testable with no filesystem fixture.

### 2.2 Per-facet check upgrade (proposal-gate.sh, record-gate.sh)

Each `(a)N` / `(b)N` facet check moves from "is this phrase anywhere in
the lowercased whole document" to "is this phrase (or a stronger,
co-occurrence-gated pattern) present **within the section whose heading
matches this facet's expected heading-vocabulary group**, using
`heading-vocabulary.md`'s existing group mechanism extended with the
groups proposal-gate/record-gate need beyond `workload`/`evidence`
(`method`, `slo`, `hypothesis`, `premortem`, `citation` for phase-1;
`repro`, `bottleneck`, `exit-criteria`, `handoff` for phase-2 — additive
to the file order-check.sh already loads, so all three gates share one
vocabulary file and one loader instead of three divergent phrase lists).

Two concrete upgrades directly answering issue-13's cited defects:

- **`" use "` bare-word bug (proposal-gate.sh:170).** Drop the bare
  `" use "` token entirely. `method_named` becomes: a heading matching the
  `method` group exists, AND within that section's body, `has_any("use
  method", "use+red", "red method", "golden signal", "four golden
  signals")` (the specific-enough multi-word phrases only — never a bare
  common word), AND that same section also satisfies `has_any("decide",
  "judg")`. Requiring same-section co-occurrence, not whole-document
  `has_any`, is what "adjacency/structure" upgrade buys here: a method
  name mentioned in an unrelated section no longer counts.
- **SLO regex accepting no numeric threshold
  (proposal-gate.sh:162).** Replace the two-alternative regex with one
  that requires a comparator **followed by** a number-and-unit, not just
  preceded by a percentile/metric token:
  `r'(p\d{1,2}|latency|throughput|error\s*rate)[^.\n]{0,40}[<>=]\s*\d+(\.\d+)?\s*(ms|s|%|/s|rps)'`
  — `"p99 < acceptable levels"` no longer matches (no digit+unit after the
  comparator); `"p99 < 250ms"` and `"error rate < 0.1%"` still do. This
  check additionally moves inside the section matching the `slo` heading
  group, same as above.
- **Downstream evidence-linkage checks (record-gate.sh (b)4-7).** Same
  section-scoping treatment: each `has_any(...)` pair is evaluated only
  within the body of the section whose heading matches that facet's
  vocabulary group, not the whole document. `graceful_exit` detection
  (record-gate.sh:161-167) stays whole-document — it is a document-level
  early-exit signal, not a per-facet claim, so section-scoping it would
  be a regression, not an upgrade.

### 2.3 order-check.sh: section-local adjacency, not whole-document `str.find`

`order-check.sh`'s current `first_index()` (line 197-203) does a flat
`str.find` per phrase over the whole lowercased document. Upgrade: use
`split_sections()` to require the workload phrase's match live inside a
section whose heading matches the `workload` group and the downstream
evidence phrase's match live inside a section whose heading matches the
`evidence` group — comparing each phrase's *section start offset* (not
raw `str.find` position) rather than comparing raw string positions.
This closes the case the survey flags: a stray workload word inside the
downstream-evidence section's prose (or vice versa) no longer perturbs
the ordering verdict, because only in-section-header-scoped matches
count.

### 2.4 What does NOT change

`heading-vocabulary.md`'s existing single-sourced-phrase-list design
(loaded at runtime, never duplicated in the gate scripts) is correct and
stays; this proposal only adds the section-splitting and section-scoping
layer on top of it, and additive vocabulary groups needed for the new
per-facet section scoping in §2.2.

## 3. Mandatory test cases (phase 2 must ship all of these, full suite
green)

Per issue-13 item 3 and the gate-house standard's own six-case floor
(`run-gate-lib-tests.sh`), adapted to this repo's three gates. Each row
below is a case group; phase 2 adds one or more concrete cases per group
to each of the three `tests/run-gate-tests.sh` suites (not a shared file —
each gate's existing suite already fixtures that gate's own document
shape, so the new cases extend those, following the local convention, not
a new copy of core's suite).

1. **Edit with `replace_all: true` against a multiply-occurring
   `old_string`.** Construct a starting document where the target phrase
   occurs twice; an Edit with `replace_all: true` replacing it with
   deny-triggering text at both occurrences must deny; the previous
   first-occurrence-only bug would have missed the second occurrence and
   allowed.
2. **MultiEdit with a mix of `replace_all: true`/`false` edits in one
   call.** At least one case per gate exercising two edits in one
   `MultiEdit`, one `replace_all: true` and one `false`, asserting the
   reconstructed content matches what `gate_reconstruct_write` would
   produce (deny/allow determined by that reconstruction, not a stub).
3. **Malformed JSON: truncated, non-object, empty payload.** Three
   sub-cases per gate (truncated JSON string, a JSON array/string at top
   level instead of an object, and an empty stdin payload) — all three
   must deny via `gate_parse_json_or_deny`'s messages, not the generic
   internal-error fail-closed catch-all.
4. **Kill-switch set to an unrecognized value.** Set each gate's own
   `*_OFF` env var to a garbage value (e.g. `banana`) and assert the gate
   stays **active** (still evaluates and can still deny) — the exact
   regression this proposal fixes (defect 1). A second case sets it to a
   recognized on-spelling (`1`/`true`/`yes`/`on`, at least two of the
   four) and asserts the gate exits 0 without evaluating.
5. **Absolute `file_path` matching the same scope a relative-path fixture
   already matches, plus a `./`-prefixed variant.** For each gate, one
   case reruns an existing relative-path deny fixture with an absolute
   path (`$CLAUDE_PROJECT_DIR` + the relative path) and one with a
   `./`-prefixed relative path, asserting identical verdicts to the
   existing relative-path case.
6. **A Bash-tool file write reaching the same target a Write-tool call
   would hit.** One case per gate: a `Bash` tool call whose `command`
   contains a redirect (`> docs/issue-N/proposals/x.md` or a heredoc) to
   the gate's target path, content omitted (undeterminable via a shell
   command) — asserting the gate treats an undeterminable Bash write to
   its target the same fail-closed way it already treats an
   undeterminable Edit (deny, per current `new_text is None` handling),
   not a silent pass.
7. **Section-scoped semantic checks (this repo's own addition, beyond the
   six house cases — required because §2 is role-specific logic
   gate-lib does not cover).** For `proposal-gate.sh`: one case with the
   `" use "`-style bare-word decoy present outside the `method` section
   and the real method phrase absent — must still deny (closes the exact
   issue-13-cited false-pass). One case with `"p99 < acceptable levels"`
   (comparator, no numeric threshold) — must still deny. One case with a
   correctly-scoped, correctly-worded facet inside the wrong section
   (e.g. the SLO figure placed inside the Premortem section) — must
   deny, proving section-scoping is enforced, not just phrase presence.
   For `order-check.sh`: one case with a workload word appearing inside
   the downstream-evidence section's own prose before the real Workload
   section — must still pass (order between sections is what's judged,
   not raw string position).

Acceptance for phase 2: `tests/run-gate-tests.sh` green in all three gate
directories, plus a local adaptation of `run-gate-lib-tests.sh`'s six
cases per `gate-house-standard.md`'s migration checklist step 3, plus
`compliance-check.sh` clean per step 4.

## 4. README realignment (issue-13 item 4)

Deferred to phase 2 (a documentation-sync task against the *result* of
§1-3, not a design decision — nothing to propose here beyond the
commitment): phase 2 diffs `README.md`'s `## Layout` list against the
actual `hooks/` trees across all plugin directories, removes any path
that does not exist, and adds the kill-switch env vars
(`PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF`,
`PERFORMANCE_ENGINEERING_RECORD_GATE_OFF`,
`PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF`) and the `gate-lib.sh` sourcing
dependency (`CORE_PLUGIN_ROOT`) that phase 2 introduces.

## 5. Hypothesis, workload characterization, and premortem for this gate change

This proposal changes enforcement infrastructure, not a measured system,
but methodology.md (a)'s facets still apply to the change itself (full
workload characterization detail already stated in §0; repeated in
context here alongside the other two facets per methodology.md's
grouping):

**Falsifiable hypothesis, grounded in existing telemetry/observed
behavior.** Hypothesis: adopting `gate-lib.sh`/`gate-lib.py` by reference
and adding section-scoped semantic checks removes the specific false-pass
paths the issue-13 audit observed (`" use "` bare-word match,
`"p99 < acceptable levels"` numeric-less SLO match) without introducing a
new false-deny rate on the existing passing fixtures in each gate's
`tests/run-gate-tests.sh`. This is falsifiable directly: phase 2's full
test suite run is the telemetry — every existing `allow`-expected fixture
must still exit 0 after the migration, and the two exact issue-13-cited
strings must newly deny where they previously passed exit 0 unblocked. If
phase 2 breaks any existing `allow` fixture, the hypothesis is refuted and
the section-scoping design in §2 needs revision before merge.

**Workload characterization.** See §0 for the full statement (concurrency
fixed at 1, five-tool-kind mix, no ramp-up dimension) — restated here only
to satisfy this section's own facet grouping, not as new content.

**Premortem.** Blast-radius: limited to this repo's three plugin
directories (`performance-engineering-proposal-gate`,
`performance-engineering-record-gate`, `performance-engineering-order-check`)
— no other role's rulebook repo is touched, and within this repo the
change touches only `hooks/*.sh` and `tests/run-gate-tests.sh` in those
three directories plus `README.md`; no change to `directive.sh`, the
session-informer, or the record/proposal write-surface regexes
themselves. Killswitch: each gate keeps its own existing
`PERFORMANCE_ENGINEERING_<X>_GATE_OFF` env var — after migration, the
*fixed* `gate_kill_switch_active` semantics apply (only a recognized
on-spelling disables), so `export PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=1`
(etc., per gate) remains the operator escape hatch (kill switch) if phase 2
introduces an unforeseen false-deny in production use. Rollback: phase 2
lands as a single PR on `issue-13/performance-engineering`; reverting that
merge commit (rollback) on `main` fully restores the current (audited,
grade-B) gate behavior with no data migration or state to unwind, since
gates are stateless PreToolUse hooks with no persisted artifacts of their
own.

## 6. Explicitly out of scope for this proposal

- No APPROVE, no phase-2 code. This PR stops at proposal + survey.
- No change to `heading-vocabulary.md`'s existing phrase-list-in-a-file
  mechanism — only additive groups per §2.2/§2.4.
- No reimplementation of any `gate_*` function under this repo's own
  `hooks/` — every core-covered defect class in §1 is a reference/import,
  never a local copy, so `stub-check.sh`'s canon-manifest check keeps
  passing.

## Assumption labels

- Assumption: `CORE_PLUGIN_ROOT` (or the `$CLAUDE_PLUGIN_ROOT/../core`
  fallback) resolves to a checkout of `tokenmaxxxer-core` at runtime in
  this repo's own plugin-install layout; not verified in this phase-1
  pass since no code executes yet. Phase 2 must verify this path
  resolves before relying on it in the runtime wiring of §1.1.
- Source: `docs/handbooks/gate-house-standard.md` and
  `core/hooks/lib/gate-lib.sh` / `gate-lib.py`, read from
  `tokenmaxxxer-core` `main` at the time of this proposal
  (2026-08-01), via `gh repo clone tokenmaxxxer/tokenmaxxxer-core`.
