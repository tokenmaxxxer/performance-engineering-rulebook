#!/usr/bin/env bash
# SessionStart: performance-engineering-session-informer.
# Non-blocking awareness: current issue/branch, existing PR/approval state,
# and whether this role's own phase-1 proposal / phase-2 record already
# exists for this issue. Informational only — never gates, never blocks.
#
# Kill switch: export PERFORMANCE_ENGINEERING_SESSION_INFORMER_OFF=1
# to disable this informer entirely (no output beyond a one-line notice).

if [ "${PERFORMANCE_ENGINEERING_SESSION_INFORMER_OFF:-}" = "1" ]; then
  echo "performance-engineering-session-informer: disabled (PERFORMANCE_ENGINEERING_SESSION_INFORMER_OFF=1)"
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$repo_root" ]; then
  echo "performance-engineering-session-informer: not inside a git repository; skipping." >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || git branch --show-current 2>/dev/null)"

echo "performance-engineering-session-informer:"
echo "  current branch: ${branch:-unknown}"

issue_num=""
if [[ "$branch" =~ ^issue-([0-9]+)/ ]]; then
  issue_num="${BASH_REMATCH[1]}"
fi

if [ -z "$issue_num" ]; then
  echo "  no issue-shaped branch detected (expected issue-<n>/...); nothing further to report."
  exit 0
fi

echo "  detected issue number: $issue_num"

# Best-effort gh lookups. Never let a gh failure (offline, unauthenticated,
# no network) block or error the session — suppress stderr and just omit
# the line on failure.
if command -v gh >/dev/null 2>&1; then
  issue_state="$(gh issue view "$issue_num" --json state -q .state 2>/dev/null || true)"
  if [ -n "$issue_state" ]; then
    echo "  issue #$issue_num state: $issue_state"
  else
    echo "  issue #$issue_num state: unavailable (offline, no gh auth, or issue not found)"
  fi

  pr_json="$(gh pr list --head "issue-${issue_num}/performance-engineering" --state all --json number,state,url 2>/dev/null || true)"
  if [ -n "$pr_json" ] && [ "$pr_json" != "[]" ]; then
    echo "  existing PR(s) for issue-${issue_num}/performance-engineering: $pr_json"
  else
    echo "  no existing PR found for issue-${issue_num}/performance-engineering (or lookup unavailable)."
  fi
else
  echo "  gh CLI not available; skipping PR/issue state lookup."
fi

proposal_glob=("$repo_root"/docs/issue-"$issue_num"/proposals/*.md)
if [ -e "${proposal_glob[0]}" ]; then
  echo "  phase-1 proposal found: docs/issue-${issue_num}/proposals/ (has .md file(s))"
else
  echo "  phase-1 proposal not found yet: docs/issue-${issue_num}/proposals/*.md"
fi

record_path="$repo_root/docs/issue-${issue_num}/reports/performance-engineering.md"
if [ -f "$record_path" ]; then
  echo "  phase-2 record found: docs/issue-${issue_num}/reports/performance-engineering.md"
else
  echo "  phase-2 record not found yet: docs/issue-${issue_num}/reports/performance-engineering.md"
fi

exit 0
