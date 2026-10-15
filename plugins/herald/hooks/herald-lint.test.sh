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

Inline `simply — /Users/x` and [link](/Users/x/simply).
MD
out="$(python3 "$SCRIPT" --file "$TMP/notes/blank.md")"
assert_contains "blanked file has zero hits" "$out" "0 hits"

echo "PASS/FAIL summary:"; [ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
