# Current-state survey — issue-19

Subject: issue-19. Phase 1 (survey + proposal), no execution in this PR.

## Spec fetched

`roles/specs/performance-engineering.spec.json` does not exist in this
repo — it lives in `tokenmaxxxer/on-the-record`. Fetched via
`gh api repos/tokenmaxxxer/on-the-record/contents/roles/specs/performance-engineering.spec.json`.
Content:

- `required_fields`: `sli` (ref), `slo_target` (string),
  `error_budget_remaining` (string), `verdict` (enum:
  `within-budget`|`exhausted`)
- `reference_resolution`: sli must resolve to an actual monitored metric,
  no orphan refs (checked by on-the-record's own
  `role-spec-reference-guard.sh`, outside this repo)
- `recomputation`: `error_budget_remaining` must be recomputed from the
  current `sli` measurement against `slo_target`, never a standalone
  asserted field — enforcement is explicitly `TBD (follow-up)`, not this
  issue's job
- `write_scope`: `docs/issue-<n>/reports/performance-engineering.md`
  (matches this rulebook's existing phase-2 record path exactly)
- `loop_state`: progress = `measuring`, `reviewing`; terminal = `landed`;
  refusal = `slo-undeclared`; error = `metric-unreachable`
- `use_when`: latency/throughput-sensitive change on branch AND no
  performance-engineering record yet for that commit sha

## Rulebook current state (write surfaces + owners)

- `performance-engineering/hooks/directive.sh` — role directive text:
  `YOU DECIDE`, `PRODUCES` (`performance budget, profiling evidence,
  bottleneck list`), `WRITE_SCOPE: []`, hand-off to capacity-planning.
  No `loop_state` vocabulary anywhere in it today.
- `docs/issue-1/proposals/methodology.md` — normative source for both
  gates below (landed issue-1, `status` not re-checked here — out of
  this issue's write set). Section (a): phase-1 required sections (SLO,
  hypothesis, method, workload characterization, premortem, evidence
  citation). Section (b): phase-2 required elements (methodology-cite,
  repro info, workload-actual, percentile evidence, bottleneck-evidence
  linkage, **exit-criteria verdict** (pass/fail against phase-1 numeric
  SLO), hand-off rationale).
- `performance-engineering-checklist/checklist.md` — plain-text mirror
  of methodology.md (a)/(b), reading aid only, not a gate.
- `performance-engineering-proposal-gate/hooks/proposal-gate.sh` — gates
  phase-1 `docs/issue-<n>/proposals/*.md` on methodology.md (a)'s 6
  facets, section-scoped via `heading-vocabulary.md`.
- `performance-engineering-record-gate/hooks/record-gate.sh` — gates
  phase-2 `docs/issue-<n>/reports/performance-engineering.md` on
  methodology.md (b)'s 7 elements, same section-scoping. No frontmatter
  check (`code_under_review:`/`loop_state:`) exists in this gate today —
  unlike the `implementation` role's `record-shape-gate.sh` (see this
  session's own SessionStart directive), this role has no record-shape
  gate at all.
- `performance-engineering-order-check/hooks/heading-vocabulary.md` —
  single-sourced heading-phrase groups read by all three gates:
  `workload`, `evidence`, `slo`, `hypothesis`, `method`, `premortem`,
  `citation`, `repro`, `bottleneck`, `exit-criteria`, `handoff`. No
  `sli`, `error-budget`, or `verdict` group exists.
- `docs/specs/` in this repo holds only `approvers.md`. No
  `record-fields-terminal-states.json` exists — the contract's default
  per-kind terminal-state table therefore governs unless this repo adds
  an override.
- README.md's `write_scope: []` line (repo-level role card) is stale
  against the actual gated write surface
  (`docs/issue-<n>/reports/performance-engineering.md`) and against the
  spec's `write_scope`, which names that same path — an existing
  mismatch, not one this issue introduces, but directly relevant to
  field placement below.

## Cross-repo precedent check

Searched sibling org repos (`tokenmaxxxer/tokenmaxxxer-core`,
`tokenmaxxxer/implementation-rulebook`) for an existing `loop_state`
vocabulary or `record-fields-terminal-states.json` pattern to reuse.
None found in `tokenmaxxxer-core/docs/specs/` (only `approvers.md`
exists there) and no `loop_state` hits via `gh search code` scoped to
`tokenmaxxxer-core`. This session's own SessionStart directive already
quotes the contract's per-kind terminal-state table verbatim
(measuring/reviewing → progress, landed → terminal, slo-undeclared →
refusal, metric-unreachable → error is exactly the shape the *spec*
also states) — that directive text is treated as the authoritative
source for how `loop_state` composes with the role-handoff contract in
this repo family; no further external sweep is needed to ground the
design decision below.

## Skip-condition statement (scout-directive)

Scouting's external-sweep stage is skipped for this issue. Reasoning:
this is not product-shaped work with a category of best-in-class
exemplars to benchmark against — it is a vocabulary-alignment task
against one authoritative internal spec (`performance-engineering.spec.json`)
whose own `source_standard` field already cites the reference standard
(Google SRE SLO/error-budget workbook) this rulebook's existing
methodology.md already draws its percentile/exit-criteria language from.
The one external precedent worth checking — how a sibling rulebook in
this same org already wires `loop_state` — was checked directly above
(cross-repo precedent check) rather than run as a 4-angle parallel web
sweep, because the answer space is one specific artifact shape (a JSON
vocabulary list + a markdown section), not a competitive landscape.

## Write set this proposal will name (preview, frozen in the proposal itself)

- `performance-engineering/hooks/directive.sh` (loop_state + required
  fields into role directive)
- `docs/issue-1/proposals/methodology.md` amendment is NOT in scope —
  landed issue-1 output; instead a new methodology addendum or direct
  gate/vocab change is needed. Confirmed: gate logic changes belong in
  the gate's own hooks + heading-vocabulary.md, not by editing another
  issue's landed proposal.
- `performance-engineering-order-check/hooks/heading-vocabulary.md` (new
  `sli`, `error-budget`, `verdict` groups)
- `performance-engineering-record-gate/hooks/record-gate.sh` (new
  element checks + frontmatter `loop_state` check)
- `performance-engineering-record-gate/tests/run-gate-tests.sh` (new
  cases)
- `performance-engineering-checklist/checklist.md` (mirror the new
  elements)
- `docs/specs/record-fields-terminal-states.json` (new file: declare
  performance-engineering's kind → terminal-state override matching the
  spec's `terminal: [landed]` exactly, since progress/refusal/error
  states also differ from contract defaults)
- `README.md` (layout section + role-card `write_scope`/`produces`
  update)
