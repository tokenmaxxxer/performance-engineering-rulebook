# performance-engineering-session-informer

A lightweight `SessionStart` companion for the performance-engineering role.
It orients a session at start-up by reporting which issue/branch it is on,
what PR/approval state already exists for that issue, and whether this
role's own phase-1 proposal or phase-2 record file has already been
authored — closing the gap that `performance-engineering/hooks/directive.sh`
leaves (it prints only static identity/hand-off text with no session-resume
awareness).

## What it reports

- Current branch name and, if it matches `issue-<n>/...`, the extracted
  issue number.
- Best-effort `gh issue view <n>` state and `gh pr list` (number/state/url)
  for this issue+role's branch.
- Whether `docs/issue-<n>/proposals/*.md` exists (phase-1 proposal).
- Whether `docs/issue-<n>/reports/performance-engineering.md` exists
  (phase-2 record).

## Advisory only

This hook is **informational only**. It never blocks, denies, or exits
non-zero for a missing PR, missing issue, or missing proposal/record file —
those are reported as plain "not found yet" notices. It only exits non-zero
if something is actually broken (e.g. not run inside a git repository), and
even then it stays minimal since a SessionStart hook must never block a
session.

## Kill switch

Set `PERFORMANCE_ENGINEERING_SESSION_INFORMER_OFF=1` to disable the
informer entirely; the script exits immediately with no output beyond a
one-line disabled notice.

## Network dependence

The `gh issue`/`gh pr` lookups are best-effort. If `gh` is unavailable, not
authenticated, or the network is unreachable, those lines are simply
omitted — the script never errors out or blocks session start because of
it.
