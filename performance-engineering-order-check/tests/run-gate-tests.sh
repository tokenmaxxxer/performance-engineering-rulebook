#!/usr/bin/env bash
# performance-engineering-order-check's own gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/order-check.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

PROP=docs/issue-10/proposals/methodology-enforcement.md
RECORD=docs/issue-10/reports/performance-engineering.md

WORKLOAD='workload characterization: 200 concurrent users, 80/20 mix, 5-minute ramp-up'
EVIDENCE='percentile evidence: p99 observed at 240ms across the canary window'

in_order() { printf '%s\n%s\n' "$WORKLOAD" "$EVIDENCE"; }
out_of_order() { printf '%s\n%s\n' "$EVIDENCE" "$WORKLOAD"; }
workload_only() { printf '%s\n' "$WORKLOAD"; }

run deny  proposal-out-of-order  "$PROP"   "$(out_of_order)"
run allow proposal-in-order      "$PROP"   "$(in_order)"
run deny  record-out-of-order    "$RECORD" "$(out_of_order)"
run allow record-in-order        "$RECORD" "$(in_order)"
run allow workload-only-no-evidence "$PROP" "$(workload_only)"
run allow foreign-path           "README.md" "x"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
