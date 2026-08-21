#!/bin/bash
# Test suite for tools/promote.sh — the promotion copy + provenance script.
# Proves: parity-set copy, provenance fields, determinism (second run
# zero-diff), drift detection (hand-edit caught by re-run + diff),
# profile/ and package.json never touched, dirty-tree refusal.
# Run: bash promote.test.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMOTE="$SCRIPT_DIR/../tools/promote.sh"
SKILL_ROOT="$(cd "$SCRIPT_DIR/../skills/cartograph-report" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()   { printf '  ok   — %s\n' "$1"; PASS=$((PASS + 1)); }
bad()  { printf '  FAIL — %s\n' "$1"; FAIL=$((FAIL + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected $2, got $3)"; fi; }

# ── usage error
bash "$PROMOTE" > /dev/null 2>&1
check "no argument exits 2" "2" "$?"

# ── first promotion into a target that already has work-side files
mkdir -p "$TMP/target/profile"
printf 'work-side content\n' > "$TMP/target/profile/evidence-sources.md"
printf '{"name":"x","version":"1.0.0"}\n' > "$TMP/target/package.json"
bash "$PROMOTE" "$TMP/target" > /dev/null 2>&1
check "promotion exits 0" "0" "$?"
[ -f "$TMP/target/SKILL.md" ] && [ -d "$TMP/target/core" ] && [ -d "$TMP/target/scripts" ] \
  && ok "parity set copied" || bad "parity set copied"

# ── provenance fields
HEAD_COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
grep -q "^- commit: $HEAD_COMMIT$" "$TMP/target/PROVENANCE.md" \
  && ok "PROVENANCE records the current commit" || bad "PROVENANCE records the current commit"
grep -q '^- repo: ' "$TMP/target/PROVENANCE.md" \
  && ok "PROVENANCE records the source repo" || bad "PROVENANCE records the source repo"
grep -qE '^- date: [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$TMP/target/PROVENANCE.md" \
  && ok "PROVENANCE records the date" || bad "PROVENANCE records the date"

# ── never touches profile/ or package.json
check "profile/ untouched" "work-side content" "$(cat "$TMP/target/profile/evidence-sources.md")"
check "package.json untouched" '{"name":"x","version":"1.0.0"}' "$(cat "$TMP/target/package.json")"

# ── determinism: two runs, parity set byte-identical
bash "$PROMOTE" "$TMP/t1" > /dev/null 2>&1
bash "$PROMOTE" "$TMP/t2" > /dev/null 2>&1
if diff -r "$TMP/t1/core" "$TMP/t2/core" > /dev/null \
   && diff -r "$TMP/t1/scripts" "$TMP/t2/scripts" > /dev/null \
   && diff "$TMP/t1/SKILL.md" "$TMP/t2/SKILL.md" > /dev/null; then
  ok "deterministic: two runs produce identical parity bytes"
else
  bad "deterministic: two runs produce identical parity bytes"
fi

# ── drift detection: a hand-edit to the target shows up against a fresh run
printf '\ndrifted line\n' >> "$TMP/t1/core/pipeline.md"
if diff -r "$TMP/t1/core" "$TMP/t2/core" > /dev/null; then
  bad "drift: hand-edit is visible in the parity diff"
else
  ok "drift: hand-edit is visible in the parity diff"
fi
bash "$PROMOTE" "$TMP/t1" > /dev/null 2>&1
diff -r "$TMP/t1/core" "$TMP/t2/core" > /dev/null \
  && ok "drift: re-promotion restores the parity set" || bad "drift: re-promotion restores the parity set"

# ── dirty skill root refusal (in a local clone, so the real repo is untouched)
git clone -q "$REPO_ROOT" "$TMP/clone" 2>/dev/null
CLONE_PROMOTE="$TMP/clone/plugins/cartographer/tools/promote.sh"
if [ -f "$CLONE_PROMOTE" ]; then
  printf '\n' >> "$TMP/clone/plugins/cartographer/skills/cartograph-report/SKILL.md"
  bash "$CLONE_PROMOTE" "$TMP/clone-target" > /dev/null 2>&1
  check "dirty skill root exits 2" "2" "$?"
else
  bad "dirty skill root exits 2 (promote.sh missing from clone — commit it first)"
fi

printf '\npromote.test.sh: PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ $FAIL -eq 0 ] || exit 1
exit 0
