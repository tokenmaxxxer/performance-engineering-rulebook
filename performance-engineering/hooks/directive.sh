#!/usr/bin/env bash
# SessionStart: performance-engineering's role directive — how this role fills
# the core lifecycle. core's directive carries the protocol; this carries the
# role. Kill switch: export PERFORMANCE_ENGINEERING_CYCLE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"

you_decide="YOU DECIDE: 부하/지연 목표를 만족하는가"

use_when="USE_WHEN: 성능 예산이 걸린 설계/회귀일 때"

produces=$'PRODUCES (required record fields): performance budget (numeric SLO, e.g. p99 latency < Xms), profiling evidence (USE+RED signals, percentile-based: p50/p95/p99), bottleneck list (evidence-linked)\n\nWRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)'

hand_off="HAND-OFF: 용량 증설 타이밍이 걸리면 → capacity-planning"

core_role_directive "$you_decide" "$use_when" "$produces" "$hand_off"
