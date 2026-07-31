#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — performance-engineering phase-2
# record-norm, the 7 methodology.md (b) elements: methodology-cite, repro
# info, workload-actual, percentile evidence, bottleneck-evidence linkage,
# exit-criteria verdict, hand-off rationale. Recognizes a small set of
# graceful-exit phrases so a legitimately early hand-off is not penalized
# for missing downstream elements. Composes with (never replaces) core
# canon's generic record-fields-gate.sh.
#
# Targets: docs/issue-<n>/reports/performance-engineering.md (this role's
# phase-2 write surface). Phase-1 proposals are
# performance-engineering-proposal-gate's job.
#
# Kill switch: export PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=1
set -uo pipefail

deny() { echo "performance-engineering-record-gate: refused — $1" >&2; exit 2; }

case "${PERFORMANCE_ENGINEERING_RECORD_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "record-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the record gate."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    v=ti.get("file_path")
    if isinstance(v,str) and v: print(v)
' 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
_under() {
  [ -z "$2" ] && return 0
  python3 -c '
import os,posixpath,sys
r,t=sys.argv[1],sys.argv[2]
try: rr=posixpath.normpath(os.path.realpath(r).replace("\\","/"))
except Exception: sys.exit(1)
n=t.replace("\\","/"); a=n if posixpath.isabs(n) else posixpath.join(rr,n)
a=posixpath.normpath(a); real=posixpath.normpath(os.path.realpath(a).replace("\\","/"))
sys.exit(0 if (real==rr or real.startswith(rr+"/")) else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (record-gate cannot run)."

PG_PAYLOAD="$payload" PG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("performance-engineering-record-gate: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge record elements on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on the record gate.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/performance-engineering\.md$')

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    if not RECORD_RE.match(rel):
        sys.exit(0)  # not this role's record write surface — not this gate's business

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list) and text is not None:
            ok = True
            for e in edits:
                if not isinstance(e, dict):
                    ok = False; break
                o, n = e.get("old_string"), e.get("new_string")
                if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                    ok = False; break
                text = text.replace(o, n, 1)
            if ok:
                new_text = text

    if new_text is None:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so the 7 record elements can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    # Graceful-exit: a legitimately early hand-off skips downstream elements.
    graceful_exit = has_any(
        "disproven at hypothesis stage",
        "routed to capacity-planning before reaching percentile evidence",
        "routed to `capacity-planning`",
        "no regression found — exit before instrumentation",
        "no regression found -- exit before instrumentation",
    )

    missing = []

    # (b)1 methodology-cite: which method applied + per-signal measured values.
    if not (has_any("use method", "red method", "golden signal") and re.search(r'\d', low)):
        missing.append("methodology-cite: which of USE/RED/Golden-Signals was actually applied, with per-signal measured values (methodology.md (b)1)")

    # (b)2 repro info: hardware/config/tool-version detail.
    if not has_any("repro", "reproduc"):
        missing.append("repro info: hardware/config/tool-version detail sufficient to reproduce the measurement (methodology.md (b)2)")

    # (b)3 workload-actual: exercised workload vs phase-1 characterization.
    if not (has_any("workload") and has_any("actual", "exercised")):
        missing.append("workload-actual: the actually-exercised workload and its match/mismatch against the phase-1 characterization (methodology.md (b)3)")

    # (b)4 percentile evidence: p50/p95/p99, not averages alone.
    if not graceful_exit and not re.search(r'p9[0-9]|p50', low):
        missing.append("percentile evidence (p50/p9x), not averages alone (methodology.md (b)4)")

    # (b)5 bottleneck-evidence linkage.
    if not graceful_exit and not (has_any("bottleneck") and has_any("evidence", "linked", "supports", "supported by")):
        missing.append("bottleneck-evidence linkage: every bottleneck named must point at the specific measurement data supporting it (methodology.md (b)5)")

    # (b)6 exit-criteria verdict: explicit pass/fail against phase-1 SLO.
    if not graceful_exit and not (has_any("pass", "fail") and has_any("slo", "exit criteria", "exit-criteria")):
        missing.append("exit-criteria verdict: explicit pass/fail against the phase-1 numeric SLO, with observed deviation (methodology.md (b)6)")

    # (b)7 hand-off rationale.
    if not graceful_exit and not (has_any("hand-off", "hand off", "handoff") and has_any("capacity-planning", "capacity planning", "no hand-off is needed", "no hand off is needed")):
        missing.append("hand-off rationale: capacity-planning basis stated explicitly, or an explicit statement that no hand-off is needed and why (methodology.md (b)7)")

    if missing:
        deny(
            "performance-engineering phase-2 record is missing required element(s): %s. "
            "Per docs/issue-1/proposals/methodology.md (b), every phase-2 record must cite "
            "the applied methodology with measured values, state repro info, state the actual "
            "workload against the phase-1 characterization, show percentile evidence, link "
            "every bottleneck to its supporting evidence, render an explicit exit-criteria "
            "verdict, and state its hand-off rationale — unless a recognized graceful-exit "
            "phrase legitimately skips the downstream elements." % "; ".join(missing)
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("record-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "performance-engineering-record-gate: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
