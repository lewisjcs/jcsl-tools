#!/bin/bash
# Promotion script — copies the skill root's parity set (SKILL.md,
# core/, scripts/) into a target directory and records provenance.
# Deterministic: the same source commit produces the same parity bytes,
# so this script doubles as the drift detector — check out the commit
# PROVENANCE.md records, run this into a scratch directory, and
# `diff -r` the three parity entries against the deployed copy. The
# diff covers the parity set only; PROVENANCE.md (which carries the
# promotion date) sits outside it by construction.
# Never touches anything else in the target — profile/, package.json,
# and any distribution extras are work-side property.
# Refuses a dirty skill root: provenance must name a commit whose bytes
# match what was copied.
# Usage: promote.sh <target-dir>
set -u

if [ -z "${1:-}" ]; then
  printf 'usage: promote.sh <target-dir>\n' >&2
  exit 2
fi
TARGET="$1"

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/cartograph-report" && pwd)"
REPO_ROOT="$(git -C "$SKILL_ROOT" rev-parse --show-toplevel)"

if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- "$SKILL_ROOT")" ]; then
  printf 'ERROR|promote|skill root has uncommitted changes — commit first; provenance must name a commit whose bytes match\n' >&2
  exit 2
fi

COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
REPO_URL="$(git -C "$REPO_ROOT" config --get remote.origin.url || printf 'unknown')"
DATE="$(date -u +%Y-%m-%d)"

mkdir -p "$TARGET"
rm -rf "$TARGET/SKILL.md" "$TARGET/core" "$TARGET/scripts"
cp "$SKILL_ROOT/SKILL.md" "$TARGET/SKILL.md"
cp -R "$SKILL_ROOT/core" "$TARGET/core"
cp -R "$SKILL_ROOT/scripts" "$TARGET/scripts"

cat > "$TARGET/PROVENANCE.md" << PROV
# PROVENANCE

Promoted from the cartographer skill root. Covers \`SKILL.md\`, \`core/\`,
and \`scripts/\` — byte-identical to the source skill root at the
recorded commit. \`profile/\` and \`package.json\` are never touched by
promotion.

- repo: $REPO_URL
- commit: $COMMIT
- date: $DATE

Drift check: check out the recorded commit in the source repo, run
\`tools/promote.sh\` into a scratch directory, and \`diff -r\` the three
covered entries against this copy. The diff must be empty; any
difference means a work-side edit that belongs upstream.
PROV

printf 'promoted %s @ %s -> %s\n' "$REPO_URL" "$COMMIT" "$TARGET"
exit 0
