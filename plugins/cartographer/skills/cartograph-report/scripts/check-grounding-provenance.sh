#!/bin/bash
# Grounding provenance checker — RC-15/RC-24 entry-level commit ordering.
# For each see: marker in core/knowledge/, verify the cited reference entry was
# not committed after the knowledge line citing it, by line-level blame:
# the marker line's commit must not be a strict ancestor of the cited anchor
# heading's commit. Same-commit passes — a squash merge collapses a branch's
# reference-first history into one commit, and that must stay green.
# Markers without an anchor, or whose anchor has no matching heading, are
# skipped here: check-knowledge-grounding.sh rule (c) already fails them.
# Run: bash check-grounding-provenance.sh [CORE_DIR]
# Default CORE_DIR: <dir of this script>/../core

set -u

# Derive CORE_DIR from argument or default; explicit argument wins over env
if [ -n "${1:-}" ]; then
  CORE_DIR="$1"
else
  CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
  # Only use CLAUDE_PLUGIN_ROOT as override if no explicit argument was given
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    CORE_DIR="$CLAUDE_PLUGIN_ROOT/core"
  fi
fi

KNOWLEDGE_DIR="$CORE_DIR/knowledge"
REFERENCES_DIR="$CORE_DIR/references"
FAIL=0

# ──────────────────────────────────────────────────────────────────────────────
# Find the line number of the heading whose slug matches an anchor
find_anchor_line() {
  local file="$1"
  local anchor="$2"
  local heading_pattern='^#+[[:space:]]+'
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ $line =~ $heading_pattern ]]; then
      local text="${line#*[[:space:]]}"
      # Build slug: lowercase, drop non-alphanumeric/space/hyphen, collapse spaces
      text="${text//[^[:alnum:] -]/}"
      text="${text,,}"
      text="${text// /-}"
      while [[ $text == *--* ]]; do text="${text//--/-}"; done
      if [ "$text" = "$anchor" ]; then
        printf '%d' "$line_num"
        return 0
      fi
    fi
  done < "$file"
  return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# Blame a single line to its commit; fails on untracked files and uncommitted lines
blame_line_commit() {
  local file="$1"
  local lnum="$2"
  local out
  out="$(git -C "$CORE_DIR" blame --porcelain -L "$lnum,$lnum" -- "$file" 2>/dev/null)" || return 1
  local hash="${out%% *}"
  # An all-zero hash means the line exists only in the working tree
  [ "$hash" = "0000000000000000000000000000000000000000" ] && return 1
  printf '%s' "$hash"
}

# ──────────────────────────────────────────────────────────────────────────────
# Check provenance for a single knowledge file
# For each see: marker, verify the knowledge line does not predate the entry
# ──────────────────────────────────────────────────────────────────────────────

check_knowledge_file() {
  local kfile="$1"
  local fence_state=0
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track fence state
    if [[ $line =~ ^[[:space:]]*\`{3,}|^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
    fi

    # Skip if in fence (RC-25)
    [ $fence_state -ne 0 ] && continue

    # Check for see: markers
    if [[ $line =~ \<\!--[[:space:]]*see:[[:space:]]*([^#]+)(#[^[:space:]]+)?[[:space:]]*--\> ]]; then
      local target_path="${BASH_REMATCH[1]}"
      local anchor="${BASH_REMATCH[2]}"
      local resolved_target="$CORE_DIR/$target_path"

      # Skip if reference doesn't exist or the marker has no anchor
      # (rule (c) fails both)
      if ! [ -f "$resolved_target" ] || [ -z "$anchor" ]; then
        continue
      fi

      # Skip if the anchor has no matching heading (rule (c) fails it)
      local rline
      if ! rline="$(find_anchor_line "$resolved_target" "${anchor#\#}")"; then
        continue
      fi

      # Blame the cited heading; uncommitted entries have no provenance
      local rcommit
      if ! rcommit="$(blame_line_commit "$resolved_target" "$rline")"; then
        printf 'ERROR|provenance|%s:%d|cited reference entry is not committed\n' "$kfile" "$line_num"
        FAIL=$((FAIL + 1))
        continue
      fi

      # Blame the marker line; uncommitted knowledge has no provenance
      local kcommit
      if ! kcommit="$(blame_line_commit "$kfile" "$line_num")"; then
        printf 'ERROR|provenance|%s:%d|knowledge line is not committed\n' "$kfile" "$line_num"
        FAIL=$((FAIL + 1))
        continue
      fi

      # Same commit passes: a squash merge lands both sides together
      [ "$kcommit" = "$rcommit" ] && continue

      # Fail only when the knowledge line provably predates the entry —
      # a backfilled citation
      if git -C "$CORE_DIR" merge-base --is-ancestor "$kcommit" "$rcommit" 2>/dev/null; then
        printf 'ERROR|provenance|%s:%d|reference entry committed after the knowledge citing it\n' "$kfile" "$line_num"
        FAIL=$((FAIL + 1))
      fi
    fi
  done < "$kfile"

  return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────

# Check all knowledge files
if [ -d "$KNOWLEDGE_DIR" ]; then
  while IFS= read -r kfile; do
    check_knowledge_file "$kfile" || true
  done < <(find "$KNOWLEDGE_DIR" -maxdepth 1 -type f -name '*.md')
fi

# Exit with appropriate code
if [ $FAIL -gt 0 ]; then
  exit 1
fi

exit 0
