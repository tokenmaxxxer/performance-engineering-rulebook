#!/usr/bin/env bash
# performance-engineering-record-gate's own gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
export CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core}"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

newtd() { td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; }

run_payload() { # want name payload [extra_env...] — caller must call newtd first
  want="$1"; name="$2"; payload="$3"; shift 3
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$HOOKS/record-gate.sh" 2>&1 >/dev/null)"
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
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/record-gate.sh" 2>&1 >/dev/null)"
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

REC=docs/issue-10/reports/performance-engineering.md

CITE='methodology-cite: applied USE method, saturation 92%, errors 0.2%'
REPRO='repro info: c5.xlarge, tool version wrk 4.2'
WORKLOAD='workload-actual: actually exercised workload matches phase-1 concurrency mix'
PCTL='percentile evidence: p50 40ms, p95 180ms, p99 240ms'
BOTTLENECK='bottleneck: connection pool, evidence linked to the percentile spike above'
EXIT='exit-criteria verdict: pass against SLO, no deviation'
HANDOFF='hand-off: no hand-off is needed, no capacity constraint hit'

full() { printf '## Method\n%s\n## Repro\n%s\n## Workload Characterization\n%s\n## Percentile Evidence\n%s\n## Bottleneck\n%s\n## Exit Criteria Verdict\n%s\n## Hand-off\n%s\n' \
  "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF"; }

without_cite()       { printf '## Repro\n%s\n## Workload Characterization\n%s\n## Percentile Evidence\n%s\n## Bottleneck\n%s\n## Exit Criteria Verdict\n%s\n## Hand-off\n%s\n' "$REPRO" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF"; }
without_repro()      { printf '## Method\n%s\n## Workload Characterization\n%s\n## Percentile Evidence\n%s\n## Bottleneck\n%s\n## Exit Criteria Verdict\n%s\n## Hand-off\n%s\n' "$CITE" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF"; }
without_workload()   { printf '## Method\n%s\n## Repro\n%s\n## Percentile Evidence\n%s\n## Bottleneck\n%s\n## Exit Criteria Verdict\n%s\n## Hand-off\n%s\n' "$CITE" "$REPRO" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF"; }
without_percentile() { printf '## Method\n%s\n## Repro\n%s\n## Workload Characterization\n%s\n## Bottleneck\n%s\n## Exit Criteria Verdict\n%s\n## Hand-off\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$BOTTLENECK" "$EXIT" "$HANDOFF"; }
without_bottleneck() { printf '## Method\n%s\n## Repro\n%s\n## Workload Characterization\n%s\n## Percentile Evidence\n%s\n## Exit Criteria Verdict\n%s\n## Hand-off\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$EXIT" "$HANDOFF"; }
without_exit()       { printf '## Method\n%s\n## Repro\n%s\n## Workload Characterization\n%s\n## Percentile Evidence\n%s\n## Bottleneck\n%s\n## Hand-off\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$HANDOFF"; }
without_handoff()    { printf '## Method\n%s\n## Repro\n%s\n## Workload Characterization\n%s\n## Percentile Evidence\n%s\n## Bottleneck\n%s\n## Exit Criteria Verdict\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$EXIT"; }

run allow complete-compliant   "$REC" "$(full)"
run deny  missing-cite         "$REC" "$(without_cite)"
run deny  missing-repro        "$REC" "$(without_repro)"
run deny  missing-workload     "$REC" "$(without_workload)"
run deny  missing-percentile   "$REC" "$(without_percentile)"
run deny  missing-bottleneck   "$REC" "$(without_bottleneck)"
run deny  missing-exit         "$REC" "$(without_exit)"
run deny  missing-handoff      "$REC" "$(without_handoff)"
run allow graceful-exit        "$REC" "$(printf '## Method\n%s\n## Repro\n%s\n## Workload Characterization\n%s\ndisproven at hypothesis stage\n' "$CITE" "$REPRO" "$WORKLOAD")"
run allow foreign-path         "README.md" "x"

# --- issue-13 §2.2 semantic-check upgrade case ---

# Correctly-worded percentile figure placed inside the wrong section (Bottleneck).
pctl_wrong_section() {
  printf '## Method\n%s\n## Repro\n%s\n## Workload Characterization\n%s\n## Percentile Evidence\nsee bottleneck section\n## Bottleneck\n%s\n%s\n## Exit Criteria Verdict\n%s\n## Hand-off\n%s\n' \
    "$CITE" "$REPRO" "$WORKLOAD" "$BOTTLENECK" "$PCTL" "$EXIT" "$HANDOFF"
}
run deny  percentile-wrong-section-denies "$REC" "$(pctl_wrong_section)"

# --- issue-13 §3 mandatory gate-house test cases ---

# 1. Edit with replace_all:true against a multiply-occurring old_string —
# the percentile figures occur twice in the Percentile Evidence section;
# replacing both with non-percentile text must deny.
edit_payload() { # file old new replace_all
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3],"replace_all":sys.argv[4]=="true"},"cwd":sys.argv[5]}))
' "$1" "$2" "$3" "$4" "$td"
}
newtd; mkdir -p "$td/docs/issue-10/reports"
pctl_twice() { printf '## Method\n%s\n## Repro\n%s\n## Workload Characterization\n%s\n## Percentile Evidence\n%s\nAlso restated: %s\n## Bottleneck\n%s\n## Exit Criteria Verdict\n%s\n## Hand-off\n%s\n' \
  "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF"; }
printf '%s' "$(pctl_twice)" > "$td/$REC"
payload="$(edit_payload "$REC" "$PCTL" "no percentile figures here" "true")"
run_payload deny replace-all-edit-both-occurrences "$payload"

# 2. MultiEdit with a mix of replace_all true/false edits in one call.
newtd; mkdir -p "$td/docs/issue-10/reports"
printf '%s' "$(full)" > "$td/$REC"
multiedit_payload() {
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":sys.argv[1],"edits":[
  {"old_string":"## Hand-off","new_string":"## Hand-off (renamed)","replace_all":True},
  {"old_string":"hand-off: no hand-off is needed, no capacity constraint hit","new_string":"nothing here","replace_all":False}
]},"cwd":sys.argv[2]}))
' "$1" "$td"
}
payload="$(multiedit_payload "$REC")"
run_payload deny multiedit-mixed-replace-all "$payload"

