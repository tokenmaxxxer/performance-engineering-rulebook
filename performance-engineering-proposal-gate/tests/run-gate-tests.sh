#!/usr/bin/env bash
# performance-engineering-proposal-gate's own gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
export CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core}"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

newtd() { td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; }

run_payload() { # want name payload [extra_env...] — caller must call newtd first
  want="$1"; name="$2"; payload="$3"; shift 3
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$HOOKS/proposal-gate.sh" 2>&1 >/dev/null)"
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$want" "$got" "$name"
}

write_payload() { # file content
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]},"cwd":sys.argv[3]}))
' "$1" "$2" "$td"
}

run() { # want name file content
  newtd; mkdir -p "$td/$(dirname "$3")"
  payload="$(write_payload "$3" "$4")"
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/proposal-gate.sh" 2>&1 >/dev/null)"
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

PROP=docs/issue-10/proposals/methodology-enforcement.md

SLO='p99 < 250ms'
HYP='hypothesis: connection pool saturates at high rps, grounded in existing telemetry'
METHOD='method: USE Method chosen to decide whether the load/latency judgment is satisfied'
WORKLOAD='workload characterization: 200 concurrent users, 80/20 read/write transaction mix, 5-minute ramp-up'
PREMORTEM='premortem: blast radius limited to canary pool, killswitch env flag, rollback via previous deploy'
EVIDENCE='source: https://example.com/bench'

full() { printf '## SLO\n%s\n## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\n%s\n' \
  "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"; }

without_slo()       { printf '## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\n%s\n' "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"; }
without_hypothesis() { printf '## SLO\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\n%s\n' "$SLO" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"; }
without_method()    { printf '## SLO\n%s\n## Hypothesis\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\n%s\n' "$SLO" "$HYP" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"; }
without_workload()  { printf '## SLO\n%s\n## Hypothesis\n%s\n## Method\n%s\n## Premortem\n%s\n## Citation\n%s\n' "$SLO" "$HYP" "$METHOD" "$PREMORTEM" "$EVIDENCE"; }
without_premortem() { printf '## SLO\n%s\n## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Citation\n%s\n' "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$EVIDENCE"; }
without_evidence()  { printf '## SLO\n%s\n## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n' "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM"; }

run allow complete-compliant     "$PROP" "$(full)"
run deny  missing-slo            "$PROP" "$(without_slo)"
run deny  missing-hypothesis     "$PROP" "$(without_hypothesis)"
run deny  missing-method         "$PROP" "$(without_method)"
run deny  missing-workload       "$PROP" "$(without_workload)"
run deny  missing-premortem      "$PROP" "$(without_premortem)"
run deny  missing-evidence       "$PROP" "$(without_evidence)"
run allow foreign-path           "README.md" "x"

# --- issue-13 §2.2 semantic-check upgrade cases ---

# Bare-word decoy: " use " outside the Method section, real method phrase absent.
decoy_bare_use() {
  printf '## SLO\n%s\n## Hypothesis\n%s\n## Notes\nwe use a script here, nothing methodological\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\n%s\n' \
    "$SLO" "$HYP" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"
}
run deny  bare-use-decoy-denies  "$PROP" "$(decoy_bare_use)"

# SLO comparator with no numeric threshold.
slo_no_number() {
  printf '## SLO\np99 < acceptable levels\n## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\n%s\n' \
    "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"
}
run deny  slo-no-numeric-denies  "$PROP" "$(slo_no_number)"

# Correctly-worded SLO figure placed inside the wrong section (Premortem).
slo_wrong_section() {
  printf '## SLO\nsee premortem for the figure\n## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n%s\n## Citation\n%s\n' \
    "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$SLO" "$EVIDENCE"
}
run deny  slo-wrong-section-denies "$PROP" "$(slo_wrong_section)"

# --- issue-13 §3 mandatory gate-house test cases ---

# 1. Edit with replace_all:true against a multiply-occurring old_string.
# The SLO figure occurs twice inside the SLO section; replacing it with
# non-numeric text at BOTH occurrences must deny (no numeric SLO left).
# The prior first-occurrence-only bug would have left the second occurrence
# intact and incorrectly allowed.
edit_payload() { # file old new replace_all
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3],"replace_all":sys.argv[4]=="true"},"cwd":sys.argv[5]}))
' "$1" "$2" "$3" "$4" "$td"
}
newtd; mkdir -p "$td/docs/issue-10/proposals"
slo_twice() { printf '## SLO\n%s\nAlso restated: %s\n## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\n%s\n' \
  "$SLO" "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"; }
