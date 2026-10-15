#!/usr/bin/env python3
"""Herald linter: a nudge after a markdown write, and a command for the rewrite skill.

Hook mode (no --file): reads one JSON event on stdin, finds the markdown files
the tool wrote, lints each, and prints one JSON object with additionalContext
when there are hits. Prints nothing otherwise. Exits 0 always. Never blocks.

Command mode: herald-lint.py --file PATH [--tier auto|document|universal]
prints the same report to stdout, with the tier line even at 0 hits.

Standard library only. Every word list, glob, and limit comes from rules.json.
"""
import fnmatch
import json
import os
import pathlib
import re
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
RULES = json.loads((HERE / "rules.json").read_text(encoding="utf-8"))
LIMITS = RULES["limits"]


# --- text shaping ---------------------------------------------------------

def _blank(match):
    """The matched span as spaces, newlines kept, so line numbers survive."""
    return re.sub(r"[^\n]", " ", match.group(0))


def _code_word(match):
    """One placeholder word for an inline code span, same length as the span."""
    span = match.group(0)
    return ("CODE" + " " * len(span))[: len(span)]


def prose_only(text):
    """The text with frontmatter, fenced code, inline code, tables, and link targets blanked."""
    text = text.replace("\r\n", "\n").replace("’", "'")
    text = re.sub(r"\A---\n.*?\n---\n", _blank, text, flags=re.S)
    text = re.sub(r"^[ \t]*(`{3,}|~{3,})[^\n]*\n.*?^[ \t]*\1[^\n]*", _blank, text, flags=re.S | re.M)
    text = re.sub(r"`[^`\n]+`", _code_word, text)
    text = re.sub(r"^[ \t]*\|.*$", _blank, text, flags=re.M)
    text = re.sub(r"\]\([a-zA-Z][a-zA-Z0-9+.-]*:[^)\n]*\)", _blank, text)
    text = re.sub(r"https?://[^\s<>()]+?(?=[.,;:!?)\]]*(?:\s|$))", _blank, text)
    return text


def paragraphs(text):
    """(first line number, lines) for each block of non-blank lines."""
    out, start, lines = [], None, []
    for number, line in enumerate(text.split("\n"), 1):
        if line.strip():
            if start is None:
                start = number
            lines.append(line)
        elif start is not None:
            out.append((start, lines))
            start, lines = None, []
    if start is not None:
        out.append((start, lines))
    return out


LIST_ITEM = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
NUMBERED_ITEM = re.compile(r"^\s*\d+[.)]\s+")
SENTENCE_END = re.compile(r"(?<=[.!?])[\"')\]]*\s+")


def units(text):
    """(first line number, inside a numbered item, text) for each paragraph or list item."""
    out = []
    for start, lines in paragraphs(text):
        unit_start, unit, numbered = start, [], False
        for offset, line in enumerate(lines):
            if LIST_ITEM.match(line):
                if unit:
                    out.append((unit_start, numbered, "\n".join(unit)))
                unit_start = start + offset
                numbered = bool(NUMBERED_ITEM.match(line))
                unit = [LIST_ITEM.sub("", line, count=1)]
            else:
                unit.append(line)
        if unit:
            out.append((unit_start, numbered, "\n".join(unit)))
    return out


def sentences(text):
    """(line number, inside a numbered item, sentence) for every sentence of two or more words."""
    out = []
    for start, numbered, unit in units(text):
        prev = 0
        for end in [m.end() for m in SENTENCE_END.finditer(unit)] + [len(unit)]:
            piece = unit[prev:end].strip()
            if len(piece.split()) >= 2:
                out.append((start + unit.count("\n", 0, prev), numbered, piece))
            prev = end
    return out


def line_text(prose, offset):
    """The whole line that holds the offset, trimmed."""
    begin = prose.rfind("\n", 0, offset) + 1
    stop = prose.find("\n", offset)
    return prose[begin: stop if stop != -1 else len(prose)].strip()


def hit(prose, offset, category, text):
    return {"line": prose.count("\n", 0, offset) + 1, "category": category, "text": text.strip()[:80]}


# --- universal checks ------------------------------------------------------

