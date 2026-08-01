# issue-16 phase-1 proposal: gate A+ final closeout (re-audit residual defects)

Status: phase-1 proposal only. No code changes in this PR. Phase 2 (the
actual fix) opens only after an approvers.md Approve per contract v3 s19.

Survey backing this proposal:
[`docs/issue-16/reports/performance-engineering/survey.md`](../reports/performance-engineering/survey.md).

## Numeric SLO

This role's own enforcement tooling carries an implicit latency SLO the
same as any other performance-sensitive code path: p99 gate-script
execution latency < 200ms per invocation (each `PreToolUse` hook blocks
the tool call synchronously, so it sits directly in the interactive-edit
critical path). None of the changes in this proposal add I/O, network
calls, or unbounded loops — the guard change (§2) adds one `||` branch
evaluated only on the already-rare core-missing path, the matcher change
(§1) is JSON-only and adds no runtime cost, and the substring-hardening
change (§3) replaces one `in` check with one compiled-regex `.search()`
per needle, same order of complexity. Phase 2's test matrix must confirm
the fixed gates still run under that same p99 < 200ms bound against the
existing fixture payloads — a regression there would falsify the "narrow,
mechanical fix" hypothesis stated below.

## Workload characterization

The workload this change must be judged against is the gate-invocation
workload of this repo's own enforcement tooling, not an application
workload — the same framing issue-13's proposal used for the same class
of change. Concurrency is fixed at 1: a `PreToolUse` hook runs
synchronously, once per tool call, never concurrently within a session.
The request/transaction mix this proposal's phase-2 test matrix must
cover is five tool-kind x gate-target combinations — `Write`/`Edit`/
`MultiEdit` (already exercised) plus `NotebookEdit` and `Bash`-command
token-scan (newly wired into the matcher, §1) — crossed against the two
gate-target document shapes (`docs/issue-<n>/proposals/*.md`,
`docs/issue-<n>/reports/performance-engineering.md`), plus a sixth,
core-unreachable case (§2) that is orthogonal to tool kind. Ramp-up is not
applicable: each hook invocation is a fresh, stateless subprocess: there
is no warm/cold state to characterize.

## Hypothesis

Grounded in the current-state survey's line-by-line reads of the running
gate scripts (survey §2, not a guess): the four defects named in issue
#16's re-audit are each independently reproducible from the code as it
stands today, and each has a narrow, mechanical fix that does not touch
the other three. Specifically: the `hooks.json` matcher for all three
gates is `Write|Edit|MultiEdit` while the script bodies and READMEs both
document `Write|Edit|MultiEdit|NotebookEdit|Bash` coverage (survey §2.2,
observed directly in the committed `hooks.json`/`.sh`/`README.md` text —
not inferred); all three gates source `gate-lib.sh` unguarded, the same
shape core-#75 already confirmed and fixed in its own 7 gates (survey
§2.1, diffed against `core@52bdc15`); and two of `section_lib.py`'s facet
needles (`"cited"`, `"use method"`) are bare substring tests with no
word-boundary or negation handling, demonstrably satisfied by their own
negations (survey §2.3, walked through with concrete counter-strings). If
this hypothesis is wrong, phase-2's test matrix (§3) will show a gate
still failing after its narrow fix is applied, or show the fix breaking
an existing passing case — either falsifies it directly.

## Method

Method: use method — apply core-#75's confirmed-correct guard/regex
verbatim where this repo's defect is the exact shape core already fixed
(source guard, `gate_bash_write_targets` duplication), and apply the
narrowest code change that closes the gap where it's local to this repo
(matcher parity, substring hardening). This role's `YOU DECIDE` line asks
whether load/latency targets are satisfied; the decision to prefer
reference-not-reimplementation here is a direct read of that mandate onto
gate-authoring itself — an enforcement script that reimplements
already-canonized logic is exactly the kind of untracked-latency/drift
risk this role exists to catch, so citing and reusing the canon copy is
the correct call, not a stylistic preference.

## Premortem

Blast radius: limited to this repo's three gate scripts
(`proposal-gate.sh`, `record-gate.sh`, `order-check.sh`) and their
`hooks.json` matchers — no core-canon file changes, no changes to any
other role's rulebook. A regression here can only ever make this role's
own phase-1/phase-2 writes stricter or (if the fix is wrong) looser; it
cannot affect another role's gates, which each source their own copy of
`gate-lib.sh` independently. Kill switch: each gate already exposes its
own `PERFORMANCE_ENGINEERING_{PROPOSAL_GATE,RECORD_GATE,ORDER_CHECK}_OFF`
env var (unchanged by this proposal — the fix does not touch the
kill-switch call sites), so a bad phase-2 land can be neutralized per-gate
without a revert. Rollback: a straight `git revert` of the phase-2 commit
restores the exact current (defective but previously-shipped) behavior,
since phase-2 will be scoped to these three files plus their tests and
READMEs — no schema or external-state change to unwind.

