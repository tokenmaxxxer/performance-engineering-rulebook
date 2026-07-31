# Current-state survey: performance-engineering plugin enforcement

Subject: issue-10, phase 1. Scope: `performance-engineering/hooks/directive.sh`,
`performance-engineering/hooks/methodology-gate.sh`,
`performance-engineering/hooks/hooks.json`, measured against the norms
adopted in `docs/issue-1/proposals/methodology.md` (6 phase-1 proposal
sections in (a), 7 phase-2 record elements in (b)).

## 1. directive.sh — what it currently says

`produces` is a single string:

```
PRODUCES (required record fields): performance budget (numeric SLO, e.g.
p99 latency < Xms), profiling evidence (USE+RED signals, percentile-based:
p50/p95/p99), bottleneck list (evidence-linked)

WRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)
```

This is a one-line-per-facet *summary* of methodology.md (b), not a
per-facet directive. It names "numeric SLO", "USE+RED", "percentile-based"
but gives no actionable per-facet criteria: it does not say what makes an
SLO acceptable-numeric vs not, what "USE+RED" measurement means concretely,
or how bottleneck-to-evidence linkage should be demonstrated. It has zero
coverage of the phase-1 proposal facets (hypothesis, method-choice reason,
workload characterization, premortem, evidence-citation format) — directive.sh
only ever speaks in terms of the phase-2 record's required fields.

## 2. methodology-gate.sh — what it currently checks

Full current logic (see file): it fires only on
`docs/issue-<n>/reports/performance-engineering.md` writes/edits, extracts
`content` (Write) or `new_string` (Edit) via a flat grep (no MultiEdit
handling, no old_string+new_string reconstruction, no python3 JSON
parsing), and denies unless the extracted text matches two loose regexes:

- `p9[0-9]|p50` (any percentile mention, anywhere)
- `\bUSE\b|\bRED\b` (either methodology name, anywhere)

That is the entirety of the check.

## 3. hooks.json — what it currently registers

`directive.sh` on `SessionStart` (static text, no dynamic state), and
`methodology-gate.sh` on `PreToolUse` for `Write|Edit|MultiEdit` (no
scope restriction in the matcher itself — the gate self-scopes by file
path inside the script). No other hooks are registered. No `agents/`
directory exists under `performance-engineering/`. No `docs/handbooks/`
file exists in this repo at all.

## 4. Gaps against the adopted methodology

**(a) Presence-only, 2-of-7 element coverage on the record.** methodology.md
(b) requires 7 phase-2 record elements: (1) methodology-cite with per-signal
measurements, (2) environment/config reproducibility, (3) workload
characterization (actual vs proposed), (4) percentile-based quantitative
evidence, (5) bottleneck list with evidence linkage, (6) exit-criteria
verdict, (7) conclusion/hand-off rationale. The current gate only checks
for the *existence of the words* "p50/p9x" and "USE/RED" anywhere in the
diff — it satisfies element (1)'s keyword and part of element (4)'s
keyword, but has no check at all for elements (2), (3), (5), (6), or (7).
A record could pass the gate today by writing "USE p99" once in an
unrelated sentence with none of the other six elements present.

**(b) No phase-1 proposal-write gate exists at all.** methodology.md (a)
requires 6 phase-1 proposal sections: numeric SLO/goal, falsifiable
hypothesis, named method with reason, workload characterization
(planned), premortem (blast-radius/killswitch/rollback), and evidence-
citation format. `methodology-gate.sh`'s path regex
(`docs/issue-[0-9]+/reports/performance-engineering\.md$`) matches only
the report path — it never fires on
`docs/issue-<n>/proposals/*.md` writes. Nothing today mechanically checks
that a phase-1 proposal contains a numeric SLO, a falsifiable hypothesis,
or a premortem before that proposal is committed.

**(c) No order/state enforcement exists.** Nothing stops a session from
writing "USE method, p99 latency" into the record with no actual
investigate → evidence → adopt sequence behind it — the two keyword
checks are independent of each other and independent of position in the
document. There is no check that, e.g., a "workload characterization"
section appears before a "percentile evidence" section, nor any state
file tracking that a hypothesis was proposed before a method was chosen.
This is true both within a single document (intra-document order) and
across the proposal → record pair (inter-document order — nothing checks
that the record's methodology-cite matches what the proposal proposed).

**(d) No repo-root `tests/` directory and no gate tests exist.**
`ls performance-engineering/hooks/tests` confirms no such path exists.
There is also no `tests/` at the repo root at all in this repo currently
(unlike implementation-rulebook's sibling checkout, which has
`tests/run-gate-tests.sh` + `tests/parse-check.sh`). No pass/deny test
case exists anywhere for `methodology-gate.sh`'s current or any future
behavior.

**(e) No agents/checklist artifact exists for the repeating procedure.**
The methodology implies a repeating phase-1 procedure (SLO → hypothesis →
method choice → workload characterization → premortem) and a repeating
phase-2 procedure (methodology-cite → repro-info → workload-actual →
percentile-evidence → bottleneck-evidence-link → exit-criteria-verdict →
handoff). Neither is captured anywhere as a checklist, a handbook doc, or
an `agents/` subagent definition — a future session re-deriving this
sequence from methodology.md's prose each time is the only current
mechanism, with no artifact enforcing that all steps were actually walked
through.

## Summary table

| Required element (methodology.md) | Directive coverage | Gate coverage |
|---|---|---|
| Phase 1: numeric SLO | one-line mention | none (gate doesn't fire on proposals) |
| Phase 1: falsifiable hypothesis | none | none |
| Phase 1: method + reason | none | none |
| Phase 1: workload characterization | none | none |
| Phase 1: premortem | none | none |
| Phase 1: evidence-citation format | none | none |
| Phase 2: methodology-cite + measurements | one-line mention | keyword-only (`USE\|RED`) |
| Phase 2: environment/repro info | none | none |
| Phase 2: workload characterization (actual) | none | none |
| Phase 2: percentile evidence | one-line mention | keyword-only (`p9[0-9]\|p50`) |
| Phase 2: bottleneck-evidence linkage | one-line mention | none |
| Phase 2: exit-criteria verdict | none | none |
| Phase 2: hand-off rationale | one-line mention (in HAND-OFF) | none |

This table is the basis for the scout-brief's must-be list and the
proposal's per-facet directive design in section (1) below.
