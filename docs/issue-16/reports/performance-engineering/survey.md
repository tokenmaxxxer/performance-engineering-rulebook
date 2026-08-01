# issue-16 phase-1 survey: re-audit residual-defect current-state map

Scout skip record: this task is bounded remediation of confirmed,
internally-cited defects (issue #16 body + already-landed core canon
references), not a field/product decision with external alternatives to
compare — no design choice here benefits from scouting outside prior-art
already named by the issue (core #75, on-the-record #182). Skip condition:
"the spec literally leaves no design decision open" for the parts that
must match core's confirmed shape (source guard), narrowed to internal
code-consistency judgment for the rest (matcher parity, substring-check
hardening, doc cleanup). No scout-brief.md written.

## 1. Confirmed prerequisites landed on `tokenmaxxxer-core` `main`

- `core#75` (`52bdc15`, merged as PR #77): `gate-lib.sh`'s usage contract
  now documents (and `compliance-check.sh` now enforces) a **mandatory
  `||`-guarded source** —
  `. ".../gate-lib.sh" || { echo "...: cannot source gate-lib.sh" >&2; exit 2; }`
  — replacing the old unguarded `. ".../gate-lib.sh"` form. Rationale
  (from the commit): an unguarded source that fails when core is
  unreachable defines no `gate_*` function, so every
  `gate_kill_switch_active ... || { exit 0; }` call site reads the
  resulting "command not found" (127) as kill-switch-off and silently
  allows everything — fail-open on missing core. `compliance-check.sh`
  gained a detection rule (`grep` for `gate-lib\.sh"$` with no trailing
  `||` guard) and `run-gate-lib-tests.sh` gained a missing-core deny test
  case for it.
- `gate-lib.py` gained `gate_bash_write_targets(command)`: a python
  mirror of `gate-lib.sh`'s `grep -oE '[[:alnum:]_./~$-]+'` token-scan
  technique, same character class, returning the token list instead of
  printing lines.
- on-the-record `#182`: `spawn.py` now injects `CLAUDE_PLUGIN_ROOT_CORE`
  (not directly inspected here — this repo's gates already read
  `CLAUDE_PLUGIN_ROOT_CORE` with a relative-path fallback, so this
  prerequisite is a runtime-wiring guarantee, not a code change on this
  repo's side).

## 2. This repo's three gate scripts today — verified against current-state code

`proposal-gate.sh`, `record-gate.sh`, `order-check.sh` (all under
`performance-engineering-*/hooks/`) share near-identical scaffolding.
Verified line-by-line against the running files (paths below are
repo-relative):

### 2.1 Unguarded `gate-lib.sh` source — confirmed present in all three

`proposal-gate.sh:2-3`, `record-gate.sh:2-3`, `order-check.sh:2-3` all
read:

```sh
CORE_HOOKS="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks"
. "$CORE_HOOKS/lib/gate-lib.sh"
```

No `||` guard on the source line — exactly the core-#75-confirmed defect
shape. Today, a missing/unreachable core silently no-ops every subsequent
`gate_*` call as "not found" (127), and because none of these three
scripts wrap their own `gate_kill_switch_active` call in
`|| { trap - EXIT; exit 0; }` distinguishably from a real "kill switch
off" (`proposal-gate.sh:26`, `record-gate.sh:25`, `order-check.sh:29` all
use exactly that pattern), a missing core is indistinguishable from an
intentional kill-switch-off: fail-open.

### 2.2 hooks.json matcher vs. documented/coded coverage — confirmed mismatch

`performance-engineering-proposal-gate/hooks/hooks.json`,
`-record-gate/hooks/hooks.json`, `-order-check/hooks/hooks.json` each
register:

```json
"matcher": "Write|Edit|MultiEdit"
```

But every one of the three gate scripts' own header comment states
`# PreToolUse gate (Write|Edit|MultiEdit|NotebookEdit|Bash)`
(`proposal-gate.sh:6`, `record-gate.sh:6`, `order-check.sh:6`), and each
README repeats the same claim verbatim (`performance-engineering-proposal-gate/README.md:12`,
`-record-gate/README.md:12`, `-order-check/README.md:14`: `` `PreToolUse` on
`Write|Edit|MultiEdit|NotebookEdit|Bash` ``). The gate bodies themselves
do implement `Bash`-command-token-scan and `NotebookEdit` reconstruction
handling (`proposal-gate.sh:107-127`, same shape in the other two) — the
code is written to cover those tool kinds. But since Claude Code only
invokes a `PreToolUse` hook for tool names matching its `matcher` regex,
a `NotebookEdit` or `Bash` write to a phase-1/phase-2 document today never
reaches these scripts at all — the `Bash`/`NotebookEdit` branches are
dead code, and the README/header claim is a **false guarantee**: the
document says these tool kinds are gated; the wiring says they are not.

### 2.3 Weak substring facet checks — confirmed two shapes

`section_lib.py`'s `section_has_any()` (`section_lib.py:51-58`) does a
bare Python `in` (substring) test, no word boundary, on each needle
against the lower-cased section body. Two confirmed false-pass shapes
from this:

- **Citation negation-blind** (`proposal-gate.sh:196`): the citation
  facet accepts needle `"cited"` among its alternatives. `"cited"` is a
  substring of `"uncited"`, `"not cited"`, `"miscited"` — so a proposal
  that literally states *"this claim is uncited"* (the opposite of
  compliance) or *"sources are not cited here"* passes the (a)6
  evidence-citation-format check verbatim, because the checker only
  tests for the substring's presence, never its negation.
- **Method-name substring collision** (`proposal-gate.sh:175`,
  `record-gate.sh:173`): the method-named facet accepts needle
  `"use method"` (and `record-gate.sh` additionally `"red method"`).
  `"use method"` is a substring of ordinary prose such as *"we could use
  methodology X instead"* or *"the team may use methods other than
  USE"* — neither of which actually names the USE method per the
  facet's intent (methodology.md (a)3: "method named explicitly (USE /
  RED / Four Golden Signals)"). The checker's substring approach passes
  text that merely contains the English word "use" immediately before
  "method(ology)", independent of whether USE-the-acronym was named.

### 2.4 Duplicated `gate_bash_write_targets` logic — confirmed pre-dates core's canonization

All three gate scripts independently inline
`re.findall(r'[A-Za-z0-9_./~$-]+', cmd)` (`proposal-gate.sh:112`,
`record-gate.sh:105`, `order-check.sh:113`) to extract path-shaped tokens
from a `Bash` command — the exact technique core-#75 just canonized as
`gate_lib.gate_bash_write_targets()`. This repo's copies pre-date that
canonization and now duplicate logic this repo's own
`docs/handbooks/gate-house-standard.md`-by-reference convention (cited in
each of these gates' own header comments) says should be sourced, not
reimplemented.

### 2.5 README/manifest stale-name and ghost-file sweep — no residual findings

Checked every `.claude-plugin/plugin.json` (6 plugins), every `README.md`
(6 files, plus repo-root `README.md`), and every path each README
references, against the actual repo tree (`find` over
`performance-engineering*` plus `docs/`). All referenced files
(`hooks/*.sh`, `hooks/*.py`, `hooks/*.md`, `tests/run-gate-tests.sh`,
`docs/specs/approvers.md`, `docs/handbooks/*.md`) exist at the paths
claimed; no plugin manifest or README uses a role name other than
`performance-engineering`/its five sibling plugin names. This facet of
issue #16 (`README/manifest 옛 역할명·유령 파일 제거`) is a **no residual
findings** result for this repo, not a skip — the sweep ran and came back
clean. (issue #13's phase-2 already removed the prior batch of stale
references; nothing new has drifted in since.)

## 3. Existing test-suite shape (informs the missing-core case design)

Each `performance-engineering-*/tests/run-gate-tests.sh` runs the gate
script as a real subprocess against constructed JSON payloads
(`CLAUDE_PLUGIN_ROOT_CORE` pointed at a local `tokenmaxxxer-core`
checkout), asserting exit code + stderr substring per case. None of the
three currently include a case that points `CLAUDE_PLUGIN_ROOT_CORE` (and
the derived relative fallback) at a **nonexistent** core, so the
fail-open behavior in §2.1 has no regression test today — the same gap
core-#75 just closed for its own 7 core gates via
`run-gate-lib-tests.sh`.

## Gap line (what the field already meets vs. what's missing)

Core canon (via #75) already supplies: the guarded-source usage-contract
line, `compliance-check.sh`'s automated detection of the unguarded form,
and `gate_lib.gate_bash_write_targets()` as the reference implementation
to call instead of reimplementing. This repo's three gates meet none of
those three yet (§2.1, §2.4) despite citing the by-reference convention
in their own header comments. Separately, this repo owns two defects core
never covered: the matcher/coverage mismatch (§2.2) and the
substring-check weaknesses (§2.3), both internal to this repo's own
`section_lib.py`/`hooks.json`, with no core-canon equivalent to adopt.
