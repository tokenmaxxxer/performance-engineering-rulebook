#!/usr/bin/env bash
CORE_HOOKS="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks"
. "$CORE_HOOKS/lib/gate-lib.sh" || { echo "record-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
# PreToolUse gate (Write|Edit|MultiEdit|NotebookEdit|Bash) — performance-engineering
# phase-2 record-norm, the 7 methodology.md (b) elements: methodology-cite,
# repro info, workload-actual, percentile evidence, bottleneck-evidence
# linkage, exit-criteria verdict, hand-off rationale. Recognizes a small
# set of graceful-exit phrases so a legitimately early hand-off is not
# penalized for missing downstream elements. Composes with (never
# replaces) core canon's generic record-fields-gate.sh.
#
# Sources core's gate-lib.sh/gate-lib.py (issue-72 gate-house standard, by
# reference) and this repo's own section_lib.py for section-scoped facet
# checks against heading-vocabulary.md's shared phrase groups.
#
# Targets: docs/issue-<n>/reports/performance-engineering.md (this role's
# phase-2 write surface). Phase-1 proposals are
# performance-engineering-proposal-gate's job.
#
# Kill switch: export PERFORMANCE_ENGINEERING_RECORD_GATE_OFF=1
# (unrecognized values stay ACTIVE — see gate_kill_switch_active).
role="performance-engineering"
gate_kill_switch_active "${PERFORMANCE_ENGINEERING_RECORD_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "${role}-record-gate" "requires python3, which is not on PATH; denying rather than guessing."

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SECTION_LIB_PY="$SELF_DIR/../../performance-engineering-order-check/hooks/section_lib.py"
VOCAB_FILE="$SELF_DIR/../../performance-engineering-order-check/hooks/heading-vocabulary.md"
[ -f "$SECTION_LIB_PY" ] || gate_deny "${role}-record-gate" "section_lib.py not found next to order-check.sh; cannot judge section-scoped facets."
[ -f "$VOCAB_FILE" ] || gate_deny "${role}-record-gate" "heading-vocabulary.md not found; cannot judge section-scoped facets without the canonical phrase list."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || gate_deny "${role}-record-gate" "empty tool-use payload on stdin; cannot evaluate the record gate."

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
[ -z "$root" ] && gate_deny "${role}-record-gate" "no project root could be determined; failing closed (record-gate cannot run)."

PG_PAYLOAD="$payload" PG_ROOT="$root" SECTION_LIB_PY="$SECTION_LIB_PY" VOCAB_FILE="$VOCAB_FILE" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys, importlib.util

    def deny(m):
        sys.stderr.write("performance-engineering-record-gate: refused — %s\n" % m); sys.exit(2)

    _gspec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_gspec); _gspec.loader.exec_module(gate_lib)
    _sspec = importlib.util.spec_from_file_location("section_lib", os.environ["SECTION_LIB_PY"])
    section_lib = importlib.util.module_from_spec(_sspec); _sspec.loader.exec_module(section_lib)

    raw = os.environ.get("PG_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["PG_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/performance-engineering\.md$')

    if tool == "Bash":
        cmd = ti.get("command", "")
        if not (isinstance(cmd, str) and cmd):
            sys.exit(0)
        hit = None
        for tok in gate_lib.gate_bash_write_targets(cmd):
            rel = gate_lib.gate_normalize_path(root, tok)
            if rel is not None and RECORD_RE.match(rel):
                hit = rel
                break
        if hit is None:
            sys.exit(0)
        deny(
            "this Bash command appears to write to %s but the gate cannot determine "
            "the resulting content from a shell command; failing closed the same way "
            "an undeterminable Edit does. Use Write/Edit/MultiEdit so the 7 record "
            "elements can be checked." % hit
        )

    if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        sys.exit(0)

    p = ti.get("file_path")
    if not (isinstance(p, str) and p):
        sys.exit(0)
    rel = gate_lib.gate_normalize_path(root, p)
    if rel is None or not RECORD_RE.match(rel):
        sys.exit(0)  # not this role's record write surface — not this gate's business

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
            "Edit/MultiEdit whose old_string matches, so the 7 record elements can be "
            "checked." % (rel, tool)
        )

    with open(os.environ["VOCAB_FILE"], encoding="utf-8-sig") as fh:
        vocab = section_lib.load_vocab_groups(fh.read())

    sections = section_lib.split_sections(new_text)
    low = new_text.lower()

    def has_any(*needles):
        return any(nd in low for nd in needles)

    # Graceful-exit: a legitimately early hand-off skips downstream elements.
    # Whole-document check on purpose — a document-level early-exit signal,
    # not a per-facet claim, so section-scoping it would be a regression.
    graceful_exit = has_any(
        "disproven at hypothesis stage",
        "routed to capacity-planning before reaching percentile evidence",
        "routed to `capacity-planning`",
        "no regression found — exit before instrumentation",
        "no regression found -- exit before instrumentation",
    )

    missing = []

    # (b)1 methodology-cite: which method applied + per-signal measured values,
    # scoped to the method section (shared group with proposal-gate).
    method_group = vocab.get("method", [])
    cite_re = re.compile(r'\d')
    if not ((section_lib.section_has_method_use(sections, method_group)
             or section_lib.section_has_any(sections, method_group, "red method", "golden signal"))
            and section_lib.section_search(sections, method_group, cite_re)):
        missing.append("methodology-cite: which of USE/RED/Golden-Signals was actually applied, with per-signal measured values, inside the Method section (methodology.md (b)1)")

    # (b)2 repro info: hardware/config/tool-version detail, scoped to the repro section.
    repro_group = vocab.get("repro", [])
    if not section_lib.section_has_any(sections, repro_group, "repro", "reproduc"):
        missing.append("repro info: hardware/config/tool-version detail sufficient to reproduce the measurement, inside the Repro section (methodology.md (b)2)")

    # (b)3 workload-actual: exercised workload vs phase-1 characterization,
    # scoped to the workload section.
    workload_group = vocab.get("workload", [])
    if not (section_lib.section_has_any(sections, workload_group, "workload")
            and section_lib.section_has_any(sections, workload_group, "actual", "exercised")):
        missing.append("workload-actual: the actually-exercised workload and its match/mismatch against the phase-1 characterization, inside the Workload section (methodology.md (b)3)")

    # (b)4 percentile evidence: p50/p95/p99, not averages alone, scoped to the evidence section.
    evidence_group = vocab.get("evidence", [])
    pctl_re = re.compile(r'p9[0-9]|p50')
    if not graceful_exit and not section_lib.section_search(sections, evidence_group, pctl_re):
        missing.append("percentile evidence (p50/p9x), not averages alone, inside the Evidence section (methodology.md (b)4)")

    # (b)5 bottleneck-evidence linkage, scoped to the bottleneck section.
    bottleneck_group = vocab.get("bottleneck", [])
    if not graceful_exit and not (section_lib.section_has_any(sections, bottleneck_group, "bottleneck")
                                    and section_lib.section_has_any(sections, bottleneck_group, "evidence", "linked", "supports", "supported by")):
        missing.append("bottleneck-evidence linkage: every bottleneck named must point at the specific measurement data supporting it, inside the Bottleneck section (methodology.md (b)5)")

    # (b)6 exit-criteria verdict: explicit pass/fail against phase-1 SLO,
    # scoped to the exit-criteria section.
    exit_group = vocab.get("exit-criteria", [])
    if not graceful_exit and not (section_lib.section_has_any(sections, exit_group, "pass", "fail")
                                    and section_lib.section_has_any(sections, exit_group, "slo", "exit criteria", "exit-criteria")):
        missing.append("exit-criteria verdict: explicit pass/fail against the phase-1 numeric SLO, with observed deviation, inside the Exit-Criteria section (methodology.md (b)6)")

    # (b)7 hand-off rationale, scoped to the handoff section.
    handoff_group = vocab.get("handoff", [])
    if not graceful_exit and not (section_lib.section_has_any(sections, handoff_group, "hand-off", "hand off", "handoff")
                                    and section_lib.section_has_any(sections, handoff_group, "capacity-planning", "capacity planning", "no hand-off is needed", "no hand off is needed")):
        missing.append("hand-off rationale: capacity-planning basis stated explicitly, or an explicit statement that no hand-off is needed and why, inside the Hand-off section (methodology.md (b)7)")

    if missing:
        deny(
            "performance-engineering phase-2 record is missing required element(s): %s. "
            "Per docs/issue-1/proposals/methodology.md (b), every phase-2 record must cite "
            "the applied methodology with measured values, state repro info, state the actual "
            "workload against the phase-1 characterization, show percentile evidence, link "
            "every bottleneck to its supporting evidence, render an explicit exit-criteria "
            "verdict, and state its hand-off rationale — each inside the section whose "
            "heading matches that facet's canonical group (heading-vocabulary.md) — unless a "
            "recognized graceful-exit phrase legitimately skips the downstream elements." % "; ".join(missing)
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
