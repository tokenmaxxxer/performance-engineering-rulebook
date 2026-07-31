# Proposal: melt the adopted performance-engineering methodology into a plugin set

Subject: issue-10, phase 1 (design proposal only — **no execution in this
PR**: no changes to `performance-engineering/hooks/*`, `.claude-plugin/*`,
or any hook/gate/directive.sh code, and no edits to
`.claude-plugin/marketplace.json`). Phase 2 opens only after an
`approvers.md` Approve, or a single-account `APPROVE
issue-10/performance-engineering` issue comment, per contract v3 s19.

Evidence base: `docs/issue-10/reports/performance-engineering/current-state-survey.md`
(gaps a–e) and `docs/issue-10/reports/performance-engineering/scout-brief.md`
(adopt/skip decisions from the two named exemplars). Normative source:
`docs/issue-1/proposals/methodology.md` ((a) 6 proposal sections, (b) 7
record elements, (c) reasoning).

## Revision note

The prior version of this proposal (superseded) designed a single enlarged
`methodology-gate.sh` living inside the one existing `performance-engineering`
plugin, with directive-text deepening folded into the same plugin. The
approver rejected that shape in the issue's "요구 정정" comment: enforcement
must be systematized as a **plugin set** — each adopted methodology piece as
its own independent, self-contained, marketplace-registered plugin (the
`freelunch`/`scout`-in-core pattern: several plugins per rulebook, each at
freelunch-level completeness), with the phase-1 proposal-norm and phase-2
record-norm each resolved as a **composition of plugins**, not as sections
inside one shared file. This revision restructures the design accordingly.
All content below is re-homed from the superseded version; no facet, gate
test case, risk, or scope boundary is dropped — only the packaging changes.

## Current repo state (verified, not fabricated)

- `.claude-plugin/marketplace.json` (repo root) registers exactly one
  plugin today: `performance-engineering`, source `./performance-engineering`.
- `performance-engineering/.claude-plugin/plugin.json` exists (name,
  description, author — Jung Jiwon & Lee Jongkwan).
- `performance-engineering/hooks/` holds `directive.sh`, `methodology-gate.sh`,
  `hooks.json` — currently all folded into the single plugin.
- There is no `core/` directory and no other rulebook (pricing-rulebook,
  implementation-rulebook) present in **this** repo. Those are read-only
  prior-art exemplars living in sibling checkouts
  (`/home/jwjung/.tokenmaxxxer/work/pricing-rulebook-issue-1-pricing/`,
  `/home/jwjung/.tokenmaxxxer/work/implementation-rulebook-issue-61-implementation/`)
  and in core canon
  (`/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/`), per the
  scout-brief — referenced by path/behavior only, never copied.

## Design principle: plugin = one methodology piece, self-contained

Each proposed plugin below is a candidate independent entry under this
repo's root (sibling to today's `performance-engineering/` directory),
each with its own `.claude-plugin/plugin.json`, its own
`hooks/` (directive text and/or gate script it owns), its own `agents/` or
checklist file if it needs one, and its own `tests/` for its own gate. Each
would get one new entry in `.claude-plugin/marketplace.json` (proposed
entries only — the actual file is not touched by this PR). No plugin
duplicates another's responsibility; composition across plugins, not size
of any one plugin, is what makes phase-1 and phase-2 whole.

## Plugin list

