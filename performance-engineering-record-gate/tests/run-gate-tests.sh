#!/usr/bin/env bash
# performance-engineering-record-gate's own gate, exercised as a real subprocess.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
HOOKS="$HERE/../hooks"
pass=0; fail=0
report() { if [ "$2" = "$1" ]; then pass=$((pass+1)); printf 'ok     %-34s %s\n' "$3" "$2"; else fail=$((fail+1)); printf 'FAIL   %-34s want=%s got=%s\n' "$3" "$1" "$2"; fi; }

run() { # want name file content
  td="$(cd "$(mktemp -d)" && pwd -P)"; git init -q "$td"; mkdir -p "$td/$(dirname "$3")"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":%s},"cwd":"%s"}' \
    "$3" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$4")" "$td" \
    | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$HOOKS/record-gate.sh" >/dev/null 2>&1
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

full() { printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF"; }

run allow complete-compliant   "$REC" "$(full)"
run deny  missing-cite         "$REC" "$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$REPRO" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF")"
run deny  missing-repro        "$REC" "$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$CITE" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF")"
run deny  missing-workload     "$REC" "$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$CITE" "$REPRO" "$PCTL" "$BOTTLENECK" "$EXIT" "$HANDOFF")"
run deny  missing-percentile   "$REC" "$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$BOTTLENECK" "$EXIT" "$HANDOFF")"
run deny  missing-bottleneck   "$REC" "$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$EXIT" "$HANDOFF")"
run deny  missing-exit         "$REC" "$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$HANDOFF")"
run deny  missing-handoff      "$REC" "$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$CITE" "$REPRO" "$WORKLOAD" "$PCTL" "$BOTTLENECK" "$EXIT")"
run allow graceful-exit        "$REC" "$(printf '%s\n%s\n%s\ndisproven at hypothesis stage\n' "$CITE" "$REPRO" "$WORKLOAD")"
run allow foreign-path         "README.md" "x"

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
