# Scout brief — issue-1

Mode: 3 parallel external-research angles in one batch (textbook methodology;
industry test-plan/report standards; SLO/proposal-norms), 1 stage, no
deepening round needed (judge point: results converged, no new build
decision would follow from another round). Internal 4th angle (this repo's
own issue-2/issue-5 proposal conventions) was covered by the survey step,
not re-swept here.

## Category must-bes (converged across all 3 angles)

- Name an explicit diagnostic methodology, not ad hoc guessing: USE method
  (Utilization/Saturation/Errors, resource-centric), RED method
  (Rate/Errors/Duration, request-centric), or the SRE book's Four Golden
  Signals (latency/traffic/errors/saturation) — these three are the same
  lineage and are the field's converged answer, cited independently by the
  textbook and standards angles.
- State goals as numeric SLOs/performance budgets *before* work starts
  (SRE book ch.4; RAIL model performance budgets) — a proposal without a
  numeric target is incomplete by this field's own definition of "goal."
- Workload characterization is mandatory before drawing conclusions
  (Gregg ch.2; ISTQB workload model: concurrency, transaction mix, ramp-up)
   — bottlenecks are workload-dependent, so "which workload" must be
  stated, not implied.
- Evidence must be quantitative and percentile-based (p50/p95/p99), not
  averages or narrative claims (SRE capacity chapter; Netflix eng blog;
  TPC Full Disclosure Report requirement for raw measured numbers).
- Pass/fail exit criteria tied to the stated SLO, and a report that
  compares actual-vs-criteria (ISTQB/ISO 29119-3; TPC FDR).
- Reproducibility: environment/config/tooling stated explicitly (TPC FDR
  audit requirement; ISTQB environment section).

## Performance axes the field competes on

1. Resource-centric vs. request-centric diagnosis (USE vs. RED) — most
   mature approaches use both, not one exclusively.
2. Proactive gating (performance budget as a hard CI/design gate) vs.
   reactive analysis (profile after the fact) — the strongest practices
   (RAIL, error budgets) push toward proactive numeric gates.
3. Rigor of reproducibility disclosure — TPC's audited FDR is the extreme
   high end; most teams don't need that, but the direction (state exact
   env/config/tooling) is the right pattern to borrow at a lighter weight.

## Adopt / skip

- Adopt: USE+RED (or Four Golden Signals as their SRE-flavored merge) as
  the named methodology for phase-2 measurement; numeric SLO/performance
  budget stated in the phase-1 proposal; workload characterization as a
  required proposal section; percentile-based evidence and exit criteria
  as required phase-2 report components; a premortem-style risk section
  (Klein; LCE canary practice) for phase-1, since this role hands off
  regressions to capacity-planning and a stated risk/rollback matters at
  handoff.
- Skip: TPC's full audited-disclosure apparatus (external auditor,
  priced-configuration disclosure) — disproportionate for a single-repo
  role; borrow only the underlying principle (state exact repro details),
  not the audit machinery. Also skip IEEE 829/ISO 29119's full generic
  test-doc template structure — this role already has a fixed
  role-handoff contract v3 shape (phase1 proposal / phase2 record) that
  the generic template does not need to duplicate.

## Segment fit

This role is a narrow, report-only rulebook role (`write_scope: []`,
directive.sh) inside a multi-role contract, not a standalone performance
team — so the adopted methodology must fit inside contract v3's existing
phase1-proposal / phase2-record shape rather than introduce a new
document type.

## Gap line

Current state (docs/issue-2 conversion + directive.sh) already has:
PRODUCES fields (`performance budget, profiling evidence, bottleneck
list`) that already anticipate a budget/goal, evidence, and bottleneck
list — i.e., the role's existing skeleton already gestures at "SLO +
evidence + bottleneck" but never names a methodology, never requires
workload characterization, never requires percentile-based evidence, and
has no gate enforcing any of it (record-fields-gate.sh only checks field
*presence*, not their contents). Missing vs. the field's must-bes: named
methodology, numeric SLO, workload characterization, percentile evidence,
exit criteria, reproducibility statement, risk/premortem section. This
proposal's job is to close exactly that gap, not to redesign the
role from scratch.

## Sources

- Brendan Gregg, *Systems Performance* (2nd ed., Pearson, 2020); brendangregg.com/usemethod.html
- Beyer/Jones/Petoff/Murphy (eds.), *Site Reliability Engineering* (O'Reilly, 2016); sre.google/sre-book (ch.4 SLOs, ch.6 Monitoring, capacity planning ch.21-22)
- Neil J. Gunther, *Guerrilla Capacity Planning* (Springer, 2007)
- Tom Wilkie, RED Method — weave.works/blog/the-red-method-key-metrics-for-microservices-architecture
- ISO/IEC 25010 (SQuaRE) performance efficiency characteristic
- ISTQB Certified Tester Performance Testing (CT-PT) syllabus
- ISO/IEC/IEEE 29119-3 (test documentation); IEEE 829 lineage
- TPC benchmark specs / Full Disclosure Report requirement — tpc.org
- web.dev RAIL model / performance budgets
- Gary Klein, premortem technique (HBR, 2007); Google Launch Coordination Engineering practice
