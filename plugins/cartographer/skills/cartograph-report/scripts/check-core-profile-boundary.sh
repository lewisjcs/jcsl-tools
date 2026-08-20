#!/bin/bash
# Core-profile boundary checker — RC-7 textual dependency enforcement.
# Flags lines in core/ containing "profiles/" unless they carry the exemption token.
# The exemption token: <!-- boundary-exempt: prose --> (trailing, outside fences only).
# Run: bash check-core-profile-boundary.sh [PLUGIN_ROOT]
# Default PLUGIN_ROOT: <dir of this script>/..

set -u

# Derive PLUGIN_ROOT from argument or default; explicit argument wins over env
if [ -n "${1:-}" ]; then
  PLUGIN_ROOT="$1"
else
  PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  # Only use CLAUDE_PLUGIN_ROOT as override if no explicit argument was given
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
  fi
fi

CORE_DIR="$PLUGIN_ROOT/core"
FAIL=0
INFO=0

# ──────────────────────────────────────────────────────────────────────────────
# Check boundary for a single file
# ──────────────────────────────────────────────────────────────────────────────

check_file() {
  local file="$1"
  local line_num=0
  local fence_state=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Track fence state
    if [[ $line =~ ^[[:space:]]*\`{3,}|^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
    fi

    # Check if line contains "profiles/"
    if [[ $line =~ profiles/ ]]; then
      # Check if exemption token is present
      local has_token=0
      if [[ $line =~ \<\!--[[:space:]]*boundary-exempt:[[:space:]]*prose[[:space:]]*--\> ]]; then
        has_token=1
      fi

      # If in fence, never exempt
      if [ $fence_state -ne 0 ]; then
        printf 'ERROR|boundary|%s:%d|profiles/ inside fenced block\n' "$file" "$line_num"
        FAIL=$((FAIL + 1))
      elif [ $has_token -eq 1 ]; then
        # Token present, outside fence — exempted
        printf 'INFO|boundary-exempt|%s:%d\n' "$file" "$line_num"
        INFO=$((INFO + 1))
      else
        # profiles/ found, no token, outside fence — error
        printf 'ERROR|boundary|%s:%d|profiles/ without exemption token\n' "$file" "$line_num"
        FAIL=$((FAIL + 1))
      fi
    fi

    # Check if exemption token appears inside a fence (always an error)
    if [ $fence_state -ne 0 ]; then
      if [[ $line =~ \<\!--[[:space:]]*boundary-exempt:[[:space:]]*prose[[:space:]]*--\> ]]; then
        printf 'ERROR|boundary|%s:%d|exemption token inside fenced block\n' "$file" "$line_num"
        FAIL=$((FAIL + 1))
      fi
    fi
  done < "$file"

  return 0
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────

# Check all files in core/ (recursively)
if [ -d "$CORE_DIR" ]; then
  while IFS= read -r file; do
    check_file "$file" || true
  done < <(find "$CORE_DIR" -type f -name '*.md')
fi

# Exit with appropriate code
if [ $FAIL -gt 0 ]; then
  exit 1
fi

exit 0
