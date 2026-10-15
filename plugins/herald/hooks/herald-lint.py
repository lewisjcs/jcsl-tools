#!/usr/bin/env python3
"""Herald linter: a nudge after a markdown write, and a command for the rewrite skill.

Hook mode (no --file): reads one JSON event on stdin, finds the markdown files
the tool wrote, lints each, and prints one JSON object with additionalContext
when there are hits. Prints nothing otherwise. Exits 0 always. Never blocks.

Command mode: herald-lint.py --file PATH [--tier auto|document|universal]
prints the same report to stdout, with the tier line even at 0 hits.

Standard library only. Every word list, glob, and limit comes from rules.json.
"""
import json
import os
import pathlib
import re
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
try:
    RULES = json.loads((HERE / "rules.json").read_text(encoding="utf-8"))
except Exception:  # noqa: BLE001  advisory: a missing or malformed rules file must never block the session
    sys.exit(0)
try:
    # Every key the module reads at import or run time: a short rules file exits 0 before any regex is built.
    for _key in ("limits", "slop", "modals", "openers", "closers", "contractions", "irregular_participles",
                 "ing_after_comma", "document_globs", "deny_segments", "config_segments", "ears_min_items"):
        RULES[_key]
    for _key in ("sentence_words", "list_item_sentence_words", "max_hits", "reports_per_file"):
        RULES["limits"][_key]
except Exception:  # noqa: BLE001  advisory: a short rules file must never block the session
    sys.exit(0)
LIMITS = RULES["limits"]


# --- text shaping ---------------------------------------------------------

def _blank(match):
    """The matched span as spaces, newlines kept, so line numbers survive."""
    return re.sub(r"[^\n]", " ", match.group(0))


def _code_word(match):
    """One placeholder word for an inline code span, same length as the span."""
    span = match.group(0)
    return ("CODE" + " " * len(span))[: len(span)]


def _blank_url(m):
    """Blank a bare URL but give trailing punctuation back."""
    url = m.group(0)
    trail = len(url) - len(url.rstrip(".,;:!?)]"))
    return " " * (len(url) - trail) + url[len(url) - trail:]


def prose_only(text):
    """The text with frontmatter, fenced code, inline code, tables, and link targets blanked."""
    text = text.replace("\r\n", "\n").replace("’", "'")
    text = re.sub(r"\A---\n.*?\n---\n", _blank, text, flags=re.S)
    text = re.sub(r"^[ \t]*(`{3,}|~{3,})[^\n]*\n.*?^[ \t]*\1[^\n]*", _blank, text, flags=re.S | re.M)
    text = re.sub(r"`[^`\n]+`", _code_word, text)
    text = re.sub(r"^[ \t]*\|.*$", _blank, text, flags=re.M)
    text = re.sub(r"\]\([a-zA-Z][a-zA-Z0-9+.-]*:[^)\n]*\)", _blank, text)
    text = re.sub(r"https?://[^\s<>()]+", _blank_url, text)
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
    return {"line": prose.count("\n", 0, offset) + 1, "category": category, "text": " ".join(text.split())[:80]}


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


# --- document checks -------------------------------------------------

MODALS = re.compile(r"\b(" + "|".join(RULES["modals"]) + r")\b", re.I)
PERFECT = re.compile(r"\b(?:has|have|had)\s+(?:\w+ed|" + "|".join(RULES["irregular_participles"]) + r")(?![\w-])", re.I)
CONTRACTIONS = re.compile(r"\b(?:" + "|".join(re.escape(c) for c in RULES["contractions"]) + r")\b|\b\w+n't\b", re.I)
ING_AFTER_COMMA = re.compile(r",\s*(?:" + "|".join(RULES["ing_after_comma"]) + r")\b", re.I)


def is_month(prose, m):
    """A capital "May" is the month when a digit follows it, or when it does not
    start a sentence (the text before it on its line is non-empty and does not
    end with . ! ? or :)."""
    if re.match(r"\s+\d", prose[m.end(): m.end() + 6]):
        return True
    before = prose[prose.rfind("\n", 0, m.start()) + 1: m.start()].replace(" ", "")
    return bool(before) and before[-1] not in ".!?:"


