#!/usr/bin/env bash
CORE_HOOKS="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks"
. "$CORE_HOOKS/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail
# PreToolUse gate (Write|Edit|MultiEdit|NotebookEdit|Bash) — performance-engineering
# intra-document section-order enforcement. Shared cross-cutting
# machinery: fires on BOTH this role's write surfaces —
# docs/issue-<n>/proposals/*.md (phase-1) and
# docs/issue-<n>/reports/performance-engineering.md (phase-2) — unlike
# proposal-gate/record-gate, which are surface-exclusive facet-presence
# checks. This gate never checks facet presence itself; it only checks
# that, when both a "workload"-group heading and an "evidence"-group
# heading are present in the document, the workload one comes first (by
# section start offset, not raw string position — a stray workload word
# inside the evidence section's own prose no longer perturbs the verdict).
# Absence of either is not this gate's concern (that's
# proposal-gate/record-gate's job).
#
# Sources core's gate-lib.sh/gate-lib.py (issue-72 gate-house standard, by
# reference) and this repo's own section_lib.py for the section-splitting
# machinery. Canonical heading vocabulary is loaded at runtime from
# hooks/heading-vocabulary.md next to this script — shared with
# proposal-gate.sh/record-gate.sh, single-sourced, never duplicated here.
#
# Kill switch: export PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF=1
# (unrecognized values stay ACTIVE — see gate_kill_switch_active).
role="performance-engineering"
gate_kill_switch_active "${PERFORMANCE_ENGINEERING_ORDER_CHECK_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "${role}-order-check" "requires python3, which is not on PATH; denying rather than guessing."

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SECTION_LIB_PY="$SELF_DIR/section_lib.py"
VOCAB_FILE="$SELF_DIR/heading-vocabulary.md"
[ -f "$SECTION_LIB_PY" ] || gate_deny "${role}-order-check" "section_lib.py not found next to order-check.sh; cannot judge section order."
[ -f "$VOCAB_FILE" ] || gate_deny "${role}-order-check" "heading-vocabulary.md not found next to order-check.sh; cannot judge section order without the canonical phrase list."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || gate_deny "${role}-order-check" "empty tool-use payload on stdin; cannot evaluate the order-check gate."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
if not isinstance(e,dict): sys.exit(0)
ti=e.get("tool_input")
if not isinstance(ti,dict): sys.exit(0)
if e.get("tool_name") in ("Write","Edit","MultiEdit","NotebookEdit"):
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
[ -z "$root" ] && gate_deny "${role}-order-check" "no project root could be determined; failing closed (order-check cannot run)."

OC_PAYLOAD="$payload" OC_ROOT="$root" SECTION_LIB_PY="$SECTION_LIB_PY" OC_VOCAB="$VOCAB_FILE" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys, importlib.util

    def deny(m):
        sys.stderr.write("performance-engineering-order-check: refused — %s\n" % m); sys.exit(2)

    _gspec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_gspec); _gspec.loader.exec_module(gate_lib)
    _sspec = importlib.util.spec_from_file_location("section_lib", os.environ["SECTION_LIB_PY"])
    section_lib = importlib.util.module_from_spec(_sspec); _sspec.loader.exec_module(section_lib)

    raw = os.environ.get("OC_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["OC_ROOT"].replace("\\", "/"))
    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*\.md$')
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/performance-engineering\.md$')

    def is_write_surface(rel):
        return bool(PROPOSAL_RE.match(rel) or RECORD_RE.match(rel))

    if tool == "Bash":
        cmd = ti.get("command", "")
        if not (isinstance(cmd, str) and cmd):
            sys.exit(0)
        hit = None
        for tok in re.findall(r'[A-Za-z0-9_./~$-]+', cmd):
            rel = gate_lib.gate_normalize_path(root, tok)
            if rel is not None and is_write_surface(rel):
                hit = rel
                break
        if hit is None:
            sys.exit(0)
        deny(
            "this Bash command appears to write to %s but the gate cannot determine "
            "the resulting content from a shell command; failing closed the same way "
            "an undeterminable Edit does. Use Write/Edit/MultiEdit so section order can "
            "be checked." % hit
        )

    if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        sys.exit(0)

    p = ti.get("file_path")
    if not (isinstance(p, str) and p):
        sys.exit(0)
    rel = gate_lib.gate_normalize_path(root, p)
    if rel is None or not is_write_surface(rel):
        sys.exit(0)  # not this role's write surface — not this gate's business

    # --- load canonical heading vocabulary, shared with proposal-gate/record-gate ---
    vocab_path = os.environ["OC_VOCAB"]
    try:
        with open(vocab_path, encoding="utf-8-sig") as fh:
            vocab_text = fh.read()
    except OSError:
        deny("heading-vocabulary.md could not be read; failing closed.")

    vocab = section_lib.load_vocab_groups(vocab_text)
    workload_group = vocab.get("workload", [])
    evidence_group = vocab.get("evidence", [])
    if not workload_group or not evidence_group:
        deny("heading-vocabulary.md did not yield both a \"workload\" and an \"evidence\" phrase group; failing closed rather than checking order against an incomplete vocabulary.")

    r = posixpath.join(root, rel)
    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r). Write the full document with Write, or use an "
            "Edit/MultiEdit whose old_string matches, so section order can be "
            "checked." % (rel, tool)
        )

    sections = section_lib.split_sections(new_text)
    w_idx = section_lib.first_group_start(sections, workload_group)
    e_idx = section_lib.first_group_start(sections, evidence_group)

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
