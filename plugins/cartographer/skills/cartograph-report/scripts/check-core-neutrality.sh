#!/bin/bash
# Core-neutrality checker — the parity set (SKILL.md + core/ + scripts/)
# must ship org-neutral. Two rules:
#   1. No org-specific token anywhere in the parity set (case-insensitive):
#      Contentful, Glean, Backstage. Org content belongs work-side, behind
#      the profile/ seam — never in the promoted core.
#   2. No `profile/` path reference outside the two licensed files:
#      core/profile-contract.md (the seam's contract) and SKILL.md (the
#      Step 0 loading rule). File-level licensing — a grep cannot see
#      sections; the profile-content review gate covers the rest.
# This file excludes itself from rule 1 (its own token list would trip it).
# A token grep, not a semantic proof: differently-phrased org references
# slip past. It runs at runtime as a tamper/drift tripwire for vendored
# copies, and in the test suite.
# Run: bash check-core-neutrality.sh [SKILL_ROOT]
set -u

if [ -n "${1:-}" ]; then
  SKILL_ROOT="$1"
else
  SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

SELF_NAME="$(basename "${BASH_SOURCE[0]}")"
FAIL=0

emit() { printf 'ERROR|neutrality|%s|%s\n' "$1" "$2"; FAIL=$((FAIL + 1)); }

# Rule 1 — org tokens, parity set minus this script
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  emit "$hit" 'org-specific token'
done < <(
  { [ -f "$SKILL_ROOT/SKILL.md" ] && grep -Hin -E 'contentful|glean|backstage' "$SKILL_ROOT/SKILL.md";
    [ -d "$SKILL_ROOT/core" ]     && grep -rin -E 'contentful|glean|backstage' "$SKILL_ROOT/core";
    [ -d "$SKILL_ROOT/scripts" ]  && grep -rin -E 'contentful|glean|backstage' "$SKILL_ROOT/scripts" \
        --exclude="$SELF_NAME"; } \
  | sed "s|^$SKILL_ROOT/||" | cut -d: -f1,2
)

# Rule 2 — profile/ references outside the licensed files
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  case "$hit" in
    SKILL.md:*|core/profile-contract.md:*) ;;  # licensed
    *) emit "$hit" 'profile/ reference outside licensed files' ;;
  esac
done < <(
  { [ -f "$SKILL_ROOT/SKILL.md" ] && grep -Hn 'profile/' "$SKILL_ROOT/SKILL.md";
    [ -d "$SKILL_ROOT/core" ]     && grep -rn 'profile/' "$SKILL_ROOT/core";
    [ -d "$SKILL_ROOT/scripts" ]  && grep -rn 'profile/' "$SKILL_ROOT/scripts" \
        --exclude="$SELF_NAME"; } \
  | sed "s|^$SKILL_ROOT/||" | cut -d: -f1,2
)

if [ $FAIL -gt 0 ]; then
  printf 'SUMMARY|neutrality|errors=%d\n' "$FAIL"
  exit 1
fi
printf 'SUMMARY|neutrality|errors=0\n'
exit 0
