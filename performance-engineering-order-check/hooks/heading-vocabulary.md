# Canonical heading vocabulary — order-check.sh / proposal-gate.sh / record-gate.sh

Case-insensitive phrase groups these three gates recognize as referring to
the same section, single-sourced here per `docs/handbooks/gate-house-standard.md`'s
reference-not-duplicate convention. A proposal/record may use any phrase
within a group as its `##`/`###` heading text; `section_lib.py`'s
`split_sections()` matches a document's ATX headings against these groups
(never the document body), so a decoy word in unrelated prose can never
satisfy a group match, and order-check.sh compares section *start
offsets*, not raw string positions.

order-check.sh only reads the `workload` and `evidence` groups (must
precede/follow). proposal-gate.sh reads `slo`, `hypothesis`, `method`,
`workload`, `premortem`, `citation`. record-gate.sh reads `method`
(shared), `repro`, `workload`, `evidence`, `bottleneck`, `exit-criteria`,
`handoff`.

## "workload" group (must precede "evidence" group)
- workload characterization
- workload-actual
- workload profile

## "evidence" group (must follow "workload" group)
- percentile evidence
- percentile-evidence
- profiling evidence

## "slo" group
- numeric slo
- slo

## "hypothesis" group
- hypothesis
- falsifiable hypothesis

## "method" group
- method
- methodology

## "premortem" group
- premortem

## "citation" group
- evidence citation
- sources
- citation

## "repro" group
- repro
- reproduction

## "bottleneck" group
- bottleneck

## "exit-criteria" group
- exit criteria verdict
- exit-criteria verdict

## "handoff" group
- hand-off
- handoff
- hand off