| # | Plugin name (proposed dir) | Methodology piece it owns | Components it would bundle | Phase it gates |
|---|---|---|---|---|
| 1 | `performance-engineering` (existing, narrowed) | Role identity + session-start orientation only: WRITE_SCOPE, hand-off target, pointer to the other plugins below | `hooks/directive.sh` (trimmed to identity/hand-off, no longer the place per-facet text lives), `hooks/hooks.json` (`SessionStart` registration for directive.sh and the new informer in #6) | orientation for both phases |
| 2 | `performance-engineering-proposal-gate` | Phase-1 proposal-norm: the 6 methodology.md (a) facets (numeric SLO, falsifiable hypothesis, named method+reason, workload characterization, premortem, evidence-citation format) | `hooks/proposal-gate.sh` (granular per-element `missing.append(...)` checks, fires on `docs/issue-[0-9]+/proposals/.*\.md$`), `hooks/hooks.json` (`PreToolUse` for `Write\|Edit\|MultiEdit`), `tests/run-gate-tests.sh` with the 6 missing-element + 1 complete-compliant + 1 scope-check cases for this surface | phase 1 |
| 3 | `performance-engineering-record-gate` | Phase-2 record-norm: the 7 methodology.md (b) elements (methodology-cite, repro info, workload-actual, percentile evidence, bottleneck-evidence linkage, exit-criteria verdict, hand-off rationale) | `hooks/record-gate.sh` (granular per-element checks + graceful-exit phrase recognition, fires on `docs/issue-[0-9]+/reports/performance-engineering\.md$`), `hooks/hooks.json`, `tests/run-gate-tests.sh` with the 7 missing-element + 1 complete-compliant + 1 graceful-exit + 1 scope-check cases | phase 2 |
| 4 | `performance-engineering-order-check` | Intra-document section-order constraint (Workload-characterization-before-percentile-evidence class of checks, both within a proposal and within a record) | `hooks/order-check.sh` (position-in-text regex check, invoked by, or chained after, the gate in #2/#3 depending on which document it is checking — exact wiring is a phase-2 execution decision, not fixed here), documented canonical-heading vocabulary file | both, as a shared cross-cutting check |
| 5 | `performance-engineering-checklist` | The two repeating human-facing procedures (phase-1 authoring checklist, phase-2 authoring checklist) as literal reference material, not a gate | `docs/performance-engineering-checklist.md` bundled inside the plugin (phase-1: SLO → hypothesis → method choice → workload characterization → premortem; phase-2: methodology-cite → repro → workload-actual → percentile-evidence → bottleneck-link → exit-criteria-verdict → hand-off) — no `agents/` subagent, see rationale below | both, as authored reference |
| 6 | `performance-engineering-session-informer` | Non-blocking SessionStart awareness: which issue/branch this session is on, existing PR/approval state, whether this role's proposal/record file already exists | `hooks/state.sh` (state.sh-style informer, `SessionStart`, never blocking), `hooks/hooks.json` | both, informational only |

Each plugin's `plugin.json` would state its single responsibility in its
`description` field, mirroring how the existing
`performance-engineering/.claude-plugin/plugin.json` states this role's
decision (부하/지연 목표를 만족하는가) — e.g. plugin #2's description would
read something like "Gates phase-1 performance-engineering proposals on the
6 methodology.md (a) facets; does not touch phase-2 records."

## Composition: what makes phase-1 valid, what makes phase-2 valid

This composition is the design's core content, per the approver's note.

**Phase-1 proposal-norm = plugins #1 + #2 + #4 + #5 + #6, composed as:**
- #1 tells the session at SessionStart which role it is and what it must
  not touch (WRITE_SCOPE: []).
- #5 gives the session the phase-1 checklist to author against.
- #2 is the enforcement backstop: it denies a proposal write/edit that is
  missing any of the 6 (a) facets, independent of whether the session
  consulted #5.
- #4 additionally enforces that, within the one proposal document, facets
  appear in the methodology-implied order (e.g. workload characterization
  stated before the evidence-citation section, not after).
- #6 is advisory only — it does not gate; it just orients the session to
  existing PR/issue state before it starts writing.
- Record-gate (#3) plays no role in phase-1 — its path regex never
  matches a `proposals/` file, by design (dual-surface separation, not one
  gate guessing which surface it's on).

**Phase-2 record-norm = plugins #1 + #3 + #4 + #5 + #6, composed as:**
- #1 and #6 play the same orienting role as in phase-1.
- #5's phase-2 checklist half is the authoring reference.
- #3 is the enforcement backstop for the 7 (b) elements, including
  graceful-exit phrase recognition so a legitimately early hand-off (e.g.
  disproven at hypothesis stage) is not penalized for missing downstream
  elements.
- #4 enforces the same class of intra-document order constraint, applied
  to the record's own section order (e.g. workload-actual before
  percentile evidence).
- Proposal-gate (#2) plays no role in phase-2, symmetric to the above.

No single plugin, on its own, constitutes either norm — each norm is the
sum of the row above, which is the concrete answer to "which plugins
combine to make phase-1 valid" / "which plugins combine to make phase-2
valid."

## Per-plugin facet detail (content re-homed from the superseded single-gate design)

### Plugin #2 — `performance-engineering-proposal-gate`: the 6 phase-1 facets

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

### Plugin #3 — `performance-engineering-record-gate`: the 7 phase-2 facets

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

### Plugins #2/#3 gate mechanics (shared design, one instance per plugin)

**Granular per-element checks, replacing the loose blob.** Instead of the
current two flat `grep -qiE` calls in the single `methodology-gate.sh`,
model pricing's style within each plugin's own gate script: one
`missing = []` list, one check per element, each appending a named
message on failure (e.g. `missing.append("numeric SLO (a numeric
threshold with unit and comparator, not prose goal)")`), and a single
combined deny message at the end listing every missing element by name
and citing the methodology.md subsection it traces to — so a denial is
immediately actionable rather than a bare "blocked" line.

**Graceful-exit allowance** (plugin #3 primarily, since early exits are a
phase-2 concept). Where methodology.md's own reasoning implies a step can
be legitimately skipped (e.g. a proposal's hypothesis is disproven before
reaching percentile evidence, and the record instead documents an early
hand-off to capacity-planning with the reason stated), recognize a small
set of graceful-exit phrases (e.g. "disproven at hypothesis stage",
"routed to capacity-planning before reaching percentile evidence", "no
regression found — exit before instrumentation") as satisfying the
otherwise-required elements downstream of the exit point, per the pattern
scouted from pricing-rulebook.

**Content derivation.** Each gate script replaces the current flat
single-line grep extraction (which does not handle MultiEdit at all, and
mishandles multi-line content) with content derived per-tool-type:
Write's `content` verbatim; Edit's `old_string`→`new_string` applied
against the current file content (read from disk, since Edit's payload is
a diff, not the full text); MultiEdit's edit list applied in sequence.
This follows the core canon idiom (python3 heredoc JSON parsing) and
pricing's own derivation pattern, not the current raw-grep-on-payload
approach.

### Plugin #4 — `performance-engineering-order-check`: intra-document order

This role's methodology has an implicit order (SLO/hypothesis stated
before method choice; workload characterization before evidence; evidence
before exit-criteria verdict), but it is **intra-document order within
one proposal or one record**, not cross-record/cross-commit sequencing
like coding-progress-gate.sh's finding-resolution state machine. Propose
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
right order" at this role's single-document granularity. This plugin is
packaged separately from #2/#3 (rather than folded into each) because the
order-regex logic and its canonical-heading vocabulary are shared machinery
applied to two different documents, not a facet-presence check itself —
factoring it out avoids duplicating that machinery across #2 and #3.

### Plugin #6 — `performance-engineering-session-informer`: SessionStart companion

A lightweight `state.sh`-style informer, registered on `SessionStart`,
that checks current branch name for an issue number, runs `gh pr view` to
report existing PR/approval state for that issue+role, and reports
whether this role's own proposal/record file already exists for this
issue — informing only, never blocking, matching implementation-rulebook's
non-blocking `state.sh` companion pattern. `directive.sh` today prints
only static text with no session-resume awareness at all; this closes
that gap without adding blocking behavior, and without merging that
concern into plugin #1's identity-only directive.

### Plugin #5 — `performance-engineering-checklist`: why a checklist file, not an `agents/` persona

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

## Gate tests (per gate-owning plugin, at that plugin's own `tests/`)

Each of plugins #2, #3, and #4 owns its own `tests/run-gate-tests.sh`
(mirroring implementation-rulebook's `tests/run-gate-tests.sh` +
`tests/parse-check.sh` structure), living inside the plugin directory
itself (e.g. `performance-engineering-proposal-gate/tests/`), not shared
at the repo root — each plugin is self-contained per the approver's
requirement. Case list (unchanged from the superseded design, now split
by which plugin's gate they exercise):

**Plugin #2 (`performance-engineering-proposal-gate`) tests:**
- missing-SLO phase-1 proposal payload → expect exit 2
- (one missing-element case per remaining 5 facets) → expect exit 2 each
- complete-compliant phase-1 proposal payload (all 6 elements present) →
  expect exit 0
- unrelated file write payload (e.g. `README.md`) → expect exit 0 (scope
  check — the gate must not fire outside its `proposals/` path pattern)

**Plugin #3 (`performance-engineering-record-gate`) tests:**
- missing-percentile phase-2 record payload → expect exit 2
- (one missing-element case per remaining 6 facets) → expect exit 2 each
- complete-compliant phase-2 record payload (all 7 elements present) →
  expect exit 0
- graceful-exit record payload (early hand-off phrase present, later
  elements absent) → expect exit 0
- unrelated file write payload → expect exit 0 (scope check)

**Plugin #4 (`performance-engineering-order-check`) tests:**
- out-of-order proposal (percentile-equivalent section before workload
  characterization) → expect exit 2
- in-order proposal/record → expect exit 0

This is phase-2 execution work; no test files are written in this PR.

## Where this lives — handbook question, resolved

The superseded design proposed one shared `docs/handbooks/
performance-engineering-methodology.md` file to hold all per-facet text,
with `directive.sh`'s `PRODUCES` string kept as a pointer to it. Under the
plugin-set framing, that shared-handbook question is replaced: the
per-facet text now lives **inside each owning plugin** (the 6 phase-1
facets inside plugin #2, the 7 phase-2 facets inside plugin #3), since
each plugin must be self-contained rather than depending on a shared
external doc for its own gate's authoritative text. A shared handbook
would only still be useful as a **cross-plugin index** — a single page
listing all six plugins, one line each, linking to the owning plugin's
own content, analogous to how `marketplace.json` itself indexes plugins
but does not hold their content. Recommendation: skip a separate
`docs/handbooks/` doc for now; plugin #5's checklist file already serves
as the human-facing cross-phase reference, and each plugin's own
`plugin.json` description plus its gate script's per-element messages
serve as the machine-facing reference. This repo still has no
`docs/handbooks/` directory; not creating one avoids introducing a new
top-level layout convention this issue does not need to decide.
**Open question for the approver**: if a shared index page across all six
plugins is wanted anyway (e.g. for discoverability), it should be a thin
`docs/` page, not a duplicate content store — flagged in Risks below.

## Risks

- **Plugin-count overhead**: six plugins for one role's methodology is a
  larger number of `marketplace.json` entries and `plugin.json` files than
  the prior one-plugin design. This is the approver's explicit ask (a
  plugin set, not a single deepened gate), but it does raise the
  bookkeeping cost of adding a seventh methodology's plugin set later —
  flagged, not treated as a reason to shrink the count below what §
  "Composition" requires.
- **Plugin #4's shared machinery vs. per-plugin self-containment
  tension**: packaging the order-check as its own plugin (rather than
  duplicating the order-regex inside both #2 and #3) trades some
  self-containment for avoiding duplicated logic. If the approver's
  self-containment requirement is meant strictly (each plugin fully
  standalone, no cross-plugin invocation), #4's logic may instead need to
  be duplicated into #2 and #3 directly — flagged as an open question
  rather than decided unilaterally here.
- **Intra-document order-regex brittleness**: section-header-name
  variance (a future proposal spelling "Workload Characterization" vs
  "Workload profile" vs a differently-cased heading) could cause the
  order check to false-negative or false-positive; the regex will need a
  documented canonical heading vocabulary, which is not yet specified.
- **Graceful-exit phrase list**: pricing-rulebook's graceful-exit phrases
  are pricing-specific; whether this role needs its own curated phrase
  list (vs. reusing pricing's wording) is open — a too-narrow list under-
  recognizes legitimate early exits, a too-broad list under-enforces.
- **Shared-index-vs-no-handbook**: whether a thin cross-plugin index page
  is wanted is an open question for the approver (see "Where this lives"
  above).

## Out of scope

- No hooks, gates, `directive.sh` changes, new plugin directories, or
  `.claude-plugin/*` / `marketplace.json` edits execute in this PR — this
  is a design proposal only.
- Core canon (`record-fields-gate.sh`, `board-gate.sh`, and other core
  scripts referenced above) are untouched and referenced by path/behavior
  only, never copied, per `core canon-scripts.md`.
- The cross-role finding-resolution state machine pattern
  (coding-progress-gate.sh's verify.md linkage) is explicitly not adopted
  for this role — see scout-brief's skip rationale.
