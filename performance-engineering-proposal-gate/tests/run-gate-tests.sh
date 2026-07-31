#!/usr/bin/env bash
# performance-engineering-proposal-gate's own gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/proposal-gate.sh" >/dev/null 2>&1
  rc=$?; case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  rm -rf "$td"; report "$1" "$got" "$2"
}

PROP=docs/issue-10/proposals/methodology-enforcement.md

SLO='p99 < 250ms'
HYP='hypothesis: connection pool saturates at high rps, grounded in existing telemetry'
METHOD='method: use method chosen to decide whether the load/latency judgment is satisfied'
WORKLOAD='workload characterization: 200 concurrent users, 80/20 read/write transaction mix, 5-minute ramp-up'
PREMORTEM='premortem: blast radius limited to canary pool, killswitch env flag, rollback via previous deploy'
EVIDENCE='source: https://example.com/bench'

full() { printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE"; }

run allow complete-compliant     "$PROP" "$(full)"
run deny  missing-slo            "$PROP" "$(printf '%s\n%s\n%s\n%s\n%s\n' "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE")"
run deny  missing-hypothesis     "$PROP" "$(printf '%s\n%s\n%s\n%s\n%s\n' "$SLO" "$METHOD" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE")"
run deny  missing-method         "$PROP" "$(printf '%s\n%s\n%s\n%s\n%s\n' "$SLO" "$HYP" "$WORKLOAD" "$PREMORTEM" "$EVIDENCE")"
run deny  missing-workload       "$PROP" "$(printf '%s\n%s\n%s\n%s\n%s\n' "$SLO" "$HYP" "$METHOD" "$PREMORTEM" "$EVIDENCE")"
run deny  missing-premortem      "$PROP" "$(printf '%s\n%s\n%s\n%s\n%s\n' "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$EVIDENCE")"
run deny  missing-evidence       "$PROP" "$(printf '%s\n%s\n%s\n%s\n%s\n' "$SLO" "$HYP" "$METHOD" "$WORKLOAD" "$PREMORTEM")"
run allow foreign-path           "README.md" "x"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