## Remediation design

### 1. Matcher/coverage parity (§2.2)

Change all three `hooks.json` files'
`"matcher": "Write|Edit|MultiEdit"` to
`"matcher": "Write|Edit|MultiEdit|NotebookEdit|Bash"`, matching what the
script bodies already implement and what the READMEs already claim. This
is the only file class where the fix is "make the wiring match the
code," not "add code" — the `NotebookEdit`/`Bash` handling already exists
in `proposal-gate.sh:107-131`/`record-gate.sh`/`order-check.sh`'s Python
judges; today it is simply unreachable dead code.

### 2. Guarded `gate-lib.sh` source (§2.1) — adopt core-#75's confirmed shape

Replace, in all three gate scripts:

```sh
. "$CORE_HOOKS/lib/gate-lib.sh"
```

with core-#75's canonical guarded form:

```sh
. "$CORE_HOOKS/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
```

(one line per script, `<gate-name>` substituted per file). This closes
the fail-open-on-missing-core hole by construction: a failed source now
exits 2 (deny) immediately, before any `gate_kill_switch_active` call can
misread the missing functions as "kill switch off."

### 3. Substring-check hardening (§2.3)

In `section_lib.py`, add word-boundary matching and, for the citation
facet, negation-awareness:

- `section_has_any()` gains a boundary-aware match mode (regex
  `\bneedle\b` in place of bare `in`) used by the two vulnerable needle
  sets (method-name, citation) — the other needles (`"assumption"`,
  `"blast radius"`, `"rollback"`, etc.) are unaffected since they are not
  substrings of their own negations or of unrelated common phrases in the
  same way.
- The citation facet's `"cited"` needle is replaced with a
  negation-excluding pattern: match `\bcited\b` only when not immediately
  preceded by `un` or by a `not`/`n't`/`never` token within a short
  window — i.e. `"uncited"`, `"not cited"`, `"isn't cited"` no longer
  satisfy the facet; `"sources are cited"`, `"per RFC..."`, `"cited:"` and
  the existing `"source:"`/`"assumption"`/URL needles still do.
- The method-name facet's `"use method"` needle is replaced with a
  pattern requiring the literal acronym context (`\bUSE\b` case-sensitive
  before lower-casing, or `\bUSE method\b`/`\bUSE Method\b` on the
  original-case text) so "use methodology X" no longer satisfies it while
  "USE Method" and "the USE method" still do; `"red method"`/
  `"golden signal"`/`"four golden signals"` needles are unaffected (they
  do not collide with ordinary English usage the way "use" does).

### 4. Reference core's `gate_bash_write_targets` instead of duplicating it (§2.4)

Replace each gate's inline
`re.findall(r'[A-Za-z0-9_./~$-]+', cmd)` call with
`gate_lib.gate_bash_write_targets(cmd)`, now that core-#75 has canonized
that exact technique in `gate_lib.py`. No behavior change (same regex,
same character class) — this is a duplication removal, not a logic
change, keeping this repo's compliance with its own by-reference
convention.

### 5. `compliance-check.sh` parity

Phase 2 will run `tokenmaxxxer-core`'s `compliance-check.sh` against this
repo's three gate scripts post-fix and record the PASS in the phase-2
record — the same detection rule core-#75 added (unguarded
`gate-lib.sh"$` source with no `||` guard) must report clean once §2 above
lands.

## Evidence citation

Per methodology.md (a)6: every claim above traces to a source or is
labeled an assumption.

- `core#75` guard shape and `compliance-check.sh` rule: `tokenmaxxxer-core`
  commit `52bdc15` (`git show 52bdc15 -- core/hooks/lib/gate-lib.sh
  core/hooks/lib/gate-lib.py core/hooks/tests/compliance-check.sh`,
  consulted directly this session).
- Matcher/coverage mismatch, unguarded source, substring-check shapes: this
  repo's own committed files, read directly this session —
  `performance-engineering-proposal-gate/hooks/hooks.json`,
  `performance-engineering-record-gate/hooks/hooks.json`,
  `performance-engineering-order-check/hooks/hooks.json`,
  `performance-engineering-{proposal-gate,record-gate,order-check}/hooks/*.sh`,
  `performance-engineering-order-check/hooks/section_lib.py`, and the
  matching `README.md` files.
- README/manifest ghost-file sweep result: assumption-labeled as "no
  residual findings" per a direct `find`+`grep` pass this session (survey
  §2.5) — not an external source, a first-party repo-state observation.
- on-the-record `#182` (`CLAUDE_PLUGIN_ROOT_CORE` injection): cited
  per issue #16's own body as an already-landed prerequisite; not
  independently re-verified this session since it is a `spawn.py`-side
  runtime-wiring guarantee outside this repo's tree.
