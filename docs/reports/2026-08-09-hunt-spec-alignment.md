---
proposal: docs/issue-19/proposals/spec-alignment.md
---

# Hunt record — spec-alignment

## after-proposal — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — the proposal's own literal content for `docs/specs/record-fields-terminal-states.json` (`{"performance-engineering": ["landed"]}`, step 7) uses this rulebook's *role name* as the override key, but core's `record-fields-gate.sh` (the sole consumer of this file, at `hooks/record-fields-gate.sh` in the `core` checkout, `CLAUDE_PLUGIN_ROOT_CORE`) validates each key against a closed `KIND_TERMINAL_DEFAULTS` set of contract-§2 *kind* names (`product-record`, `coding-record`, `qa-record`, `feasibility-record`, `ux-design-record`, `review-record`, `verify-record`, `ops-record`, `reflect-record`) — `performance-engineering` is not, and cannot be, one of them, because `performance-engineering` never appears in `ROLE_TO_KIND` either (that map only names `product`/`coding`/`implementation`/`qa`/`feasibility`/`ux-design`/`review`/`verify`/`ops`/`reflect`). Writing the file exactly as the proposal specifies causes the gate to `deny()` with "names unrecognized kind 'performance-engineering'" — and because this gate fires on *every* role's record/proposal write across the whole repo family (it is generic core code keyed by `CLAUDE_ROLE`, not scoped to performance-engineering), a malformed/unrecognized-kind override file fails closed globally, blocking every other role's record writes too, not just this rulebook's. The proposal presents this JSON file's shape as settled ("`{"performance-engineering": ["landed"]}`") without ever consulting the closed kind-vocabulary state that the consuming gate maintains — that vocabulary has no slot for a role that the contract's §2 kind table has never named, and the proposal never checks or extends that table.
Kind: design-error
Seed: docs/issue-19/proposals/spec-alignment.md (step 7, the `docs/specs/record-fields-terminal-states.json` plan), plus current repo state of performance-engineering-record-gate/hooks/record-gate.sh
cap_seconds: 120
tier: default
diff_stat_lines: 2 new files (survey.md + spec-alignment.md), ~340 lines total
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:15:00Z

### Reproduce
```
# core/hooks/record-fields-gate.sh (CLAUDE_PLUGIN_ROOT_CORE checkout) defines:
KIND_TERMINAL_DEFAULTS = {"product-record","coding-record","qa-record","feasibility-record",
                          "ux-design-record","review-record","verify-record","ops-record","reflect-record"}
override_data = {"performance-engineering": ["landed"]}   # <- exact content proposed in step 7
for ok, ov in override_data.items():
    if ok not in KIND_TERMINAL_DEFAULTS:
        print("DENY: unrecognized kind %r (not one of contract sec2's record kinds: %s)"
              % (ok, ", ".join(sorted(KIND_TERMINAL_DEFAULTS))))
```
Run: `python3 -c "<above>"`

### Observed
```
DENY: unrecognized kind 'performance-engineering' (not one of contract sec2's record kinds: coding-record, feasibility-record, ops-record, product-record, qa-record, reflect-record, review-record, ux-design-record, verify-record)
```
This is the literal deny message `record-fields-gate.sh` emits (see `hooks/record-fields-gate.sh` lines ~386-390 in the core checkout) when it encounters the file the proposal plans to create, on the very next write to any role's own record or proposal file anywhere in the repo family — the gate parses this JSON on every triggering write, unconditionally, once the file exists.

### Expected
The proposal should either (a) name a real contract-§2 kind this role's records map to (extending `ROLE_TO_KIND`/`KIND_TERMINAL_DEFAULTS` in core first, which is out of this repo's write scope and not requested), or (b) not claim the override file "overrides the contract default per-kind terminal-state table" for this role at all — as written, step 7 both fails to achieve its stated purpose (this role's terminal set is never actually overridden, since `kind` never resolves for an unmapped role and the override lookup `if kind and kind in override_data` short-circuits false) and, worse, actively breaks every other role's record-fields-gate check the moment the file lands, because the gate validates the file's keys unconditionally regardless of which role triggered the write.

## before-landing — stance 1: assume this change and another plugin's rule cancel each other — find the pair

Verdict: NO FINDING
Seed: performance-engineering-record-gate/hooks/record-gate.sh (new sli/error-budget/verdict section checks + frontmatter loop_state closed-set check), performance-engineering-order-check/hooks/heading-vocabulary.md (new "sli"/"error-budget" groups), performance-engineering/hooks/directive.sh
cap_seconds: 120
tier: default (size:21-200-line-diff)
diff_stat_lines: 70 insertions(+), 2 deletions(-) across the 3 hook-bearing files
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:15:00Z

Searched for a plugin whose rule would permit what record-gate.sh's new checks deny, or vice versa, on the same write surface. `performance-engineering-order-check/hooks/order-check.sh` only reads the `workload`/`evidence` heading groups (confirmed by reading its header comment and body) — it never inspects `sli`, `error-budget`, `exit-criteria` verdict text, or frontmatter `loop_state`, so it cannot cancel the new checks. `grep -rln loop_state` across the repo shows the field is read only inside `performance-engineering-record-gate/hooks/record-gate.sh` (everywhere else is prose docs). No core-canon generic record-fields gate exists in this repo family (`find . -iname "*record-fields-gate*"` empty; only the performance-engineering-* plugins exist). `proposal-gate.sh` gates a different write surface (phase-1 proposals) than `record-gate.sh` (phase-2 records), so the two never evaluate the same document. No reproducible cross-plugin cancellation found within the cap.

Noted but out of scope for this stance: the new `loop_state` deny() block in record-gate.sh is not wrapped in the `if not graceful_exit and ...` guard that every sibling check in the same function uses — this is an intra-file inconsistency within record-gate.sh itself, not a conflict with another plugin's rule, so it does not satisfy "the pair" this stance asks for.
