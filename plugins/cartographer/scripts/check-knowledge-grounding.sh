#!/bin/bash
# Knowledge grounding checker — rules (a), (b), (c), (c'), (d) per RC-1 through RC-5.
# Rules (a), (b), (c), (c'): core/knowledge/ only. Rule (d): core/references/ only.
# Run: bash check-knowledge-grounding.sh [CORE_DIR]
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
PASS=0
FAIL=0

# ──────────────────────────────────────────────────────────────────────────────
# UTILITIES
# ──────────────────────────────────────────────────────────────────────────────

# Check if a line is inside a fenced code block.
# Returns 0 if the line is inside a fence, 1 if outside.
is_in_fence() {
  local line_num="$1"
  local fence_state=0
  local i
  # Parse line by line up to line_num to track fence state
  # This assumes $FILE is set in the caller context
  for ((i = 1; i <= line_num; i++)); do
    local line="$(sed -n "${i}p" "$FILE")"
    if [[ $line =~ ^[[:space:]]*\`{3,}|^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
    fi
  done
  return $fence_state
}

# Detect unterminated fences in a file
check_fence_integrity() {
  local file="$1"
  local fence_state=0
  local line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ $line =~ ^[[:space:]]*\`{3,}|^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
    fi
  done < "$file"
  if [ $fence_state -ne 0 ]; then
    printf 'ERROR|fence-integrity|%s|unterminated fence\n' "$file"
    return 1
  fi
  return 0
}

# Build anchor slug from heading text (GitHub style)
# Convert to lowercase, drop non-alphanumeric/space/hyphen, collapse spaces to hyphens
make_slug() {
  local text="$1"
  text="${text//[^[:alnum:] -]/}"  # Drop non-alphanumeric/space/hyphen
  text="${text,,}"  # Lowercase
  text="${text// /-}"  # Replace spaces with hyphens
  text="${text//-+/-g}"  # Collapse multiple hyphens
  printf '%s' "$text"
}

# Extract all headings from a file and build a slug set
extract_slugs() {
  local file="$1"
  local heading_pattern='^#+[[:space:]]+'
  local slug
  while IFS= read -r line; do
    if [[ $line =~ $heading_pattern ]]; then
      # Remove leading # and spaces
      local text="${line#*[[:space:]]}"
      slug="$(make_slug "$text")"
      printf '%s\n' "#$slug"
    fi
  done < "$file"
}

# ──────────────────────────────────────────────────────────────────────────────
# RULE (a): Missing evidentiary basis (core/knowledge/ only)
# A section with a claim-shaped line needs at least one marker (see: or rationale:)
# Non-firing: a section with no claim-shaped line needs no marker
# ──────────────────────────────────────────────────────────────────────────────

check_rule_a() {
  local file="$1"
  shopt -s nocasematch  # Enable case-insensitive matching per RC-2

  # Check fence integrity first
  check_fence_integrity "$file" || { shopt -u nocasematch; return 1; }

  local in_section=0
  local section_start_line=0
  local section_heading=""
  local has_claim=0
  local has_marker=0
  local fence_state=0
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track fence state
    if [[ $line =~ ^[[:space:]]*\`{3,}|^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
    fi

    # Detect section start (## or ### heading)
    if [[ $line =~ ^(##[[:space:]]+)([^#].*)$ ]]; then
      # If we were in a section, check it
      if [ $in_section -eq 1 ] && [ $has_claim -eq 1 ] && [ $has_marker -eq 0 ]; then
        printf 'ERROR|rule-a|%s:%d|%s\n' "$file" "$section_start_line" "$section_heading"
        FAIL=$((FAIL + 1))
      fi

      # Start new section
      section_heading="${BASH_REMATCH[2]}"
      section_start_line=$line_num
      in_section=1
      has_claim=0
      has_marker=0
      fence_state=0
      continue
    fi

    # Skip processing if we're not in a section yet
    [ $in_section -eq 0 ] && continue

    # Check for markers (only outside fences)
    if [ $fence_state -eq 0 ]; then
      if [[ $line =~ \<\!--[[:space:]]*(see|rationale):[[:space:]]* ]]; then
        has_marker=1
      fi
    fi

    # Check for claim-shaped lines (only outside fences)
    if [ $fence_state -eq 0 ]; then
      # Check for normative verbs (case-insensitive per RC-2)
      if [[ $line =~ (must|shall|should|never|always|prefer|require|do\ not) ]]; then
        # Skip if line is itself a marker
        if ! [[ $line =~ \<\!--.*--\> ]]; then
          has_claim=1
        fi
      fi
      # Check for numeric thresholds: digit sequence within 20 chars of unit word
      # RC-2: "a digit sequence within 20 characters of lines|chars|characters|tokens|%|sections"
      if [[ $line =~ [0-9]+.{0,20}(lines|chars|characters|tokens|%|sections) ]] || \
         [[ $line =~ (lines|chars|characters|tokens|%|sections).{0,20}[0-9]+ ]]; then
        if ! [[ $line =~ \<\!--.*--\> ]]; then
          has_claim=1
        fi
      fi
    fi
  done < "$file"

  # Check final section
  if [ $in_section -eq 1 ] && [ $has_claim -eq 1 ] && [ $has_marker -eq 0 ]; then
    printf 'ERROR|rule-a|%s:%d|%s\n' "$file" "$section_start_line" "$section_heading"
    FAIL=$((FAIL + 1))
  fi

  shopt -u nocasematch
  return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# RULE (b): Inline full-citation block (core/knowledge/ only)
# Fires when: 2+ blockquote lines, 2+ URLs/arXiv, or 1 >300-char line in a section
# Non-firing: core/references/ files (by design, all full citations)
# ──────────────────────────────────────────────────────────────────────────────

check_rule_b() {
  local file="$1"
  local in_section=0
  local section_start_line=0
  local section_heading=""
  local blockquote_count=0
  local url_count=0
  local long_line_count=0
  local fence_state=0
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track fence state
    if [[ $line =~ ^[[:space:]]*\`{3,}|^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
    fi

    # Detect section start
    if [[ $line =~ ^(##[[:space:]]+)([^#].*)$ ]]; then
      # Check previous section for rule (b) violation
      if [ $in_section -eq 1 ]; then
        local violation=0
        if [ $blockquote_count -ge 2 ]; then violation=1; fi
        if [ $url_count -ge 2 ]; then violation=1; fi
        if [ $long_line_count -ge 1 ]; then violation=1; fi

        if [ $violation -eq 1 ]; then
          local slug="$(make_slug "$section_heading")"
          printf 'ERROR|rule-b|%s:%d|%s|move the full citation to core/references/%s.md and replace it with <!-- see: references/%s.md#%s -->\n' \
            "$file" "$section_start_line" "$section_heading" "$slug" "$slug" "$slug"
          FAIL=$((FAIL + 1))
        fi
      fi

      # Start new section
      section_heading="${BASH_REMATCH[2]}"
      section_start_line=$line_num
      in_section=1
      blockquote_count=0
      url_count=0
      long_line_count=0
      fence_state=0
      continue
    fi

    [ $in_section -eq 0 ] && continue

    # Only check outside fences
    if [ $fence_state -eq 0 ]; then
      # Check for blockquotes
      if [[ $line =~ ^[[:space:]]*\>[[:space:]] ]]; then
        blockquote_count=$((blockquote_count + 1))
      fi

      # Check for URLs and arXiv IDs
      if [[ $line =~ https?://|arXiv: ]]; then
        url_count=$((url_count + 1))
      fi

      # Check for >300 character lines
      if [ ${#line} -gt 300 ]; then
        long_line_count=$((long_line_count + 1))
      fi
    fi
  done < "$file"

  # Check final section
  if [ $in_section -eq 1 ]; then
    local violation=0
    if [ $blockquote_count -ge 2 ]; then violation=1; fi
    if [ $url_count -ge 2 ]; then violation=1; fi
    if [ $long_line_count -ge 1 ]; then violation=1; fi

    if [ $violation -eq 1 ]; then
      local slug="$(make_slug "$section_heading")"
      printf 'ERROR|rule-b|%s:%d|%s|move the full citation to core/references/%s.md and replace it with <!-- see: references/%s.md#%s -->\n' \
        "$file" "$section_start_line" "$section_heading" "$slug" "$slug" "$slug"
      FAIL=$((FAIL + 1))
    fi
  fi

  return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# RULE (c): Unverified citation marker — see: markers only (RC-5)
# Non-firing: rationale: markers never checked, core/references/ files excluded
# ──────────────────────────────────────────────────────────────────────────────

check_rule_c() {
  local file="$1"
  local line_num=0
  local fence_state=0

  # First pass: extract reference slug set
  local refs_file="$REFERENCES_DIR/README.md"
  local -A slug_map

  if [ -f "$refs_file" ]; then
    local in_slugs_section=0
    while IFS= read -r line; do
      if [[ $line =~ ^###[[:space:]]+(.+)$ ]]; then
        in_slugs_section=1
        local ref_file="${BASH_REMATCH[1]}"
        # Extract slugs from this reference file
        local ref_path="$REFERENCES_DIR/$ref_file"
        if [ -f "$ref_path" ]; then
          while IFS= read -r slug; do
            slug_map["$ref_file${slug}"]="1"
          done < <(extract_slugs "$ref_path")
        fi
      fi
    done < "$refs_file"
  fi

  # Second pass: check see: markers
  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track fence state
    if [[ $line =~ ^[[:space:]]*\`{3,}|^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
    fi

    # Skip if in fence
    [ $fence_state -ne 0 ] && continue

    # Check for see: markers
    if [[ $line =~ \<\!--[[:space:]]*see:[[:space:]]*([^#]+)(#[^[:space:]]+)?[[:space:]]*--\> ]]; then
      local target_path="${BASH_REMATCH[1]}"
      local anchor="${BASH_REMATCH[2]}"

      # Resolve path relative to core/
      local resolved_path="$CORE_DIR/$target_path"

      # Check if file exists
      if ! [ -f "$resolved_path" ]; then
        printf 'ERROR|rule-c|%s:%d|unverified|%s\n' "$file" "$line_num" "$target_path"
        FAIL=$((FAIL + 1))
        continue
      fi

      # Check if anchor exists (if provided)
      if [ -n "$anchor" ]; then
        anchor="${anchor#\#}"  # Remove leading #
        local found=0
        while IFS= read -r slug; do
          if [[ "$slug" == "#$anchor" ]]; then
            found=1
            break
          fi
        done < <(extract_slugs "$resolved_path")

        if [ $found -eq 0 ]; then
          printf 'ERROR|rule-c|%s:%d|unverified|%s%s\n' "$file" "$line_num" "$target_path" "#$anchor"
          FAIL=$((FAIL + 1))
        fi
      else
        # Anchor is mandatory
        printf 'ERROR|rule-c|%s:%d|unverified|%s (missing anchor)\n' "$file" "$line_num" "$target_path"
        FAIL=$((FAIL + 1))
      fi
    fi
  done < "$file"

  return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# RULE (c'): Rationale marker validity (core/knowledge/ only)
# Text after rationale: must be non-empty and contain no URL or arXiv ID
# ──────────────────────────────────────────────────────────────────────────────

check_rule_c_prime() {
  local file="$1"
  local line_num=0
  local fence_state=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track fence state
    if [[ $line =~ ^[[:space:]]*\`{3,}|^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
    fi

    # Skip if in fence
    [ $fence_state -ne 0 ] && continue

    # Check for rationale: markers
    if [[ $line =~ \<\!--[[:space:]]*rationale:[[:space:]]*([^-]*)--\> ]]; then
      local text="${BASH_REMATCH[1]}"

      # Check if text is empty
      if [ -z "${text// }" ]; then
        printf 'ERROR|rule-c-prime|%s:%d|empty rationale\n' "$file" "$line_num"
        FAIL=$((FAIL + 1))
        continue
      fi

      # Check if text contains URL or arXiv ID
      if [[ $text =~ https?://|arXiv: ]]; then
        printf 'ERROR|rule-c-prime|%s:%d|rationale contains URL or arXiv ID\n' "$file" "$line_num"
        FAIL=$((FAIL + 1))
      fi
    fi
  done < "$file"

  return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# RULE (d): Unindexed reference (core/references/ only)
# File set: find "$REFERENCES_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'README.md'
# Non-firing: core/knowledge/ files excluded, .gitkeep excluded, README.md excluded
# ──────────────────────────────────────────────────────────────────────────────

check_rule_d() {
  # Get the set of .md files in core/references/ (depth 1, excluding README.md)
  local indexed_files="$REFERENCES_DIR/README.md"

  if ! [ -f "$indexed_files" ]; then
    return 0
  fi

  # Extract the list of indexed files from the "Files indexed" section
  local in_indexed_section=0
  local -a indexed_names

  while IFS= read -r line; do
    if [[ $line =~ ^##[[:space:]]+Files\ indexed ]]; then
      in_indexed_section=1
      continue
    fi

    if [ $in_indexed_section -eq 1 ]; then
      # Stop if we hit another section
      if [[ $line =~ ^##[^#] ]]; then
        break
      fi

      # Extract link text: [filename](./filename)
      # Parse using parameter expansion instead of regex to avoid bash nesting issues
      if [[ "$line" == *"["*"]("*")"* ]]; then
        # Extract filename from pattern like [name](./file.md)
        local link_part="${line#*\(./}"
        link_part="${link_part%%)}"
        indexed_names+=("$link_part")
      fi
    fi
  done < "$indexed_files"

  # Check all .md files (depth 1, excluding README.md)
  while IFS= read -r file; do
    local basename="$(basename "$file")"
    local found=0

    for idx_name in "${indexed_names[@]}"; do
      if [ "$basename" = "$idx_name" ]; then
        found=1
        break
      fi
    done

    if [ $found -eq 0 ]; then
      printf 'ERROR|rule-d|%s|not indexed in references/README.md\n' "$file"
      FAIL=$((FAIL + 1))
    fi
  done < <(find "$REFERENCES_DIR" -maxdepth 1 -type f -name '*.md' ! -name 'README.md')

  return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────

# Check knowledge files: rules (a), (b), (c), (c')
if [ -d "$KNOWLEDGE_DIR" ]; then
  while IFS= read -r file; do
    check_rule_a "$file" || true
    check_rule_b "$file" || true
    check_rule_c "$file" || true
    check_rule_c_prime "$file" || true
  done < <(find "$KNOWLEDGE_DIR" -maxdepth 1 -type f -name '*.md')
fi

# Check reference files: rule (d)
if [ -d "$REFERENCES_DIR" ]; then
  check_rule_d
fi

# Exit with appropriate code
if [ $FAIL -gt 0 ]; then
  exit 1
fi

exit 0
