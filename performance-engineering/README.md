# performance-engineering

Role identity + SessionStart orientation only, per the issue-10 plugin-set
restructure. `YOU DECIDE`, `USE_WHEN`, `WRITE_SCOPE`, and hand-off target
live here; per-facet phase-1/phase-2 enforcement text does not — it lives
in the sibling plugins below, each owning exactly one methodology piece:

- `performance-engineering-proposal-gate` — phase-1 proposal-norm gate
- `performance-engineering-record-gate` — phase-2 record-norm gate
- `performance-engineering-order-check` — intra-document section-order
  check shared by both phases
- `performance-engineering-checklist` — human-facing authoring checklist
  (reference only, never gates)
- `performance-engineering-session-informer` — non-blocking SessionStart
  awareness (issue/branch/PR/approval state)

No single plugin constitutes phase-1 or phase-2 on its own; see
`docs/issue-10/proposals/methodology-enforcement.md` § Composition for
which plugins combine to make each phase valid.

## Kill switch

`export PERFORMANCE_ENGINEERING_CYCLE_OFF=1` — disables this plugin's
SessionStart directive only. Each sibling plugin carries its own
independent kill switch (see each plugin's own README).