printf '%s' "$(slo_twice)" > "$td/$PROP"
payload="$(edit_payload "$PROP" "$SLO" "p99 < acceptable levels" "true")"
run_payload deny replace-all-edit-both-occurrences "$payload"

# 2. MultiEdit with a mix of replace_all true/false edits in one call.
newtd; mkdir -p "$td/docs/issue-10/proposals"
printf '%s' "$(full)" > "$td/$PROP"
multiedit_payload() {
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":sys.argv[1],"edits":[
  {"old_string":"## SLO","new_string":"## SLO (renamed)","replace_all":True},
  {"old_string":"p99 < 250ms","new_string":"p99 < acceptable levels","replace_all":False}
]},"cwd":sys.argv[2]}))
' "$1" "$td"
}
payload="$(multiedit_payload "$PROP")"
run_payload deny multiedit-mixed-replace-all "$payload"

# 3. Malformed JSON: truncated, non-object top level, empty payload.
newtd
run_payload deny malformed-json-truncated  '{"tool_name":"Write","tool_inp'
newtd
run_payload deny malformed-json-array      '["not","an","object"]'
newtd
run_payload deny malformed-json-empty      ''

# 4. Kill-switch set to an unrecognized value stays active; recognized on-spellings disable.
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(write_payload "$PROP" "$(without_slo)")"
run_payload deny kill-switch-garbage-stays-active "$payload" env PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=banana
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(write_payload "$PROP" "$(without_slo)")"
run_payload allow kill-switch-on-1-disables "$payload" env PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=1
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(write_payload "$PROP" "$(without_slo)")"
run_payload allow kill-switch-on-true-disables "$payload" env PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=true

# 5. Absolute file_path and ./-prefixed relative path match the same scope.
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(python3 -c '
import json,sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/"+sys.argv[2],"content":sys.argv[3]},"cwd":sys.argv[1]}))
' "$td" "$PROP" "$(without_slo)")"
run_payload deny absolute-path-same-scope "$payload"
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(write_payload "./$PROP" "$(without_slo)")"
run_payload deny dot-slash-prefixed-path "$payload"

# 6. A Bash-tool write reaching the same target a Write-tool call would hit.
newtd
bash_payload() {
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))
' "$1" "$td"
}
payload="$(bash_payload "cat > $PROP <<EOF
some content
EOF")"
run_payload deny bash-write-undeterminable-denies "$payload"

# 7. missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere must deny
# (issue-75-shaped fail-open guard), not silently allow.
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(write_payload "$PROP" "$(without_slo)")"
run_payload deny missing-core-denies "$payload" env CLAUDE_PLUGIN_ROOT_CORE="$td/no-such-core"

# --- issue-16 §2.3 substring-hardening regression cases ---

# "uncited" must no longer satisfy the citation facet (own-negation false pass).
uncited_only() {
  printf '## SLO\n%s\n## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\nthis figure is uncited\n' \
    "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM"
}
run deny  uncited-decoy-denies "$PROP" "$(uncited_only)"

# "not cited" must no longer satisfy the citation facet (negation window).
not_cited_only() {
  printf '## SLO\n%s\n## Hypothesis\n%s\n## Method\n%s\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\nthis figure is not cited anywhere\n' \
    "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM"
}
run deny  not-cited-decoy-denies "$PROP" "$(not_cited_only)"

# lower-case "use methodology X" must no longer satisfy the method-name facet.
use_methodology_decoy() {
  printf '## SLO\n%s\n## Hypothesis\n%s\n## Method\nwe use methodology X to decide\ndecide judgement here\n## Workload Characterization\n%s\n## Premortem\n%s\n## Citation\n%s\n' \
    "$SLO" "$HYP" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"
}
run deny  use-methodology-decoy-denies "$PROP" "$(use_methodology_decoy)"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