def document_hits(prose):
    hits = []
    for line, numbered, sentence in sentences(prose):
        limit = LIMITS["list_item_sentence_words"] if numbered else LIMITS["sentence_words"]
        count = len(sentence.split())
        if count > limit:
            hits.append({"line": line, "category": f"sentence over {limit} words ({count})", "text": " ".join(sentence.split())[:80]})
    for m in MODALS.finditer(prose):
        if m.group(0) == "May" and is_month(prose, m):
            continue
        hits.append(hit(prose, m.start(), "banned modal", line_text(prose, m.start())))
    for m in PERFECT.finditer(prose):
        hits.append(hit(prose, m.start(), "present perfect", m.group(0)))
    for m in CONTRACTIONS.finditer(prose):
        hits.append(hit(prose, m.start(), "contraction", m.group(0)))
    for m in re.finditer(";", prose):
        hits.append(hit(prose, m.start(), "semicolon", line_text(prose, m.start())))
    for m in ING_AFTER_COMMA.finditer(prose):
        hits.append(hit(prose, m.start(), "-ing verb after a comma", line_text(prose, m.start())))
    return hits


# --- tier and exclusions -------------------------------------------

FRONTMATTER = re.compile(r"\A---\n(.*?)\n---\n", re.S)


def frontmatter_value(text, key):
    """The frontmatter value for key, lowercased, or None."""
    m = FRONTMATTER.match(text.replace("\r\n", "\n"))
    if not m:
        return None
    found = re.search(r"^%s:\s*(\S+)\s*$" % re.escape(key), m.group(1), re.M)
    return found.group(1).strip("\"'").lower() if found else None


def glob_regex(glob):
    """A regex for one glob. ** crosses folders, * stays inside one, and a match may start at any folder."""
    parts, i = [], 0
    while i < len(glob):
        if glob.startswith("**/", i):
            parts.append("(?:.*/)?")
            i += 3
        elif glob.startswith("**", i):
            parts.append(".*")
            i += 2
        elif glob[i] == "*":
            parts.append("[^/]*")
            i += 1
        elif glob[i] == "?":
            parts.append("[^/]")
            i += 1
        else:
            parts.append(re.escape(glob[i]))
            i += 1
    return re.compile(r"(?:^|.*/)" + "".join(parts) + r"$", re.I)


def is_document_path(path):
    extra = [g for g in os.environ.get("HERALD_DOCUMENT_GLOBS", "").split(os.pathsep) if g]
    posix = path.as_posix()
    return any(glob_regex(g).match(posix) for g in RULES["document_globs"] + extra)


def ears_content(text):
    """True when three or more list items carry the word shall: an EARS requirements file."""
    items = [line for line in prose_only(text).split("\n") if LIST_ITEM.match(line)]
    return sum(1 for line in items if re.search(r"\sshall\s", line, re.I)) >= RULES["ears_min_items"]


def tier_for(path, text, cwd=None):
    """document or universal for a file that is not skipped. Explicit frontmatter wins over the path."""
    marker = frontmatter_value(text, "herald")
    if marker == "document":
        return "document"
    rel = checked_path(path, cwd)
    if not is_document_path(rel):
        return "universal"
    if {p.lower() for p in rel.parts} & set(RULES["deny_segments"]):
        return "universal"
    if ears_content(text):
        return "universal"
    if marker == "universal":
        return "universal"
    return "document"


def absolute(raw, cwd):
    """The path as an absolute path. A relative path resolves against cwd from the event."""
    return pathlib.Path(os.path.normpath(pathlib.Path(cwd or os.getcwd(), pathlib.Path(raw).expanduser()).absolute()))


def checked_path(path, cwd):
    """The path relative to cwd when it is inside cwd, else unchanged. Folders above the project do not count."""
    if cwd:
        base = absolute(cwd, None)
        for root in (base, base.resolve()):
            for candidate in (path, path.resolve()):
                if candidate.is_relative_to(root):
                    return candidate.relative_to(root)
    return path


def forms(path):
    """The path as written and with symlinks resolved. An exclusion matches either form."""
    return {pathlib.Path(os.path.normpath(path)), path.resolve()}


