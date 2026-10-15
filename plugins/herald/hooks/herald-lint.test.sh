#!/usr/bin/env bash
# Fixture-driven checks for herald-lint.py. Exit 0 when every check passes.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/herald-lint.py"
fail=0
ok() { echo "ok: $1"; }
bad() { echo "FAIL: $1"; fail=1; }
assert_contains() { if grep -q -- "$3" <<<"$2"; then ok "$1"; else bad "$1 (missing: $3)"; echo "$2" | sed 's/^/    /'; fi; }
assert_missing() { if grep -q -- "$3" <<<"$2"; then bad "$1 (present: $3)"; echo "$2" | sed 's/^/    /'; else ok "$1"; fi; }
assert_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$2] got [$3])"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export CLAUDE_PLUGIN_DATA="$TMP/data"

# 5. A handoff with an em-dash and a hard wrap: universal, two categories.
mkdir -p "$TMP/notes"
cat > "$TMP/notes/handoff.md" <<'MD'
# Handoff

The run finished — the next step is the review.

This paragraph is wrapped by hand
and continues on the next line.

Use `git --no-pager log` and see [the log](https://example.com/a—b).
MD
out="$(python3 "$SCRIPT" --file "$TMP/notes/handoff.md")"; rc=$?
assert_eq "handoff exit 0" "0" "$rc"
assert_contains "handoff universal tier" "$out" "universal tier"
assert_contains "handoff em-dash" "$out" "em-dash"
assert_contains "handoff hard wrap" "$out" "hard-wrapped paragraph"
assert_contains "handoff two hits" "$out" "2 hits"
assert_eq "handoff em-dash on line 3" "1" "$(grep -c 'line 3, em-dash' <<<"$out")"

# Universal word checks: slop, opener, closer, local path, name.
cat > "$TMP/notes/words.md" <<'MD'
Certainly, this is the plan.

We simply leverage the tool in order to streamline the work at /Users/someone/repo and ~/code/thing.

Let me know if that helps.
MD
out="$(HERALD_NAMES="Someone" python3 "$SCRIPT" --file "$TMP/notes/words.md")"
assert_contains "slop word" "$out" "slop word: simply"
assert_contains "slop phrase" "$out" "slop word: in order to"
assert_contains "filler opener" "$out" "filler opener"
assert_contains "filler closer" "$out" "filler closer"
assert_eq "two local paths" "2" "$(grep -c 'local machine path' <<<"$out")"
assert_contains "personal name" "$out" "personal name"
assert_missing "no hard wrap on one-line paragraphs" "$out" "hard-wrapped"

# Blanking: code, tables, link targets, and frontmatter never produce hits.
cat > "$TMP/notes/blank.md" <<'MD'
---
title: it's — simply
---

| Column | Value |
|---|---|
| simply — | /Users/x |

```
simply — /Users/x
```

Inline `simply — /Users/x` and [link](https://example.com/Users/x/simply).
MD
out="$(python3 "$SCRIPT" --file "$TMP/notes/blank.md")"
assert_contains "blanked file has zero hits" "$out" "0 hits"

# Fences: indented and tilde fences are blanked; the closing run must match.
cat > "$TMP/notes/fences.md" <<'MD'
Steps:

1. Run the setup.

   ```bash
   cd ~/code/project — simply
   git checkout -- notes.md
   ```

2. Then check it.

~~~
em-dash — here, ~/code/project, git checkout -- notes.md
~~~

````
```
simply — /Users/x
```
````
MD
out="$(python3 "$SCRIPT" --file "$TMP/notes/fences.md")"
assert_contains "indented and tilde fences blanked" "$out" ", 0 hits."

# Link targets: a local path stays visible, a scheme target is blanked.
cat > "$TMP/notes/links.md" <<'MD'
See [notes](/Users/name/notes.md) and [site](https://example.com/a—b).
MD
out="$(python3 "$SCRIPT" --file "$TMP/notes/links.md")"
assert_eq "one local path in a link" "1" "$(grep -c 'local machine path' <<<"$out")"
assert_missing "no em-dash from a URL target" "$out" "em-dash"

# A bare URL keeps the period that ends its sentence.
res="$(python3 -B -c '
import importlib.util, sys
spec = importlib.util.spec_from_file_location("hl", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
src = "See https://example.com. Then run it."
out = m.prose_only(src)
print(out.rstrip().endswith("Then run it.") and out[src.index("com") + 3] == ".")
' "$SCRIPT")"
assert_eq "period after a bare URL survives" "True" "$res"

# 1. A README with one over-limit sentence, one "should", one "has completed",
#    one contraction, one semicolon: document tier, five categories.
mkdir -p "$TMP/repo"
cat > "$TMP/repo/README.md" <<'MD'
# Demo

This sentence should be flagged for a modal. The team has completed the migration and it’s done; the rest follows.

One sentence that runs on and on with many words so that it goes over the twenty five word limit set by the document rules for descriptive text here.

The release ships in May 2026, and the team uses the tool.
MD
out="$(python3 "$SCRIPT" --file "$TMP/repo/README.md" --tier document)"
assert_contains "readme document tier" "$out" "document tier"
assert_contains "readme sentence over limit" "$out" "sentence over 25 words"
assert_contains "readme banned modal" "$out" "banned modal"
assert_contains "readme present perfect" "$out" "present perfect"
assert_contains "readme contraction (typographic apostrophe)" "$out" "contraction"
assert_contains "readme semicolon" "$out" "semicolon"
assert_eq "readme exactly five hits" "5" "$(grep -c '^  line' <<<"$out")"
assert_missing "May 2026 is not a modal" "$out" "banned modal: The release"

# Numbered list items use the 20-word limit; -ing after a comma is a hit.
cat > "$TMP/repo/CHANGELOG.md" <<'MD'
# Changes

1. Run the installer on the host that holds the data, then restart the service that reads it, then read the log file.
2. Restart it.

The tool retries the upload, making the data safe.
MD
out="$(python3 "$SCRIPT" --file "$TMP/repo/CHANGELOG.md" --tier document)"
assert_contains "numbered item over 20 words" "$out" "sentence over 20 words"
assert_contains "ing after comma" "$out" "-ing verb after a comma"
assert_eq "changelog exactly two hits" "2" "$(grep -c '^  line' <<<"$out")"

# A README whose only long lines are table rows: no sentence hits.
cat > "$TMP/repo/README-table.md" <<'MD'
# Table

| Command | What it does |
|---|---|
| run | One cell that is very long and holds many words so that a naive sentence counter would flag it as over the limit for sure. |
MD
out="$(python3 "$SCRIPT" --file "$TMP/repo/README-table.md" --tier document)"
assert_contains "table rows produce zero hits" "$out" "0 hits"

# Fix round 1: hyphenated compounds, May as a month, one-line hit text.
cat > "$TMP/repo/README-perfect.md" <<'MD'
# Perfect

The server has read-only access and has built-in caching.

The team has completed it.
MD
out="$(python3 "$SCRIPT" --file "$TMP/repo/README-perfect.md" --tier document)"
assert_contains "has completed is a present perfect hit" "$out" "present perfect: has completed"
assert_eq "hyphenated compounds are not present perfect" "1" "$(grep -c 'present perfect' <<<"$out")"

cat > "$TMP/repo/README-may.md" <<'MD'
# May

Support ends in May.
The release shipped on 15 May, after the freeze.
May 2026 is the target.
You may run it.
MD
out="$(python3 "$SCRIPT" --file "$TMP/repo/README-may.md" --tier document)"
assert_eq "May as a month: exactly one modal hit" "1" "$(grep -c 'banned modal' <<<"$out")"
assert_contains "the modal hit is the may line" "$out" "line 6"

cat > "$TMP/repo/README-wrap.md" <<'MD'
# Wrap

One sentence that runs on and on with many words so that it goes over
the twenty five word limit set by the document rules for descriptive
text here.
MD
out="$(python3 "$SCRIPT" --file "$TMP/repo/README-wrap.md" --tier document)"
assert_contains "wrapped sentence over limit" "$out" "sentence over 25 words"
n="$(sed -n 's/.*document tier, \([0-9]*\) hit.*/\1/p' <<<"$out")"
assert_eq "hit text stays on one line" "$n" "$(grep -c '^  line' <<<"$out")"

# 2. An EARS ticket under docs/tickets/: universal by the deny list, no modal or length hits.
mkdir -p "$TMP/repo/docs/tickets" "$TMP/repo/docs/features" "$TMP/repo/docs/adr" "$TMP/repo/docs/guide"
cat > "$TMP/repo/docs/tickets/T-1.md" <<'MD'
# T-1

- The system shall retry the upload when the network fails, and the system should log the retry count every time it happens for the operator to read later on the console page.
- The system shall keep the data.
- The system shall report the result.
MD
out="$(python3 "$SCRIPT" --file "$TMP/repo/docs/tickets/T-1.md")"
assert_contains "ticket universal tier" "$out" "universal tier"
assert_missing "ticket no modal hits" "$out" "banned modal"
assert_missing "ticket no length hits" "$out" "sentence over"

# 3. Five shall bullets under docs/ with no deny-listed segment: universal by the EARS pull-back.
cp "$TMP/repo/docs/tickets/T-1.md" "$TMP/repo/docs/features/login.md"
out="$(python3 "$SCRIPT" --file "$TMP/repo/docs/features/login.md")"
assert_contains "ears pull-back universal" "$out" "universal tier"

# A docs file with no shall bullets is document tier.
printf '# Guide\n\nYou should run it.\n' > "$TMP/repo/docs/guide/run.md"
out="$(python3 "$SCRIPT" --file "$TMP/repo/docs/guide/run.md")"
assert_contains "docs guide document tier" "$out" "document tier"
assert_contains "docs guide modal hit" "$out" "banned modal"

# 4. An ADR under docs/adr/: universal by the deny list.
printf '# ADR 1\n\nWe should use Postgres.\n' > "$TMP/repo/docs/adr/0001-db.md"
out="$(python3 "$SCRIPT" --file "$TMP/repo/docs/adr/0001-db.md")"
assert_contains "adr universal" "$out" "universal tier"

# Frontmatter: herald: universal pulls back, herald: document forces, herald: off skips.
printf -- '---\nherald: universal\n---\n\n# R\n\nYou should run it.\n' > "$TMP/repo/README-u.md"
assert_contains "frontmatter universal" "$(python3 "$SCRIPT" --file "$TMP/repo/README-u.md")" "universal tier"
printf -- '---\nherald: document\n---\n\n# N\n\nYou should run it.\n' > "$TMP/repo/notes.md"
assert_contains "frontmatter document" "$(python3 "$SCRIPT" --file "$TMP/repo/notes.md")" "document tier"
printf -- '---\nherald: off\n---\n\n# R\n\nYou should run it.\n' > "$TMP/repo/README-off.md"
assert_contains "frontmatter off" "$(python3 "$SCRIPT" --file "$TMP/repo/README-off.md")" "skipped"

# Config folders are skipped by segment and by CLAUDE_CONFIG_DIR.
mkdir -p "$TMP/.claude" "$TMP/cfg/sub"
printf 'You should.\n' > "$TMP/.claude/notes.md"
printf 'You should.\n' > "$TMP/cfg/sub/README.md"
assert_contains "dot-claude segment skipped" "$(python3 "$SCRIPT" --file "$TMP/.claude/notes.md")" "skipped"
assert_contains "config dir skipped" "$(CLAUDE_CONFIG_DIR="$TMP/cfg" python3 "$SCRIPT" --file "$TMP/cfg/sub/README.md")" "skipped"

# HERALD_EXCLUDE and HERALD_DOCUMENT_GLOBS.
assert_contains "exclude glob skipped" "$(HERALD_EXCLUDE="$TMP/repo/docs/guide/*" python3 "$SCRIPT" --file "$TMP/repo/docs/guide/run.md")" "skipped"
mkdir -p "$TMP/repo/manual"
printf '# M\n\nYou should run it.\n' > "$TMP/repo/manual/intro.md"
assert_contains "extra glob makes document tier" "$(HERALD_DOCUMENT_GLOBS="**/manual/**/*.md" python3 "$SCRIPT" --file "$TMP/repo/manual/intro.md")" "document tier"
assert_contains "without extra glob it is universal" "$(python3 "$SCRIPT" --file "$TMP/repo/manual/intro.md")" "universal tier"

echo "PASS/FAIL summary:"; [ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