SLOP = re.compile(r"\b(" + "|".join(re.escape(w).replace(r"\ ", r"\s+") for w in sorted(RULES["slop"], key=len, reverse=True)) + r")\w*", re.I)
DASH = re.compile(r"—|(?<=\S) -- (?=\S)")
OPENER = re.compile(r"^\s*(?:" + "|".join(re.escape(o) for o in RULES["openers"]) + r")", re.I)
CLOSERS = re.compile("|".join(re.escape(c) for c in RULES["closers"]), re.I)
LOCAL_PATH = re.compile(r"(?<![\w/])(?:/Users/|/home/|~/)[\w.\-/]+")
WRAP_END = re.compile(r"[.!?:][\"')\]]*\s*$")


def hard_wrapped(lines):
    """True when a line ends without sentence punctuation and the next starts lowercase."""
    for first, second in zip(lines, lines[1:]):
        if not WRAP_END.search(first) and re.match(r"\s*[a-z]", second):
            return True
    return False


def names_pattern():
    names = [n.strip() for n in os.environ.get("HERALD_NAMES", "").split(",") if n.strip()]
    return re.compile(r"\b(?:" + "|".join(re.escape(n) for n in names) + r")\b", re.I) if names else None


def universal_hits(prose):
    hits = []
    for m in SLOP.finditer(prose):
        hits.append(hit(prose, m.start(), "slop word", m.group(0)))
    for m in DASH.finditer(prose):
        hits.append(hit(prose, m.start(), "em-dash", line_text(prose, m.start())))
    for m in CLOSERS.finditer(prose):
        hits.append(hit(prose, m.start(), "filler closer", line_text(prose, m.start())))
    for m in LOCAL_PATH.finditer(prose):
        hits.append(hit(prose, m.start(), "local machine path", m.group(0)))
    names = names_pattern()
    if names:
        for m in names.finditer(prose):
            hits.append(hit(prose, m.start(), "personal name", m.group(0)))
    wrapped = False
    for start, lines in paragraphs(prose):
        if OPENER.match(lines[0]):
            hits.append({"line": start, "category": "filler opener", "text": lines[0].strip()[:80]})
        if not wrapped and len(lines) > 1 and hard_wrapped(lines):
            wrapped = True
            hits.append({"line": start, "category": "hard-wrapped paragraph", "text": lines[0].strip()[:80]})
    return hits


# --- document checks (Task 4) -------------------------------------------------

def document_hits(prose):
    return []


# --- tier and exclusions (Task 5) -------------------------------------------

def tier_for(path, text):
    return "universal"


def skipped(path, text):
    return False


# --- reports ----------------------------------------------------------------

def lint_text(path, text, tier):
    """(tier, hits) for one file's text. tier is auto, document, or universal."""
    if tier == "auto":
        tier = tier_for(path, text)
    prose = prose_only(text)
    hits = universal_hits(prose)
    if tier == "document":
        hits += document_hits(prose)
    return tier, sorted(hits, key=lambda h: h["line"])


def report(path, tier, hits, nudge):
    lines = [f"herald: {path.name}, {tier} tier, {len(hits)} hits."]
    for h in hits[: LIMITS["max_hits"]]:
        lines.append(f"  line {h['line']}, {h['category']}: {h['text']}")
    if len(hits) > LIMITS["max_hits"]:
        lines.append(f"  and {len(hits) - LIMITS['max_hits']} more.")
    if nudge and hits:
        lines.append("Fix these in the file you just wrote, then continue.")
    return "\n".join(lines)


def command(argv):
    path = pathlib.Path(argv[argv.index("--file") + 1]).expanduser().absolute()
    tier = argv[argv.index("--tier") + 1] if "--tier" in argv else "auto"
    text = path.read_text(encoding="utf-8")
    if tier == "auto" and skipped(path, text):
        print(f"herald: {path.name}, skipped.")
        return 0
    tier, hits = lint_text(path, text, tier)
    print(report(path, tier, hits, nudge=False))
    return 0


def main(argv):
    try:
        if "--file" in argv:
            return command(argv)
        return 0
    except Exception:  # noqa: BLE001  advisory: a crash must never block the session
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