def skipped(path, text, cwd=None):
    """True for files inside an agent configuration folder, an excluded glob, or with herald: off."""
    config_dirs = set()
    for raw in (os.environ.get("CLAUDE_CONFIG_DIR") or "~/.claude", "~/.codex", "~/.cursor"):
        config_dirs |= forms(pathlib.Path(raw).expanduser().absolute())
    patterns = [glob_regex(os.path.expanduser(p)) for p in os.environ.get("HERALD_EXCLUDE", "").split(os.pathsep) if p]
    for form in forms(path):
        if set(checked_path(form, cwd).parts) & set(RULES["config_segments"]):
            return True
        if any(form == d or form.is_relative_to(d) for d in config_dirs):
            return True
        if any(p.match(form.as_posix()) for p in patterns):
            return True
    return frontmatter_value(text, "herald") == "off"


# --- reports ----------------------------------------------------------------

def lint_text(path, text, tier, cwd=None):
    """(tier, hits) for one file's text. tier is auto, document, or universal."""
    if tier == "auto":
        tier = tier_for(path, text, cwd)
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
        lines.append("Fix the ones in text you wrote or changed. Leave older text unless the task covers it.")
    return "\n".join(lines)


def command(argv):
    path = pathlib.Path(argv[argv.index("--file") + 1]).expanduser().absolute()
    tier = argv[argv.index("--tier") + 1] if "--tier" in argv else "auto"
    text = path.read_text(encoding="utf-8")
    if tier == "auto" and skipped(path, text, os.getcwd()):
        print(f"herald: {path.name}, skipped.")
        return 0
    tier, hits = lint_text(path, text, tier, os.getcwd())
    print(report(path, tier, hits, nudge=False))
    return 0


# --- hook mode -----------------------------------------------------------------

PATCH_FILE = re.compile(r"^\*\*\* (?:Update|Add) File: (.+?)\s*$", re.M)


def event_paths(event):
    """The markdown files the tool wrote: Claude Code's file_path, or the files named in a Codex apply_patch."""
    tool_input = event.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return []
    if tool_input.get("file_path"):
        raw = [str(tool_input["file_path"])]
    elif event.get("tool_name") == "apply_patch":
        command = tool_input.get("command") or ""
        if isinstance(command, list):
            command = "\n".join(str(c) for c in command)
        raw = PATCH_FILE.findall(str(command))
    else:
        raw = []
    return [absolute(p, event.get("cwd")) for p in raw if p.endswith(".md")]


def guard_dir():
    for key in ("CLAUDE_PLUGIN_DATA", "PLUGIN_DATA"):
        if os.environ.get(key):
            return pathlib.Path(os.environ[key])
    getuid = getattr(os, "getuid", None)
    return pathlib.Path(tempfile.gettempdir()) / (f"herald-{getuid()}" if getuid else "herald")


def guard_allows(session_id, path):
    """True when this file has had fewer than the allowed reports this session. Counts this one."""
    folder = guard_dir()
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    store = folder / "loop-guard.json"
    try:
        data = json.loads(store.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            data = {}
    except (OSError, ValueError):
        data = {}
    per_session = data.setdefault(str(session_id or "no-session"), {})
    key = str(path.resolve())
    count = per_session.get(key, 0)
    if count >= LIMITS["reports_per_file"]:
        return False
    per_session[key] = count + 1
    fd, temp = tempfile.mkstemp(dir=folder, prefix="loop-guard-", suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write(json.dumps(data))
    os.replace(temp, store)
    return True


def output_for_host(text, host):
    if host == "cursor":
        return {"additional_context": text}
    return {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": text}}


def hook(event, host):
    reports = []
    for path in event_paths(event):
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, ValueError):
            continue
        if skipped(path, text, event.get("cwd")):
            continue
        tier, hits = lint_text(path, text, "auto", event.get("cwd"))
        if hits and guard_allows(event.get("session_id"), path):
            reports.append(report(path, tier, hits, nudge=True))
    if reports:
        print(json.dumps(output_for_host("\n".join(reports), host)))
    return 0


def main(argv):
    try:
        if "--file" in argv:
            return command(argv)
        host = argv[argv.index("--host") + 1] if "--host" in argv else "claude"
        return hook(json.load(sys.stdin), host)
    except Exception:  # noqa: BLE001  advisory: a crash must never block the session
        return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
