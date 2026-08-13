---
subject: issue-1174
layer_program: docs/issue-1174/proposals/operational-playbook-program.md
---

# Performance-engineering operational playbook

Numbered condition → choice → source rules, three research layers:
(A) practitioner decision rules, (B) named methodologies verified at
source, (C) academic/theoretical grounding. REMOVAL-category rules are
marked `[REMOVAL]`.

## Layer A — practitioner decision rules

1. **Condition:** a service is "slow" with no prior hypothesis.
   **Choice:** check Utilization, Saturation, Errors for every candidate
   resource (CPU, memory, disk I/O, network) before touching code —
   never jump straight to the first metric that looks abnormal.
   **Source:** Brendan Gregg, "USE Method: Linux Performance Checklist,"
   https://www.brendangregg.com/USEmethod/use-linux.html

2. **Condition:** reporting or alerting on request latency.
   **Choice:** report p50/p95/p99 (or p99.9 for latency-sensitive paths
   like checkout/auth), never the mean — mean latency hides the tail
   that users and SLOs actually experience.
   **Source:** Google SRE Book, "Service Level Objectives,"
   https://sre.google/sre-book/service-level-objectives/

3. **Condition:** deciding how strict an SLO/error budget should be.
   **Choice:** set the target below 100% deliberately and track burn
   rate against a budget (1 − SLO), not against zero-tolerance — a
   100%-target SLO measurably suppresses release velocity for no
   reliability gain once the budget is otherwise unspent.
   **Source:** Google SRE Workbook, "Error Budget Policy,"
   https://sre.google/workbook/error-budget-policy/

4. **Condition:** a queue/pool/worker pool is running "hot" (util near
   100%) but not yet erroring.
   **Choice:** treat it as an imminent wait-time cliff and act before
   errors appear — under Little's Law (L = λW), wait time W grows
   supralinearly, not linearly, as utilization approaches 1.0.
   **Source:** "What is Little's Law? The Core Formula of Queueing
   Theory," https://sixsigmadsi.com/glossary/littles-law/

5. **[REMOVAL] Condition:** an ORM-driven code path issues one query per
   loop iteration (N+1 pattern) discovered during USE/latency triage.
   **Choice:** remove the per-iteration query (batch/eager-load it) in
   preference to scaling the database tier to absorb it — the query
   count is the defect, not the hardware.
   **Source:** ClearPeaks, "Database Connection Pooling: A Guide to
   Tuning & Performance Optimisation,"
   https://www.clearpeaks.com/database-connection-pooling-a-guide-to-tuning-performance-optimisation/
   (connection-exhaustion and per-request-query patterns as the root
   driver of pool pressure, not pool size).

6. **[REMOVAL] Condition:** a connection pool is periodically exhausted
   or timing out under normal (non-spike) load.
   **Choice:** first remove connection leaks (unreleased connections on
   error paths) and stale/dead connections from the pool; only increase
   pool size after leaks are confirmed absent — an oversized pool masks
   a leak instead of fixing it and shifts the failure to the database's
   own connection ceiling.
   **Source:** ClearPeaks, ibid.

7. **Condition:** choosing a fix among several that close the same
   latency/capacity gap.
   **Choice:** prefer the removal-shaped fix (delete redundant work: a
   query, a cache layer, an unbounded retry) over the addition-shaped
   fix (add a cache, add a replica, add a bigger instance) when both
   close the gap — addition adds a permanent operational surface
   (invalidation, replication lag, cost) that removal does not.
   **Source:** derived from Gregg's methodology corpus emphasizing
   root-cause elimination over symptom compensation,
   https://www.brendangregg.com/methodology.html

## Layer B — named methodologies verified at source

8. **Condition:** starting any performance investigation with no
   existing dashboard coverage.
   **Choice:** apply the USE Method systematically (per-resource
   utilization/saturation/errors table) before applying any
   application-level profiling method.
   **Source:** Brendan Gregg, "Performance Analysis Methodology,"
   https://www.brendangregg.com/methodology.html

9. **Condition:** defining what "reliable enough" means for a service
   before setting alerts.
   **Choice:** define SLI → SLO → error budget in that order (measure
   first, target second, budget derived), per the SRE canon — never
   set an alert threshold before an SLO exists to justify it.
   **Source:** Google SRE Book ch.4, "Service Level Objectives,"
   https://sre.google/sre-book/service-level-objectives/

## Layer C — academic/theoretical grounding

10. **Condition:** justifying why a wait-time or capacity claim is valid
    across arrival-rate variation, not just at the measured sample.
    **Choice:** ground the claim in Little's Law (L = λW, a long-run
    average identity independent of the arrival-process distribution)
    rather than in a single point measurement — and state explicitly
    that it predicts long-run averages, not any single item's transit
    time.
    **Source:** "All About Little's Law: Applications, Examples, Best
    Practices," https://www.6sigma.us/six-sigma-in-focus/littles-law-applications-examples-best-practices/

## Evidence trail

| # | Claim | Fetched source | Verification |
|---|-------|-----------------|---------------|
| 1,8 | USE method definition and per-resource checklist | brendangregg.com/USEmethod, /methodology.html | primary source (methodology's own author's site) |
| 2,9 | Percentile-based SLI/SLO practice, p50/p95/p99.9 tiering | sre.google/sre-book/service-level-objectives | primary source (Google SRE canonical book) |
| 3 | Error budget = 1 − SLO, burn-rate tracking over zero-tolerance | sre.google/workbook/error-budget-policy | primary source (Google SRE workbook) |
| 4,10 | Little's Law L=λW, nonlinear wait-time growth near saturation, long-run-average limitation | sixsigmadsi.com/glossary/littles-law, 6sigma.us Little's Law article | secondary/tertiary summary of established queueing theory (no conflicting authoritative source found) |
| 5,6,7 | Connection pooling leak-before-resize discipline, N+1/root-cause-over-hardware framing | clearpeaks.com database connection pooling guide | practitioner guide; corroborated qualitatively by USE-method root-cause-first principle (no conflict found across sources) |

No source conflicts encountered in this sweep; all four fetched-source
families (Gregg, Google SRE, queueing-theory summaries, connection-pool
practitioner guide) agree on their respective claims.
