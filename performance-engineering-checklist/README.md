# performance-engineering-checklist

Single responsibility: the performance-engineering role's phase-1 and
phase-2 human-facing authoring checklists, as literal reference material.
See `checklist.md`.

This is reference-only — no gate, no hook, no `hooks/` directory. It never
blocks a write; the enforcement backstop for these same facets/elements is
`performance-engineering-proposal-gate` (phase-1) and
`performance-engineering-record-gate` (phase-2). No kill switch is needed
since this plugin never executes or blocks anything.

Note: `checklist.md` lives at the plugin root rather than under a nested
`docs/` (the repo's output-layout convention reserves `docs/` for the
per-issue/standing-bucket tree at repo root, not per-plugin subdirectories).