# 3. Malformed JSON: truncated, non-object top level, empty payload.
newtd
run_payload deny malformed-json-truncated  '{"tool_name":"Write","tool_inp'
newtd
run_payload deny malformed-json-array      '["not","an","object"]'
newtd
run_payload deny malformed-json-empty      ''

# 4. Kill-switch set to an unrecognized value stays active; recognized on-spellings disable.
newtd; mkdir -p "$td/$(dirname "$REC")"
payload="$(write_payload "$REC" "$(without_cite)")"
run_payload deny kill-switch-garbage-stays-active "$payload" env PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=banana
newtd; mkdir -p "$td/$(dirname "$REC")"
payload="$(write_payload "$REC" "$(without_cite)")"
run_payload allow kill-switch-on-yes-disables "$payload" env PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=yes
newtd; mkdir -p "$td/$(dirname "$REC")"
payload="$(write_payload "$REC" "$(without_cite)")"
run_payload allow kill-switch-on-on-disables "$payload" env PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=on

# 5. Absolute file_path and ./-prefixed relative path match the same scope.
newtd; mkdir -p "$td/$(dirname "$REC")"
payload="$(python3 -c '
import json,sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/"+sys.argv[2],"content":sys.argv[3]},"cwd":sys.argv[1]}))
' "$td" "$REC" "$(without_cite)")"
run_payload deny absolute-path-same-scope "$payload"
newtd; mkdir -p "$td/$(dirname "$REC")"
payload="$(write_payload "./$REC" "$(without_cite)")"
run_payload deny dot-slash-prefixed-path "$payload"

# 6. A Bash-tool write reaching the same target a Write-tool call would hit.
newtd
bash_payload() {
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))
' "$1" "$td"
}
payload="$(bash_payload "cat > $REC <<EOF
some content
EOF")"
run_payload deny bash-write-undeterminable-denies "$payload"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
