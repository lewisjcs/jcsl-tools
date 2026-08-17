#!/bin/bash
# Grounding provenance checker — RC-15/RC-24 commit ancestry ordering.
# For each see: marker in core/knowledge/, verify reference was committed first via ancestry.
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
# Extract all headings from a file and build a slug set
extract_slugs() {
  local file="$1"
  local heading_pattern='^#+[[:space:]]+'
  local slug
  while IFS= read -r line; do
    if [[ $line =~ $heading_pattern ]]; then
      local text="${line#*[[:space:]]}"
      # Build slug: lowercase, drop non-alphanumeric/space/hyphen, collapse spaces
      text="${text//[^[:alnum:] -]/}"
      text="${text,,}"
      text="${text// /-}"
      text="${text//-+/-g}"
      printf '%s\n' "#$text"
    fi
  done < "$file"
}

# ──────────────────────────────────────────────────────────────────────────────
# Check provenance for a single knowledge file
# For each see: marker, verify reference commit is ancestor of knowledge commit
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
      local resolved_target="$CORE_DIR/$target_path"

      # Skip if reference doesn't exist (rule (c) will catch this)
      if ! [ -f "$resolved_target" ]; then
        continue
      fi

      # Get the commit hash that added the reference file
      local rcommit="$(git log -1 --format=%H --diff-filter=A -- "$resolved_target" 2>/dev/null)"

      # Get the commit hash that added the knowledge file
      local kcommit="$(git log -1 --format=%H --diff-filter=A -- "$kfile" 2>/dev/null)"

      # Check if either is untracked (empty hash)
      if [ -z "$rcommit" ] || [ -z "$kcommit" ]; then
        printf 'ERROR|provenance|%s:%d|commit references first\n' "$kfile" "$line_num"
        FAIL=$((FAIL + 1))
        continue
      fi

      # Check if in the same commit (must be strict ancestry)
      if [ "$rcommit" = "$kcommit" ]; then
        printf 'ERROR|provenance|%s:%d|references and knowledge in same commit\n' "$kfile" "$line_num"
        FAIL=$((FAIL + 1))
        continue
      fi

      # Check ancestry: reference must be strict ancestor of knowledge
      if ! git merge-base --is-ancestor "$rcommit" "$kcommit" 2>/dev/null; then
        printf 'ERROR|provenance|%s:%d|reference not committed before knowledge\n' "$kfile" "$line_num"
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
