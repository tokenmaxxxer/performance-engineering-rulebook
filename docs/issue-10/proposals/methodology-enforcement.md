# Proposal: melt the adopted performance-engineering methodology into enforcement machinery

Subject: issue-10, phase 1 (design proposal only — **no execution in this
PR**: no changes to `performance-engineering/hooks/*`, `.claude-plugin/*`,
or any hook/gate/directive.sh code). Phase 2 opens only after an
`approvers.md` Approve, or a single-account `APPROVE
issue-10/performance-engineering` issue comment, per contract v3 s19.

Evidence base: `docs/issue-10/reports/performance-engineering/current-state-survey.md`
(gaps a–e) and `docs/issue-10/reports/performance-engineering/scout-brief.md`
(adopt/skip decisions from the two named exemplars). Normative source:
`docs/issue-1/proposals/methodology.md` ((a) 6 proposal sections, (b) 7
record elements, (c) reasoning).

This proposal addresses the issue's four numbered requirements in order.

## (1) Directive depth

Per-facet, actionable breakdown — not a paraphrase of directive.sh's
existing one-line PRODUCES summary.

**Phase 1 (proposal-write time)**:
- **SLO** must be numeric (a latency/throughput/error-rate figure with a
  unit and a comparison operator, e.g. "p99 < 250ms", "error rate <
  0.1%"). A goal stated only in prose ("faster", "more scalable") does
  not satisfy this facet.
- **Hypothesis** must be falsifiable (name a specific mechanism that could
  be wrong, e.g. "connection pool saturates at X rps") and must reference
  existing telemetry it is grounded in, not a bare guess.
- **Method** must be named explicitly as USE, RED, Four Golden Signals, or
  a stated combination, with one sentence tying the choice to this role's
  `YOU DECIDE` line ("does load/latency satisfy the target") — i.e. why
  this method answers that judgment for this specific change.
- **Workload characterization** must state concurrency level, request/
  transaction mix, and ramp-up profile for the load condition the
  hypothesis will be tested under — not "under load" alone.
- **Premortem** must state blast-radius limit, a killswitch mechanism, and
  a rollback procedure, written as if the regression has already happened
  — required because this role's `WRITE_SCOPE: []` means it cannot itself
  patch code if phase 2 finds a regression; the hand-off path must exist
  before execution starts.
- **Evidence-citation format**: every external claim (a standard, a prior
  benchmark, an industry figure) must carry a source; anything without
  one must be explicitly labeled an assumption or removed.

**Phase 2 (record-write time)**:
- **Methodology-cite**: name which of USE/RED/Golden-Signals was actually
  applied, with the per-signal measured values (not just the name).
- **Repro info**: hardware/config/tool-version detail sufficient for
  another session to reproduce the measurement.
- **Workload-actual**: state the actually-exercised workload and its
  match/mismatch against the phase-1 workload characterization.
- **Percentile evidence**: p50/p95/p99 (or equivalent), not averages —
  averages alone do not satisfy this facet, matching the numeric SLO
  facet's own units.
- **Bottleneck-evidence linkage**: every bottleneck named in the list must
  point at the specific percentile/measurement data that supports it —
  a bottleneck asserted with no linked evidence does not satisfy this
  facet.
- **Exit-criteria verdict**: an explicit pass/fail against the phase-1
  numeric SLO, with the observed deviation stated.
- **Hand-off rationale**: if capacity is the gating factor, state the
  hand-off basis to capacity-planning explicitly; if not, state that no
  hand-off is needed and why.

**Where this lives**: recommend a new `docs/handbooks/
performance-engineering-methodology.md` handbook doc carrying the full
per-facet text above, with directive.sh's existing `PRODUCES` string kept
as a short pointer to it (e.g. append "— see
docs/handbooks/performance-engineering-methodology.md for per-facet
criteria"). Rationale: `core_role_directive`'s 4-arg shape is meant to
stay terse (issue-2 precedent establishes this constraint and forbids
inventing a 5th arg); a facet-by-facet breakdown at the length above does
not fit a directive string meant to print once at SessionStart.
**Open question for the approver**: this repo currently has no
`docs/handbooks/` directory at all, so creating one is itself a layout
decision — flagged in Risks below rather than decided unilaterally here.

## (2) Methodology gate

Extend the existing `methodology-gate.sh` (same file — not a new one; it
is already this role's local, non-canon content-gate per methodology.md
(d)-2's decision to keep such checks local rather than in core canon).

**(a) Dual-surface firing.** Add a second path regex,
`docs/issue-[0-9]+/proposals/.*\.md$`, alongside the existing
`docs/issue-[0-9]+/reports/performance-engineering\.md$`, mirroring
pricing-rulebook's dual-surface pattern (its gate fires on both
`proposals/*pricing*.md` and `reports/pricing.md`). On the proposal
surface, check the six (a)-facets from methodology.md granularly; on the
record surface, check the seven (b)-facets granularly.

**(b) Granular per-element checks, replacing the loose blob.** Instead of
the current two flat `grep -qiE` calls, model pricing's style: one
`missing = []` list, one check per element, each appending a named
message on failure (e.g. `missing.append("numeric SLO (a numeric
threshold with unit and comparator, not prose goal)")`), and a single
combined deny message at the end listing every missing element by name
and citing the methodology.md subsection it traces to — so a denial is
immediately actionable rather than a bare "blocked" line.

**(c) Graceful-exit allowance.** Where methodology.md's own reasoning
implies a step can be legitimately skipped (e.g. a proposal's hypothesis
is disproven before reaching percentile evidence, and the record instead
documents an early hand-off to capacity-planning with the reason stated),
recognize a small set of graceful-exit phrases (e.g. "disproven at
hypothesis stage", "routed to capacity-planning before /reaching
percentile evidence", "no regression found — exit before instrumentation")
as satisfying the otherwise-required elements downstream of the exit
point, per the pattern scouted from pricing-rulebook.

**(d) Content derivation.** Replace the current flat single-line grep
extraction (which does not handle MultiEdit at all, and mishandles
multi-line content) with content derived per-tool-type: Write's `content`
verbatim; Edit's `old_string`→`new_string` applied against the current
file content (read from disk, since Edit's payload is a diff, not the
full text); MultiEdit's edit list applied in sequence. This follows the
core canon idiom (python3 heredoc JSON parsing) and pricing's own
derivation pattern, not the current raw-grep-on-payload approach.

**(e) Order constraint — intra-document, not cross-record.** This role's
methodology has an implicit order (SLO/hypothesis stated before method
choice; workload characterization before evidence; evidence before
exit-criteria verdict), but it is **intra-document order within one
proposal or one record**, not cross-record/cross-commit sequencing like
coding-progress-gate.sh's finding-resolution state machine. Propose
enforcing it via **section-order regex within the single document text**:
does the "Workload characterization" heading's match position precede the
"Percentile evidence" (or equivalent) heading's match position in the
same content string. Full state-tracking (a running state file,
persistent across sessions, as in `state.sh`) is **not warranted** here:
this role is report-only (`write_scope: []`), produces exactly one
phase-1 proposal and one phase-2 record per issue, with no intermediate
commits to sequence across — unlike coding's many-commit lifecycle that
coding-progress-gate.sh's cross-record state machine exists to police.
Position-in-text is a sufficient proxy for "was this actually done in the
right order" at this role's single-document granularity.

**SessionStart companion (new, non-blocking)**: recommend adding a
lightweight `state.sh`-style informer, registered on `SessionStart`
alongside `directive.sh`, that checks current branch name for an issue
number, runs `gh pr view` to report existing PR/approval state for that
issue+role, and reports whether this role's own proposal/record file
already exists for this issue — informing only, never blocking, matching
implementation-rulebook's non-blocking `state.sh` companion pattern.
directive.sh today prints only static text with no session-resume
awareness at all; this closes that gap without adding blocking behavior.

## (3) Gate tests

Propose creating `tests/` at the **repo root** (not under
`performance-engineering/`), mirroring implementation-rulebook's
`tests/run-gate-tests.sh` + `tests/parse-check.sh` structure: one test
script (`tests/run-gate-tests.sh`) that pipes a set of synthetic
PreToolUse JSON payloads into `methodology-gate.sh` and asserts the exit
code:

- missing-SLO phase-1 proposal payload → expect exit 2
- missing-percentile phase-2 record payload → expect exit 2
- complete-compliant phase-1 proposal payload (all 6 elements present) →
  expect exit 0
- complete-compliant phase-2 record payload (all 7 elements present) →
  expect exit 0
- graceful-exit record payload (early hand-off phrase present, later
  elements absent) → expect exit 0
- unrelated file write payload (e.g. `README.md`) → expect exit 0 (scope
  check — the gate must not fire outside its two path patterns)

This is phase-2 execution work; no test files are written in this PR.

## (4) Agents/checklist

Propose `docs/handbooks/performance-engineering-checklist.md` (or folded
into the handbook from item (1) if that placement is approved),
enumerating:

- **Phase-1 checklist**: SLO → hypothesis → method choice → workload
  characterization → premortem.
- **Phase-2 checklist**: methodology-cite → repro → workload-actual →
  percentile-evidence → bottleneck-link → exit-criteria-verdict →
  hand-off.

...as a literal checklist a future session reads before writing its
proposal/record, not a new `agents/` subagent definition. **Why an
agents/ file was considered and rejected**: this role has no repeating
multi-step procedure that is *delegated* to a sub-persona (unlike, e.g.,
warrant-hunter's proportional-hunt-cadence use case, where a recurring
search procedure is handed off to an agent). This role's phase-1/phase-2
procedure is authored directly by the role session itself, once per
issue — a checklist the session reads is the right level of artifact; an
agent persona would add indirection with no delegation to justify it.

## Risks

- **Handbook-vs-directive-line placement** (item 1): whether the per-facet
  breakdown belongs in a new `docs/handbooks/` doc (recommended) or should
  instead be inlined further into directive.sh's PRODUCES string is an
  open question for the approver — this repo has no `docs/handbooks/`
  file yet, so creating the directory is itself a layout decision.
- **Intra-document order-regex brittleness**: section-header-name
  variance (a future proposal spelling "Workload Characterization" vs
  "Workload profile" vs a differently-cased heading) could cause the
  order check to false-negative or false-positive; the regex will need a
  documented canonical heading vocabulary, which is not yet specified.
- **Graceful-exit phrase list**: pricing-rulebook's graceful-exit phrases
  are pricing-specific; whether this role needs its own curated phrase
  list (vs. reusing pricing's wording) is open — a too-narrow list under-
  recognizes legitimate early exits, a too-broad list under-enforces.

## Out of scope

- No hooks, gates, or `directive.sh` changes execute in this PR — this is
  a design proposal only.
- Core canon (`record-fields-gate.sh`, `board-gate.sh`, and other core
  scripts referenced above) are untouched and referenced by path/behavior
  only, never copied, per `core canon-scripts.md`.
- The cross-role finding-resolution state machine pattern
  (coding-progress-gate.sh's verify.md linkage) is explicitly not adopted
  for this role — see scout-brief's skip rationale.
