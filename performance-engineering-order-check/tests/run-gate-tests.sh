#!/usr/bin/env bash
# performance-engineering-order-check's own gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
export CLAUDE_PLUGIN_ROOT_CORE="${CLAUDE_PLUGIN_ROOT_CORE:-/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core}"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

newtd() { td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; }

run_payload() { # want name payload [extra_env...] — caller must call newtd first
  want="$1"; name="$2"; payload="$3"; shift 3
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" "$@" /bin/bash "$HOOKS/order-check.sh" 2>&1 >/dev/null)"
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
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/order-check.sh" 2>&1 >/dev/null)"
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

PROP=docs/issue-10/proposals/methodology-enforcement.md
RECORD=docs/issue-10/reports/performance-engineering.md

WORKLOAD_H='## Workload Characterization'
EVIDENCE_H='## Percentile Evidence'
WORKLOAD='workload characterization: 200 concurrent users, 80/20 mix, 5-minute ramp-up'
EVIDENCE='percentile evidence: p99 observed at 240ms across the canary window'

in_order()     { printf '%s\n%s\n%s\n%s\n' "$WORKLOAD_H" "$WORKLOAD" "$EVIDENCE_H" "$EVIDENCE"; }
out_of_order() { printf '%s\n%s\n%s\n%s\n' "$EVIDENCE_H" "$EVIDENCE" "$WORKLOAD_H" "$WORKLOAD"; }
workload_only() { printf '%s\n%s\n' "$WORKLOAD_H" "$WORKLOAD"; }

run deny  proposal-out-of-order  "$PROP"   "$(out_of_order)"
run allow proposal-in-order      "$PROP"   "$(in_order)"
run deny  record-out-of-order    "$RECORD" "$(out_of_order)"
run allow record-in-order        "$RECORD" "$(in_order)"
run allow workload-only-no-evidence "$PROP" "$(workload_only)"
run allow foreign-path           "README.md" "x"

# --- issue-13 §2.3 section-scoped adjacency case ---

# The real section order is correct (Workload heading, then Evidence
# heading), but the downstream Evidence section's own prose casually
# reuses the word "workload" before its own facet line — must still pass:
# only the heading (not body prose) decides where a group's section
# starts, so this in-body decoy cannot perturb the verdict the way a
# whole-document raw-string search would have.
run allow workload-word-inside-evidence-prose "$PROP" "$(printf '%s\n%s\n%s\nthis evidence section briefly reuses the word workload in prose\n%s\n' \
  "$WORKLOAD_H" "$WORKLOAD" "$EVIDENCE_H" "$EVIDENCE")"

# --- issue-13 §3 mandatory gate-house test cases ---

# 1. Edit with replace_all:true against a multiply-occurring old_string —
# two real "## Workload Characterization" headings, one before and one
# after the Evidence heading. Renaming BOTH to a non-matching heading must
# remove the workload group entirely (allow — presence is not this gate's
# business). The prior first-occurrence-only bug would rename only the
# first heading, leaving the second (positioned after Evidence) intact and
# incorrectly denying as out-of-order.
edit_payload() { # file old new replace_all
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3],"replace_all":sys.argv[4]=="true"},"cwd":sys.argv[5]}))
' "$1" "$2" "$3" "$4" "$td"
}
newtd; mkdir -p "$td/docs/issue-10/proposals"
sandwich_doc() { printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$WORKLOAD_H" "$WORKLOAD" "$EVIDENCE_H" "$EVIDENCE" "$WORKLOAD_H" "$WORKLOAD"; }
printf '%s' "$(sandwich_doc)" > "$td/$PROP"
payload="$(edit_payload "$PROP" "$WORKLOAD_H" "## Notes" "true")"
run_payload allow replace-all-edit-both-occurrences "$payload"

# 2. MultiEdit with a mix of replace_all true/false edits in one call.
newtd; mkdir -p "$td/docs/issue-10/proposals"
printf '%s' "$(out_of_order)" > "$td/$PROP"
multiedit_payload() {
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":sys.argv[1],"edits":[
  {"old_string":"## Percentile Evidence","new_string":"## Percentile Evidence (canary)","replace_all":True},
  {"old_string":"workload characterization: 200 concurrent users, 80/20 mix, 5-minute ramp-up",
   "new_string":"workload characterization: 400 concurrent users, 80/20 mix, 5-minute ramp-up","replace_all":False}
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
payload="$(write_payload "$PROP" "$(out_of_order)")"
run_payload deny kill-switch-garbage-stays-active "$payload" env PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=banana
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(write_payload "$PROP" "$(out_of_order)")"
run_payload allow kill-switch-on-1-disables "$payload" env PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=1
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(write_payload "$PROP" "$(out_of_order)")"
run_payload deny kill-switch-off-string-stays-active "$payload" env PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=off

# 5. Absolute file_path and ./-prefixed relative path match the same scope.
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(python3 -c '
import json,sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]+"/"+sys.argv[2],"content":sys.argv[3]},"cwd":sys.argv[1]}))
' "$td" "$PROP" "$(out_of_order)")"
run_payload deny absolute-path-same-scope "$payload"
newtd; mkdir -p "$td/$(dirname "$PROP")"
payload="$(write_payload "./$PROP" "$(out_of_order)")"
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

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
