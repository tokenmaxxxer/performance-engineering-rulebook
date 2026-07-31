# Scout brief: enforcement-machinery exemplars for performance-engineering

Subject: issue-10, phase 1.

**Scouted**: 2 exemplars, named by the issue itself as the comparison
class — pricing-rulebook's `methodology-gate.sh`, and
implementation-rulebook's `coding-progress-gate.sh` + `state.sh`.

**Mode**: batched-sequential fallback, not concurrent subagent fan-out.
Both exemplars and two core canon files were read sequentially in one
research session as local-disk file reads of known sibling checkouts
(`/home/jwjung/.tokenmaxxxer/work/pricing-rulebook-issue-1-pricing/...`,
`/home/jwjung/.tokenmaxxxer/work/implementation-rulebook-issue-61-implementation/...`,
core at `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/...`) — this is
not a web/multi-source sweep, so no concurrent-agent fan-out was
warranted; a single sequential pass sufficed and is reported as such.

**Category must-bes extracted**:
- Granular per-element content checks (each required element gets its own
  `missing.append(...)` and its own explanation), not one keyword blob.
- Graceful-exit allowances — phrases like "exited too early" / "routed to
  X" satisfy a requirement instead of forcing inapplicable content.
- State-tracking across records/commits, used where the methodology has a
  genuine cross-artifact ORDER constraint (coding-progress-gate.sh reading
  another role's record + git log to gate a commit).
- A SessionStart informer companion (state.sh-style): non-blocking, tells
  the role what issue/branch/PR state it's resuming.
- Fail-closed `trap __fc EXIT` idiom, shared across all core canon gates
  and both exemplars.
- A `tests/` directory with explicit pass/deny synthetic-payload cases.

**Adopt for this role**:
- Granular per-element check on BOTH surfaces — phase-1 proposal writes
  and the phase-2 record — mirroring pricing's dual-surface pattern
  (pricing checks `docs/issue-<n>/proposals/*pricing*.md` and
  `docs/issue-<n>/reports/pricing.md` with the same six-granular-element
  style).
- Graceful-exit phrases, adapted to this role's hand-off vocabulary (e.g.
  "disproven at hypothesis stage" / "routed to capacity-planning").
- A gate `tests/` directory with pass/deny cases, at repo root.
- The fail-closed trap idiom and content-derivation-from-payload pattern
  (Write content / Edit old_string→new_string / MultiEdit edit list),
  replacing the current flat-grep extraction.
- A SessionStart informer companion in the state.sh style (non-blocking).

**Skip for this role**:
- coding-progress-gate.sh's cross-role finding-resolution state machine
  (reading another role's record for `severity: blocking` findings and
  gating `git commit` on their resolution). This role is report-only
  (`write_scope: []`), produces one proposal + one record per issue with
  no intermediate commits to sequence, and no other role's blocking
  findings gate this role's commits — there is nothing analogous to
  verify.md's finder/coder relationship in this role's lifecycle. The
  ORDER constraint this role actually has is intra-document (section A
  before section B within one proposal or record), not cross-record
  cross-commit — so a persistent running-state file is unwarranted here.

**Gap line**: this scouting directly answers survey gaps (a) 2-of-7
keyword-only coverage → granular per-element checks; (b) no phase-1 gate
→ dual-surface pattern; (c) no order enforcement → intra-document
section-order check (not full state-tracking, per the skip above); (d) no
tests dir → adopt tests/ structure; (e) no checklist artifact → see
proposal item (4), a handbook checklist rather than an agents/ persona.

**Sources** (local-repo file paths, not URLs — no web fetch was performed
because the comparison class named by the issue itself, sibling rulebook
repos already checked out on this disk, was locally available and
authoritative for this role's own plugin ecosystem):
- `/home/jwjung/.tokenmaxxxer/work/pricing-rulebook-issue-1-pricing/pricing/hooks/methodology-gate.sh`
- `/home/jwjung/.tokenmaxxxer/work/implementation-rulebook-issue-61-implementation/coding/hooks/coding-progress-gate.sh`
- `/home/jwjung/.tokenmaxxxer/work/implementation-rulebook-issue-61-implementation/coding/hooks/state.sh`
- `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/record-fields-gate.sh` and
  `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/board-gate.sh` (core canon,
  reference-only — cited for the §20 field-presence + state-tracking
  pattern, never copied, per `core canon-scripts.md`).
