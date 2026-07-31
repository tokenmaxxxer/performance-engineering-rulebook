#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — performance-engineering phase-1
# proposal-norm, the 6 methodology.md (a) facets: numeric SLO, falsifiable
# hypothesis, named method+reason, workload characterization, premortem,
# evidence-citation format. Composes with (never replaces) core canon's
# generic record-fields-gate.sh.
#
# Targets: docs/issue-<n>/proposals/*.md (this role's phase-1 write
# surface). Phase-2 records are performance-engineering-record-gate's job —
# this gate never fires on docs/issue-<n>/reports/*.
#
# Kill switch: export PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=1
set -uo pipefail

role="performance-engineering"
deny() { echo "${role}-proposal-gate: refused — $1" >&2; exit 2; }

case "${PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "proposal-gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the proposal gate."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (proposal-gate cannot run)."

PG_PAYLOAD="$payload" PG_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("performance-engineering-proposal-gate: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("PG_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge proposal facets on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on the proposal gate.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*\.md$')

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
    if not PROPOSAL_RE.match(rel):
        sys.exit(0)  # not a proposal write surface — not this gate's business

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
            "Edit/MultiEdit whose old_string matches, so the 6 proposal facets can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    missing = []

    # (a)1 numeric SLO: a figure with unit + comparator, not a prose goal.
    if not re.search(r'p\d{1,2}\s*[<>=]|(latency|throughput|error\s*rate)[^.\n]{0,40}[<>=]\s*\d', low):
        missing.append("numeric SLO (a numeric threshold with unit and comparator, e.g. \"p99 < 250ms\", not a prose goal — methodology.md (a)1)")

    # (a)2 falsifiable hypothesis, grounded in telemetry.
    if not (has_any("hypothesis") and has_any("telemetry", "existing metric", "existing measurement", "observed", "profil")):
        missing.append("falsifiable hypothesis grounded in existing telemetry, not a bare guess (methodology.md (a)2)")

    # (a)3 method named + tied to this role's YOU DECIDE line.
    method_named = has_any("use method", " use ", "use+red", "red method", "golden signal", "four golden signals")
    if not (method_named and has_any("decide", "judg")):
        missing.append("method named explicitly (USE / RED / Four Golden Signals) with a sentence tying the choice to this role's YOU DECIDE line (methodology.md (a)3)")

    # (a)4 workload characterization: concurrency, mix, ramp-up.
    if not (has_any("concurren") and has_any("mix", "ratio", "transaction") and has_any("ramp")):
        missing.append("workload characterization (concurrency level, request/transaction mix, ramp-up profile — not \"under load\" alone) (methodology.md (a)4)")

    # (a)5 premortem: blast-radius, killswitch, rollback.
    if not (has_any("blast radius", "blast-radius") and has_any("killswitch", "kill switch", "kill-switch") and has_any("rollback")):
        missing.append("premortem stating blast-radius limit, killswitch mechanism, and rollback procedure (methodology.md (a)5)")

    # (a)6 evidence-citation format: source or explicit assumption label.
    if not has_any("source:", "assumption", "per ", "http://", "https://", "cited"):
        missing.append("evidence-citation format: every external claim carries a source or is labeled an assumption (methodology.md (a)6)")

    if missing:
        deny(
            "performance-engineering phase-1 proposal is missing required element(s): %s. "
            "Per docs/issue-1/proposals/methodology.md (a), every phase-1 proposal must "
            "state a numeric SLO, a falsifiable telemetry-grounded hypothesis, an explicitly "
            "named method tied to this role's decision, a full workload characterization, a "
            "premortem (blast-radius/killswitch/rollback), and source-cited or "
            "assumption-labeled evidence." % "; ".join(missing)
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("proposal-gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "performance-engineering-proposal-gate: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
