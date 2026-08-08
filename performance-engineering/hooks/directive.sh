#!/usr/bin/env bash
# SessionStart: performance-engineering's role identity + hand-off only.
# Per-facet phase-1/phase-2 enforcement text lives in the
# performance-engineering-proposal-gate / performance-engineering-record-gate
# plugins, not here — this plugin is identity/orientation only, per the
# issue-10 plugin-set restructure. Kill switch: export PERFORMANCE_ENGINEERING_CYCLE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"

you_decide="YOU DECIDE: 부하/지연 목표를 만족하는가"

use_when="USE_WHEN: 성능 예산이 걸린 설계/회귀일 때"

produces=$'PRODUCES: see performance-engineering-proposal-gate (phase-1 norm) and\nperformance-engineering-record-gate (phase-2 norm) for the enforced\nfield/facet lists; performance-engineering-checklist for the human-facing\nauthoring checklist. Phase-2 records also carry the\nroles/specs/performance-engineering.spec.json required fields: sli,\nslo_target, error_budget_remaining, verdict.\n\nLOOP_STATE: landed | measuring | metric-unreachable | reviewing | slo-undeclared (record frontmatter, closed set)\n\nWRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)'

hand_off="HAND-OFF: 용량 증설 타이밍이 걸리면 → capacity-planning"

core_role_directive "$you_decide" "$use_when" "$produces" "$hand_off"
