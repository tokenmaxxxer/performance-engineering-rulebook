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
