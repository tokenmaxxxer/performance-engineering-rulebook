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

A `PreToolUse` hook on `Write|Edit|MultiEdit` that fires only when the
target path matches:

- `docs/issue-<n>/proposals/*.md` (phase-1 proposal), or
- `docs/issue-<n>/reports/performance-engineering.md` (phase-2 record)

Any other path is out of scope and the hook exits 0 immediately.

For an in-scope write, the gate derives the resulting document text
(full content for `Write`, old→new substitution for `Edit`, chained
substitutions for `MultiEdit`), then finds the first occurrence of any
"workload" group phrase and any "evidence" group phrase (case-insensitive,
loaded at runtime from `hooks/heading-vocabulary.md`, never hardcoded
separately). If both are present and the evidence phrase's position
precedes the workload phrase's position, the write is denied (exit 2)
with a message pointing to methodology.md's implied order. If either
phrase is absent, this gate has nothing to check and allows the write —
absence is `performance-engineering-proposal-gate` / `performance-engineering-record-gate`'s
job, not this one's.

## Kill switch

```
export PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=1
```

## Composition

This plugin composes with, and does not replace:

- `performance-engineering-proposal-gate` — phase-1 facet presence
- `performance-engineering-record-gate` — phase-2 facet presence
- core canon's generic gates (e.g. `record-fields-gate.sh`)

All may fire on the same write; each judges a different concern.
