---
status: proposed
files:
  - performance-engineering/hooks/directive.sh
  - performance-engineering-order-check/hooks/heading-vocabulary.md
  - performance-engineering-record-gate/hooks/record-gate.sh
  - performance-engineering-record-gate/README.md
  - performance-engineering-record-gate/tests/run-gate-tests.sh
  - performance-engineering-checklist/checklist.md
  - README.md
---

# Proposal: align rulebook with the realized performance-engineering spec (issue #19)

Subject: issue-19. Phase 1 (survey + proposal) — no execution in this PR;
phase 2 opens only after an approvers.md Approve per contract v3 s19. See
`docs/issue-19/reports/implementation/survey.md` for the current-state
survey this proposal is drafted from (includes the scout-directive
skip-condition statement).

## Request

Layer `roles/specs/performance-engineering.spec.json`'s (fetched from
`tokenmaxxxer/on-the-record`, marketplace #521-#525 program) required
deliverable fields (`sli`, `slo_target`, `error_budget_remaining`,
`verdict`) and `loop_state` vocabulary
(`landed`/`measuring`/`metric-unreachable`/`reviewing`/`slo-undeclared`)
onto this rulebook's docs and hooks — strengthening existing methodology
content, deleting nothing.

## Constraints

- Every spec required-field name must appear in `docs/` or `README.md`
  after phase 2 (acceptance check: `grep -ri <field> docs/ README.md`).
- The rulebook's `loop_state` vocabulary must match the spec's five-state
  set exactly — no stale or extra states.
- Where a spec field has no natural home, say so explicitly with
  reasoning (none found here — see Rationale).
- `error_budget_remaining`'s recomputation-only rule is explicitly
  `TBD (follow-up)` at the spec level (issue-521 out-of-scope note) — this
  proposal documents the rule as a required record element but does not
  build automated recomputation enforcement; that stays a named
  follow-up, not silently dropped.
- No existing methodology.md (a)/(b) facet is removed; the spec's fields
  layer on top of, not instead of, the existing percentile/exit-criteria
  norm.
- Any operational-surface file touched must ship alongside a
  `docs/handbooks/` update per contract v3 s21 — this proposal's write
  set touches none (no package manifest, Dockerfile, CI workflow, or
  migration), so no handbook file is added.

## Rationale

**Where `sli`/`slo_target`/`error_budget_remaining`/`verdict` land**: the
record-gate's existing (b)4/(b)6 elements (percentile evidence,
exit-criteria pass/fail) already carry the *evidence*, but under
free-text prose, not a named field the gate can grep. Two structural
options were weighed:

1. **Chosen — extend the existing Evidence and Exit-Criteria sections
   with four labeled sub-fields** (`sli:`, `slo_target:`,
   `error_budget_remaining:`, `verdict:`) checked by the record-gate,
   plus a new `heading-vocabulary.md` group for `sli`/`error-budget` so
   the section-scoping the other three gates already rely on keeps
   working. This reuses the section-scoped-check machinery every other
   facet in this rulebook already goes through, so the new fields get
   the same section-mismatch protection (the record-gate's existing
   pattern: a correctly-worded field in the wrong section still fails)
   without inventing a second checking mechanism.
2. **Rejected — a standalone frontmatter block only** (e.g.
   `sli:`/`verdict:` as YAML frontmatter keys, no section requirement,
   modeled on how the `implementation` role's `record-shape-gate.sh`
   checks `code_under_review:`/`loop_state:`). Rejected because
   frontmatter-only would bypass the section-scoping this rulebook's
   three existing gates are built around — a `verdict:` key in
   frontmatter says nothing about which section's claim it backs, so a
   pass/fail asserted in frontmatter could contradict the prose
   exit-criteria verdict with no gate catching the mismatch. `loop_state`
   itself (see below) is the one field this proposal DOES put in
   frontmatter, because it is a document-level state marker, not a
   claim tied to one section — that asymmetry is deliberate, not an
   inconsistency.

