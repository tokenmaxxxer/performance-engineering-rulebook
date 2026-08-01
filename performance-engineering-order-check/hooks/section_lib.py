# Sourceable Python helper, private to this repo (not core canon — gate-lib
# does not attempt document-semantics checks; this is role-specific
# judgment logic). Loaded the same importlib way as gate-lib.py by all
# three gates' Python payloads:
#
#   import importlib.util, os
#   _spec = importlib.util.spec_from_file_location("section_lib", os.environ["SECTION_LIB_PY"])
#   section_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(section_lib)
#
# Gives proposal-gate.sh/record-gate.sh/order-check.sh a shared way to
# scope a facet check to the section whose heading matches a
# heading-vocabulary.md group, instead of a whole-document substring
# search (issue-13's cited false-pass: a decoy word anywhere in the
# document, or a correct figure placed under the wrong heading, both used
# to pass).

import re

_HEADING_RE = re.compile(r'^(#{2,3})[ \t]+(.+?)[ \t]*$', re.MULTILINE)


def split_sections(text):
    """Split a markdown document on ATX headings (## or ###) into an
    ordered list of (heading_text, heading_lower, start_offset, body)
    tuples.

    `start_offset` is the character offset of the heading line itself
    (used for order-check.sh's section-start-offset comparison, not raw
    string position). `body` runs from the end of the heading line to the
    start of the next heading of any level (## or ###), or end of
    document — so a "###" subsection's text is not double-counted in its
    parent "##" section's body.
    """
    matches = list(_HEADING_RE.finditer(text))
    sections = []
    for i, m in enumerate(matches):
        heading_text = m.group(2).strip()
        body_start = m.end()
        body_end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[body_start:body_end]
        sections.append((heading_text, heading_text.lower(), m.start(), body))
    return sections


def sections_matching_group(sections, group_phrases):
    """Return the subset of split_sections() output whose heading_lower
    contains any phrase in group_phrases (already-lowercased list)."""
    return [s for s in sections if any(p in s[1] for p in group_phrases)]


def section_has_any(sections, group_phrases, *needles):
    """True if any section whose heading matches group_phrases has a body
    containing any of needles (case-insensitive substring)."""
    for _, _, _, body in sections_matching_group(sections, group_phrases):
        low = body.lower()
        if any(nd in low for nd in needles):
            return True
    return False


def section_search(sections, group_phrases, pattern):
    """True if any section whose heading matches group_phrases has a body
    matching the compiled regex `pattern` (re.search)."""
    for _, _, _, body in sections_matching_group(sections, group_phrases):
        if pattern.search(body.lower()):
            return True
    return False


# issue-16-confirmed: two facet needles used with section_has_any's bare
# substring test are satisfied by their own negations/unrelated English
# usage ("uncited"/"not cited" contain "cited"; "use methodology X"
# contains "use method"). Word-boundary + negation-aware checks below are
# used only for these two vulnerable needles — the other needles
# ("assumption", "blast radius", "rollback", etc.) are not substrings of
# their own negations or of unrelated common phrases the same way, so they
# stay on section_has_any.

_CITED_RE = re.compile(r'\bcited\b')
_CITED_NEGATION_RE = re.compile(r"\b(not|never)\b|n't\b")
_CITED_NEGATION_WINDOW = 20


def section_has_cited(sections, group_phrases):
    """True if any section whose heading matches group_phrases has a body
    containing a non-negated, word-boundary "cited" (case-insensitive).
    "uncited" never matches (no word boundary before "cited"); "not
    cited"/"isn't cited"/"never cited" are excluded by a negation-token
    scan of the text immediately preceding the match."""
    for _, _, _, body in sections_matching_group(sections, group_phrases):
        low = body.lower()
        for m in _CITED_RE.finditer(low):
            window = low[max(0, m.start() - _CITED_NEGATION_WINDOW):m.start()]
            if _CITED_NEGATION_RE.search(window):
                continue
            return True
    return False


_USE_METHOD_RE = re.compile(r'\bUSE\b')


def section_has_method_use(sections, group_phrases):
    """True if any section whose heading matches group_phrases has a body
    containing the literal acronym "USE" as a standalone word, checked
    against the ORIGINAL-case body (not lower-cased) so "use methodology
    X" no longer satisfies the facet while "USE Method"/"the USE method"
    still do."""
    for _, _, _, body in sections_matching_group(sections, group_phrases):
        if _USE_METHOD_RE.search(body):
            return True
    return False


def load_vocab_groups(vocab_text):
    """Parse heading-vocabulary.md's '## "<group>" group' / '- phrase'
    bullet-list format into {group_name_lower: [phrase_lower, ...]}. Single
    parser shared by all three gates so the file format never drifts
    between them."""
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
    return groups


def first_group_start(sections, group_phrases):
    """Earliest start_offset among sections whose heading matches
    group_phrases, or None if no such section exists."""
    matched = sections_matching_group(sections, group_phrases)
    if not matched:
        return None
    return min(s[2] for s in matched)
