#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) — performance-engineering
# intra-document section-order enforcement. Shared cross-cutting
# machinery: fires on BOTH this role's write surfaces —
# docs/issue-<n>/proposals/*.md (phase-1) and
# docs/issue-<n>/reports/performance-engineering.md (phase-2) — unlike
# proposal-gate/record-gate, which are surface-exclusive facet-presence
# checks. This gate never checks facet presence itself; it only checks
# that, when both a "workload" phrase and an "evidence" phrase are
# present in the document, the workload one comes first. Absence of
# either is not this gate's concern (that's proposal-gate/record-gate's
# job).
#
# Canonical heading vocabulary is loaded at runtime from
# hooks/heading-vocabulary.md next to this script — two "## \"<group>\"
# group" sections, each followed by "- phrase" bullet lines — so the
# phrase list stays single-sourced in that file, never duplicated here.
#
# Kill switch: export PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=1
set -uo pipefail

role="performance-engineering"
deny() { echo "${role}-order-check: refused — $1" >&2; exit 2; }

case "${PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "order-check.sh requires python3, which is not on PATH; denying rather than guessing."

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VOCAB_FILE="$SELF_DIR/heading-vocabulary.md"
[ -f "$VOCAB_FILE" ] || deny "heading-vocabulary.md not found next to order-check.sh; cannot judge section order without the canonical phrase list."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the order-check gate."

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
[ -z "$root" ] && deny "no project root could be determined; failing closed (order-check cannot run)."

OC_PAYLOAD="$payload" OC_ROOT="$root" OC_VOCAB="$VOCAB_FILE" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("performance-engineering-order-check: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("OC_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge section order on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed on the order-check gate.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["OC_ROOT"].replace("\\", "/"))
    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*\.md$')
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
    if not (PROPOSAL_RE.match(rel) or RECORD_RE.match(rel)):
        sys.exit(0)  # not this role's write surface — not this gate's business

    # --- load canonical heading vocabulary from heading-vocabulary.md ---
    vocab_path = os.environ["OC_VOCAB"]
    try:
        with open(vocab_path, encoding="utf-8-sig") as fh:
            vocab_text = fh.read()
    except OSError:
        deny("heading-vocabulary.md could not be read; failing closed.")

    groups = {}
    current = None
    heading_re = re.compile(r'^##\s*"([^"]+)"\s*group', re.IGNORECASE)
    bullet_re = re.compile(r'^-\s+(.+?)\s*$')
    for line in vocab_text.splitlines():
        m = heading_re.match(line.strip())
        if m:
            current = m.group(1).strip().lower()
            groups.setdefault(current, [])
            continue
        m = bullet_re.match(line)
        if m and current is not None:
            phrase = m.group(1).strip().lower()
            if phrase:
                groups[current].append(phrase)

    workload_phrases = groups.get("workload", [])
    evidence_phrases = groups.get("evidence", [])
    if not workload_phrases or not evidence_phrases:
        deny("heading-vocabulary.md did not yield both a \"workload\" and an \"evidence\" phrase group; failing closed rather than checking order against an incomplete vocabulary.")

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
            "Edit/MultiEdit whose old_string matches, so section order can be "
            "checked." % (rel, tool)
        )

    low = new_text.lower()

    def first_index(phrases):
        best = None
        for p in phrases:
            i = low.find(p)
            if i != -1 and (best is None or i < best):
                best = i
        return best

    w_idx = first_index(workload_phrases)
    e_idx = first_index(evidence_phrases)

    if w_idx is None or e_idx is None:
        # presence is proposal-gate's/record-gate's job, not ours.
        sys.exit(0)

    if e_idx < w_idx:
        deny(
            "%s places an evidence-class section (e.g. percentile/profiling evidence) "
            "before the workload-class section (e.g. workload characterization). Per "
            "methodology.md's implied order, workload characterization must be stated "
            "before percentile/profiling evidence within the same document." % rel
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("order-check.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?  # fail-closed-on-internal-error
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "performance-engineering-order-check: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
