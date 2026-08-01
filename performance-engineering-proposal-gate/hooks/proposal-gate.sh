#!/usr/bin/env bash
CORE_HOOKS="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks"
. "$CORE_HOOKS/lib/gate-lib.sh" || { echo "proposal-gate.sh: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail
# PreToolUse gate (Write|Edit|MultiEdit|NotebookEdit|Bash) — performance-engineering
# phase-1 proposal-norm, the 6 methodology.md (a) facets: numeric SLO,
# falsifiable hypothesis, named method+reason, workload characterization,
# premortem, evidence-citation format. Composes with (never replaces) core
# canon's generic record-fields-gate.sh.
#
# Sources core's gate-lib.sh/gate-lib.py (issue-72 gate-house standard, by
# reference — see docs/handbooks/gate-house-standard.md) for the fail-closed
# trap, kill-switch, path-normalize, and Write/Edit/MultiEdit/NotebookEdit
# reconstruction; and this repo's own section_lib.py (private, role-specific
# document-semantics helper, not house infrastructure) for section-scoped
# facet checks against heading-vocabulary.md's shared phrase groups.
#
# Targets: docs/issue-<n>/proposals/*.md (this role's phase-1 write
# surface). Phase-2 records are performance-engineering-record-gate's job —
# this gate never fires on docs/issue-<n>/reports/*.
#
# Kill switch: export PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF=1
# (unrecognized values stay ACTIVE — see gate_kill_switch_active).
role="performance-engineering"
gate_kill_switch_active "${PERFORMANCE_ENGINEERING_PROPOSAL_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || gate_deny "${role}-proposal-gate" "requires python3, which is not on PATH; denying rather than guessing."

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SECTION_LIB_PY="$SELF_DIR/../../performance-engineering-order-check/hooks/section_lib.py"
VOCAB_FILE="$SELF_DIR/../../performance-engineering-order-check/hooks/heading-vocabulary.md"
[ -f "$SECTION_LIB_PY" ] || gate_deny "${role}-proposal-gate" "section_lib.py not found next to order-check.sh; cannot judge section-scoped facets."
[ -f "$VOCAB_FILE" ] || gate_deny "${role}-proposal-gate" "heading-vocabulary.md not found; cannot judge section-scoped facets without the canonical phrase list."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || gate_deny "${role}-proposal-gate" "empty tool-use payload on stdin; cannot evaluate the proposal gate."

# Root-resolution hint: only Write/Edit/MultiEdit/NotebookEdit carry a
# single file_path we can use to guess CLAUDE_PROJECT_DIR plausibility up
# front; a Bash tool_input.command is not one path, so it is left as "" and
# _under's `[ -z "$2" ] && return 0` short-circuits to "plausible" — the
# python judge below still applies the real path pattern to every
# candidate token extracted from the command.
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
[ -z "$root" ] && gate_deny "${role}-proposal-gate" "no project root could be determined; failing closed (proposal-gate cannot run)."

PG_PAYLOAD="$payload" PG_ROOT="$root" SECTION_LIB_PY="$SECTION_LIB_PY" VOCAB_FILE="$VOCAB_FILE" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys, importlib.util

    def deny(m):
        sys.stderr.write("performance-engineering-proposal-gate: refused — %s\n" % m); sys.exit(2)

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
    PROPOSAL_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*\.md$')

    if tool == "Bash":
        cmd = ti.get("command", "")
        if not (isinstance(cmd, str) and cmd):
            sys.exit(0)
        hit = None
        for tok in gate_lib.gate_bash_write_targets(cmd):
            rel = gate_lib.gate_normalize_path(root, tok)
            if rel is not None and PROPOSAL_RE.match(rel):
                hit = rel
                break
        if hit is None:
            sys.exit(0)
        deny(
            "this Bash command appears to write to %s but the gate cannot determine "
            "the resulting content from a shell command; failing closed the same way "
            "an undeterminable Edit does. Use Write/Edit/MultiEdit so the 6 proposal "
            "facets can be checked." % hit
        )

    if tool not in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
        sys.exit(0)

    p = ti.get("file_path")
    if not (isinstance(p, str) and p):
        sys.exit(0)
    rel = gate_lib.gate_normalize_path(root, p)
    if rel is None or not PROPOSAL_RE.match(rel):
        sys.exit(0)  # not a proposal write surface — not this gate's business

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
            "Edit/MultiEdit whose old_string matches, so the 6 proposal facets can be "
            "checked." % (rel, tool)
        )

    with open(os.environ["VOCAB_FILE"], encoding="utf-8-sig") as fh:
        vocab = section_lib.load_vocab_groups(fh.read())

    sections = section_lib.split_sections(new_text)

    missing = []

    # (a)1 numeric SLO: a figure with unit + comparator, scoped to the slo section.
    slo_re = re.compile(r'(p\d{1,2}|latency|throughput|error\s*rate)[^.\n]{0,40}[<>=]\s*\d+(\.\d+)?\s*(ms|s|%|/s|rps)')
    if not section_lib.section_search(sections, vocab.get("slo", []), slo_re):
        missing.append("numeric SLO (a numeric threshold with unit and comparator, e.g. \"p99 < 250ms\", not a prose goal, stated inside the SLO section — methodology.md (a)1)")

    # (a)2 falsifiable hypothesis, grounded in telemetry, scoped to the hypothesis section.
    hyp_group = vocab.get("hypothesis", [])
    if not (section_lib.section_has_any(sections, hyp_group, "hypothesis")
            and section_lib.section_has_any(sections, hyp_group, "telemetry", "existing metric", "existing measurement", "observed", "profil")):
        missing.append("falsifiable hypothesis grounded in existing telemetry, not a bare guess, stated inside the Hypothesis section (methodology.md (a)2)")

    # (a)3 method named + tied to this role's YOU DECIDE line, scoped to the method
    # section, same-section co-occurrence only (no bare " use " substring).
    method_group = vocab.get("method", [])
    method_named = (section_lib.section_has_method_use(sections, method_group)
                     or section_lib.section_has_any(sections, method_group, "use+red", "red method", "golden signal", "four golden signals"))
    method_decided = section_lib.section_has_any(sections, method_group, "decide", "judg")
    if not (method_named and method_decided):
        missing.append("method named explicitly (USE / RED / Four Golden Signals) with a sentence tying the choice to this role's YOU DECIDE line, both inside the Method section (methodology.md (a)3)")

    # (a)4 workload characterization: concurrency, mix, ramp-up, scoped to the workload section.
    workload_group = vocab.get("workload", [])
    if not (section_lib.section_has_any(sections, workload_group, "concurren")
            and section_lib.section_has_any(sections, workload_group, "mix", "ratio", "transaction")
            and section_lib.section_has_any(sections, workload_group, "ramp")):
        missing.append("workload characterization (concurrency level, request/transaction mix, ramp-up profile — not \"under load\" alone), inside the Workload section (methodology.md (a)4)")

    # (a)5 premortem: blast-radius, killswitch, rollback, scoped to the premortem section.
    premortem_group = vocab.get("premortem", [])
    if not (section_lib.section_has_any(sections, premortem_group, "blast radius", "blast-radius")
            and section_lib.section_has_any(sections, premortem_group, "killswitch", "kill switch", "kill-switch")
            and section_lib.section_has_any(sections, premortem_group, "rollback")):
        missing.append("premortem stating blast-radius limit, killswitch mechanism, and rollback procedure, inside the Premortem section (methodology.md (a)5)")

    # (a)6 evidence-citation format: source or explicit assumption label, scoped to the citation section.
    citation_group = vocab.get("citation", [])
    if not (section_lib.section_has_any(sections, citation_group, "source:", "assumption", "per ", "http://", "https://")
            or section_lib.section_has_cited(sections, citation_group)):
        missing.append("evidence-citation format: every external claim carries a source or is labeled an assumption, inside the citation/evidence section (methodology.md (a)6)")

    if missing:
        deny(
            "performance-engineering phase-1 proposal is missing required element(s): %s. "
            "Per docs/issue-1/proposals/methodology.md (a), every phase-1 proposal must "
            "state a numeric SLO, a falsifiable telemetry-grounded hypothesis, an explicitly "
            "named method tied to this role's decision, a full workload characterization, a "
            "premortem (blast-radius/killswitch/rollback), and source-cited or "
            "assumption-labeled evidence — each inside the section whose heading matches "
            "that facet's canonical group (heading-vocabulary.md)." % "; ".join(missing)
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