**Where `loop_state` lands**: as record frontmatter
(`loop_state: measuring|reviewing|landed|slo-undeclared|metric-unreachable`),
matching the shape the `implementation` role's `record-shape-gate.sh`
already establishes for `loop_state:` frontmatter elsewhere in this repo
family (per this session's own SessionStart directive text, which quotes
the contract's per-kind terminal-state table). Two options were weighed:

1. **Rejected — a `docs/specs/record-fields-terminal-states.json`
   override keyed `{"performance-engineering": ["landed"]}`**, modeled
   on core's `record-fields-gate.sh` override channel. Rejected after a
   warrant-hunt on this proposal (stance 3, `docs/reports/2026-08-09-hunt-spec-alignment.md`)
   found it structurally broken: that gate's override file is keyed by
   contract-§2 *kind* (`coding-record`, `qa-record`, ... — a closed,
   role-name-independent vocabulary with no `performance-engineering`
   entry and no `ROLE_TO_KIND["performance-engineering"]` mapping), and
   the gate validates every override entry's key against that closed set
   on *every* role's record/proposal write, denying loudly on an
   unrecognized key. Landing this file as specified would not just fail
   to override this role's terminal states — it would fail-closed-deny
   every other role's record and proposal writes across the repo family
   the moment the file lands, since the gate parses it unconditionally.
2. **Chosen — enforce the five-state closed set directly inside this
   role's own `performance-engineering-record-gate.sh`**, the same file
   already doing all of this role's other frontmatter-adjacent and
   section-scoped checks, rather than through core's shared override
   channel, which is scoped to contract-§2 kinds this role is not one
   of. The gate parses the frontmatter `loop_state:` value itself and
   denies unless it is exactly one of `landed`, `measuring`,
   `metric-unreachable`, `reviewing`, `slo-undeclared` — a closed check
   satisfying the "no stale or extra states" acceptance criterion without
   touching core's kind-keyed override mechanism at all.

**No field is homeless.** All four required fields and all five
loop_state values have a named landing spot above; the "empty state"
acceptance clause is therefore satisfied by having none to report,
stated explicitly rather than by omission.

## What will be done

1. `performance-engineering/hooks/directive.sh` — add the four required
   field names and the five-state `loop_state` vocabulary to the role
   directive text (under `PRODUCES`/a new `LOOP_STATE` line), so a
   session reading its own directive sees the spec vocabulary at
   SessionStart, matching how `implementation`'s directive already
   surfaces its own loop_state table.
2. `performance-engineering-order-check/hooks/heading-vocabulary.md` —
   add an `"sli"` group (phrases: `sli`, `service level indicator`) and
   an `"error-budget"` group (phrases: `error budget`,
   `error-budget-remaining`, `error_budget_remaining`), documented
   consistently with the file's existing group-comment convention
   (which gates read which groups).
3. `performance-engineering-record-gate/hooks/record-gate.sh` — extend
   the (b)4/(b)6 element checks: within the Evidence section, require an
   `sli:` line naming a concrete monitored metric (reference-resolution
   text: "must resolve to an actual monitored metric" per the spec,
   phrased as a checklist reminder in the deny message — this repo has
   no monitoring system to resolve against, so the check is textual
   presence + non-placeholder wording, not live metric resolution) and
   an `error_budget_remaining:` line inside a new Error-Budget section;
   within the Exit-Criteria section, require a `verdict:` line whose
   value is `within-budget` or `exhausted` (replacing/extending the
   existing bare pass/fail check — pass/fail is kept as the existing
   prose requirement, `verdict:` is the new spec-exact enum layered on
   top). Add a frontmatter `loop_state:` check validating one of the
   five spec states, fail-closed on anything else, mirroring the
   existing fail-closed conventions already in this file.
4. `performance-engineering-record-gate/README.md` — document the new
   elements and the frontmatter check in the "Behavior" section.
5. `performance-engineering-record-gate/tests/run-gate-tests.sh` — add
   fixture cases: missing `sli:`, missing `error_budget_remaining:`,
   invalid `verdict:` value, invalid `loop_state:` value, and a passing
   case carrying all five loop_state values across separate fixtures.
6. `performance-engineering-checklist/checklist.md` — mirror the new
   required elements under the phase-2 checklist section, same
   bullet-list style as the existing seven items.
7. `README.md` — update the "Layout" section describing
   `record-gate.sh`'s scope to mention the four new elements and the
   loop_state frontmatter check, and correct the stale role-card
   `write_scope: []` line to match the spec's declared
   `docs/issue-<n>/reports/performance-engineering.md`.

## Out of scope

- Building live `sli` reference-resolution against a real monitoring
  system (`on-the-record/hooks/role-spec-reference-guard.sh` is that
  repo's job, not this rulebook's) — this proposal only adds the textual
  presence/non-placeholder check described in step 3.
- Automated `error_budget_remaining` recomputation enforcement — the
  spec itself marks this `TBD (follow-up)`; this proposal documents the
  rule in prose (record-gate deny message + checklist) but builds no
  recomputation engine.
- Editing `docs/issue-1/proposals/methodology.md` — that is landed
  issue-1 output; this proposal changes gate/vocab/directive files
  instead, consistent with how the existing three gates already layer
  norms on top of methodology.md without rewriting it.
- Any change to `performance-engineering-proposal-gate` (phase-1 gate) —
  the spec's four fields and loop_state vocabulary are phase-2 record
  concepts per the spec's own `write_scope`; phase-1's existing six
  facets are untouched.
- `performance-engineering-order-check/hooks/order-check.sh` ordering
  rule changes — the new `sli`/`error-budget` groups are additive to
  heading-vocabulary.md; no new precedence rule is requested by the spec
  or the issue.
- `docs/specs/record-fields-terminal-states.json` / core's
  `record-fields-gate.sh` override channel — that channel is keyed by
  contract-§2 kind, a closed vocabulary `performance-engineering` is not
  a member of; using it was considered and rejected (see Rationale) after
  a warrant-hunt found it would fail-closed-deny every other role's
  writes repo-wide. This role's `loop_state` closed-set check is instead
  self-contained inside `performance-engineering-record-gate.sh`.

## How you'll know it worked

- `grep -ri "sli\|slo_target\|error_budget_remaining\|verdict" docs/ README.md`
  each returns at least one hit after phase 2.
- `grep -ri "loop_state" docs/ README.md` shows exactly the five spec
  states somewhere in the surfaced vocabulary, and no other state name.
- `CLAUDE_PLUGIN_ROOT_CORE=<core-checkout>/core bash performance-engineering-record-gate/tests/run-gate-tests.sh`
  passes, including the new fixture cases from step 5.
- Every other gate's existing test suite
  (`performance-engineering-proposal-gate/tests`,
  `performance-engineering-order-check/tests`) still passes unmodified,
  confirming no regression to the untouched phase-1 gate or ordering
  rule.
