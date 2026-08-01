# performance-engineering-order-check

Single responsibility: intra-document **section-order** enforcement for
the performance-engineering role. It never checks whether a required
section exists — only, when a workload-class section and an
evidence-class section are both present in the same document, whether
the workload section comes first. This machinery is shared across both
of this role's write surfaces (phase-1 proposal and phase-2 record),
which is why it is packaged as its own plugin rather than duplicated
into the two facet-presence gates.

## What triggers it

A `PreToolUse` hook on `Write|Edit|MultiEdit|NotebookEdit|Bash` that fires
only when the target path matches:

- `docs/issue-<n>/proposals/*.md` (phase-1 proposal), or
- `docs/issue-<n>/reports/performance-engineering.md` (phase-2 record)

(a `Bash` write is matched by scanning path-shaped tokens in
`tool_input.command`). Any other path is out of scope and the hook exits 0
immediately.

For an in-scope write, the gate sources `core/hooks/lib/gate-lib.sh`/
`gate-lib.py` (by reference) to derive the resulting document text —
`Write`/`Edit`/`MultiEdit`/`NotebookEdit` are fully reconstructed
(honoring each edit's own `replace_all`), an undeterminable
Edit/MultiEdit/Bash write denies rather than passing through — then splits
it into sections on its `##`/`###` ATX headings (`hooks/section_lib.py`,
private to this repo) and finds the earliest section whose heading matches
the "workload" group and the earliest whose heading matches the
"evidence" group (case-insensitive, both loaded at runtime from
`hooks/heading-vocabulary.md`, never hardcoded separately). Matching is
against **headings only**, not body prose, and comparison is by section
start offset, not raw string position — a stray workload/evidence word
inside the wrong section's own prose cannot perturb the verdict. If both
sections are present and the evidence section starts before the workload
section, the write is denied (exit 2) with a message pointing to
methodology.md's implied order. If either is absent, this gate has
nothing to check and allows the write — absence is
`performance-engineering-proposal-gate` / `performance-engineering-record-gate`'s
job, not this one's.

## Kill switch

```
export PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=1
```

Any other value, including a typo, leaves the gate active — only a
recognized on-spelling (`1`/`true`/`yes`/`on`) disables it.

## Composition

This plugin composes with, and does not replace:

- `performance-engineering-proposal-gate` — phase-1 facet presence
- `performance-engineering-record-gate` — phase-2 facet presence
- core canon's generic gates (e.g. `record-fields-gate.sh`)

All may fire on the same write; each judges a different concern.
