#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit): content-level gate for this role's
# phase-2 record — role-unique, not core canon (core's record-fields-gate.sh
# checks field *presence* only; this checks that the methodology content
# proposed in docs/issue-1/proposals/methodology.md is actually present).
# Fires only on this role's own record file: docs/issue-<n>/reports/performance-engineering.md
set -uo pipefail

record_path_pattern='docs/issue-[0-9]+/reports/performance-engineering\.md$'

input="$(cat)"
file_path="$(printf '%s' "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')"

[ -n "$file_path" ] || exit 0
printf '%s' "$file_path" | grep -qE "$record_path_pattern" || exit 0

content="$(printf '%s' "$input" | grep -o '"content"[[:space:]]*:[[:space:]]*"[^"]*"\|"new_string"[[:space:]]*:[[:space:]]*"[^"]*"')"
[ -n "$content" ] || content="$input"

if ! printf '%s' "$content" | grep -qiE 'p9[0-9]|p50'; then
  echo "methodology-gate: blocked — performance-engineering record must cite percentile evidence (p50/p9x), not averages (docs/issue-1/proposals/methodology.md (b)4)" >&2
  exit 2
fi

if ! printf '%s' "$content" | grep -qiE '\bUSE\b|\bRED\b'; then
  echo "methodology-gate: blocked — performance-engineering record must name the applied methodology (USE/RED) (docs/issue-1/proposals/methodology.md (b)1)" >&2
  exit 2
fi

exit 0
