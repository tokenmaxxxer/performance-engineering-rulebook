# performance-engineering authoring checklist

Reading aid, not an enforcement mechanism. The actual gates are
`performance-engineering-proposal-gate` (phase-1) and
`performance-engineering-record-gate` (phase-2) — this plugin never
blocks a write; it only restates their normative source
(`docs/issue-1/proposals/methodology.md`) as a literal checklist.

## Phase-1 authoring checklist (methodology.md (a))

- [ ] **SLO** — stated as a numeric threshold with unit and comparator
      (e.g. "p99 < 250ms", "error rate < 0.1%"), not a prose goal.
- [ ] **Hypothesis** — falsifiable, names a specific mechanism that could
      be wrong, grounded in existing telemetry — not a bare guess.
- [ ] **Method** — explicitly named (USE, RED, Four Golden Signals, or a
      stated combination), with one sentence tying the choice to this
      role's `YOU DECIDE` line.
- [ ] **Workload characterization** — concurrency level, request/
      transaction mix, and ramp-up profile for the load condition under
      test — not "under load" alone.
- [ ] **Premortem** — blast-radius limit, killswitch mechanism, and
      rollback procedure, written as if the regression has already
      happened.

## Phase-2 authoring checklist (methodology.md (b))

- [ ] **Methodology-cite** — which of USE/RED/Golden-Signals was actually
      applied, with the per-signal measured values.
- [ ] **Repro info** — hardware/config/tool-version detail sufficient for
      another session to reproduce the measurement.
- [ ] **Workload-actual** — the actually-exercised workload and its
      match/mismatch against the phase-1 workload characterization.
- [ ] **Percentile evidence** — p50/p95/p99 (or equivalent); averages
      alone do not satisfy this item.
- [ ] **Bottleneck-evidence linkage** — every bottleneck named points at
      the specific percentile/measurement data supporting it.
- [ ] **Exit-criteria verdict** — explicit pass/fail against the phase-1
      numeric SLO, with the observed deviation stated.
- [ ] **Hand-off rationale** — if capacity is the gating factor, state the
      hand-off basis to capacity-planning; if not, state that no hand-off
      is needed and why.
