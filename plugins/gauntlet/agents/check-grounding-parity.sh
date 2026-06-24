#!/usr/bin/env bash
# check-grounding-parity.sh
# Verifies that GROUNDING-CONTRACT:START / GROUNDING-CONTRACT:END sentinel block
# is present and byte-identical across all 10 finder/validator agent files.
# Exit 0 = parity confirmed. Exit non-zero = failure with diff.

set -euo pipefail

# Portable SHA-256: shasum (macOS) or sha256sum (Linux). Both print
# "<hash>  <file>", so the downstream `awk '{print $1}'` works for either.
if command -v shasum >/dev/null 2>&1; then
  SHA_CMD="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD="sha256sum"
else
  echo "FAIL: neither shasum nor sha256sum found on PATH" >&2
  exit 1
fi

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"

FILES=(
  "$AGENTS_DIR/adversarial-finder.md"
  "$AGENTS_DIR/adversarial-validator.md"
  "$AGENTS_DIR/directive-finder.md"
  "$AGENTS_DIR/directive-validator.md"
  "$AGENTS_DIR/doc-finder.md"
  "$AGENTS_DIR/doc-validator.md"
  "$AGENTS_DIR/plan-finder.md"
  "$AGENTS_DIR/plan-validator.md"
  "$AGENTS_DIR/security-finder.md"
  "$AGENTS_DIR/security-validator.md"
)

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

missing=()
hashes=()

for f in "${FILES[@]}"; do
  name="$(basename "$f")"

  # Check markers are present
  if ! grep -q 'GROUNDING-CONTRACT:START' "$f"; then
    missing+=("$name (missing START marker)")
    continue
  fi
  if ! grep -q 'GROUNDING-CONTRACT:END' "$f"; then
    missing+=("$name (missing END marker)")
    continue
  fi

  # Extract the block (inclusive of sentinel lines) into a temp file
  extracted="$TMPDIR_WORK/$name.block"
  awk '/<!-- GROUNDING-CONTRACT:START/{found=1} found{print} /GROUNDING-CONTRACT:END -->/{found=0}' "$f" > "$extracted"

  # Hash the extracted block
  hash="$($SHA_CMD "$extracted" | awk '{print $1}')"
  hashes+=("$hash $name")
done

# Report missing markers
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "FAIL: GROUNDING-CONTRACT markers absent in ${#missing[@]} file(s):"
  for m in "${missing[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

# Assert one unique hash across all 10
unique_hashes="$(printf '%s\n' "${hashes[@]}" | awk '{print $1}' | sort -u)"
unique_count="$(printf '%s\n' "$unique_hashes" | wc -l | tr -d ' ')"

if [[ "$unique_count" -ne 1 ]]; then
  echo "FAIL: GROUNDING-CONTRACT block is NOT byte-identical across all 10 files ($unique_count distinct hashes found)."
  echo ""
  echo "Per-file hashes:"
  printf '  %s\n' "${hashes[@]}"
  echo ""
  echo "Diff (first diverging pair):"
  first_file=""
  for f in "${FILES[@]}"; do
    name="$(basename "$f")"
    extracted="$TMPDIR_WORK/$name.block"
    if [[ -z "$first_file" ]]; then
      first_file="$extracted"
      first_name="$name"
    else
      if ! diff -u "$first_file" "$extracted" > /dev/null 2>&1; then
        echo "--- $first_name"
        echo "+++ $name"
        diff -u "$first_file" "$extracted" || true
        break
      fi
    fi
  done
  exit 1
fi

echo "OK: GROUNDING-CONTRACT block present and byte-identical in all ${#FILES[@]} files."
echo "    SHA-256: $unique_hashes"

# ---------------------------------------------------------------------------
# FINDER-GROUNDING block check: present + byte-identical across the 5 finders
# ---------------------------------------------------------------------------

FINDER_FILES=(
  "$AGENTS_DIR/adversarial-finder.md"
  "$AGENTS_DIR/directive-finder.md"
  "$AGENTS_DIR/doc-finder.md"
  "$AGENTS_DIR/plan-finder.md"
  "$AGENTS_DIR/security-finder.md"
)

finder_missing=()
finder_hashes=()

for f in "${FINDER_FILES[@]}"; do
  name="$(basename "$f")"

  if ! grep -q 'FINDER-GROUNDING:START' "$f"; then
    finder_missing+=("$name (missing FINDER-GROUNDING:START marker)")
    continue
  fi
  if ! grep -q 'FINDER-GROUNDING:END' "$f"; then
    finder_missing+=("$name (missing FINDER-GROUNDING:END marker)")
    continue
  fi

  extracted="$TMPDIR_WORK/$name.finder.block"
  awk '/<!-- FINDER-GROUNDING:START/{found=1} found{print} /FINDER-GROUNDING:END -->/{found=0}' "$f" > "$extracted"

  hash="$($SHA_CMD "$extracted" | awk '{print $1}')"
  finder_hashes+=("$hash $name")
done

if [[ ${#finder_missing[@]} -gt 0 ]]; then
  echo "FAIL: FINDER-GROUNDING markers absent in ${#finder_missing[@]} finder file(s):"
  for m in "${finder_missing[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

finder_unique_hashes="$(printf '%s\n' "${finder_hashes[@]}" | awk '{print $1}' | sort -u)"
finder_unique_count="$(printf '%s\n' "$finder_unique_hashes" | wc -l | tr -d ' ')"

if [[ "$finder_unique_count" -ne 1 ]]; then
  echo "FAIL: FINDER-GROUNDING block is NOT byte-identical across all 5 finder files ($finder_unique_count distinct hashes found)."
  echo ""
  echo "Per-file hashes:"
  printf '  %s\n' "${finder_hashes[@]}"
  echo ""
  echo "Diff (first diverging pair):"
  first_file=""
  for f in "${FINDER_FILES[@]}"; do
    name="$(basename "$f")"
    extracted="$TMPDIR_WORK/$name.finder.block"
    if [[ -z "$first_file" ]]; then
      first_file="$extracted"
      first_name="$name"
    else
      if ! diff -u "$first_file" "$extracted" > /dev/null 2>&1; then
        echo "--- $first_name"
        echo "+++ $name"
        diff -u "$first_file" "$extracted" || true
        break
      fi
    fi
  done
  exit 1
fi

echo "OK: FINDER-GROUNDING block present and byte-identical in all ${#FINDER_FILES[@]} finder files."
echo "    SHA-256: $finder_unique_hashes"

# ---------------------------------------------------------------------------
# VALIDATOR-GROUNDING block check: present + byte-identical across the 5 validators
# ---------------------------------------------------------------------------

VALIDATOR_FILES=(
  "$AGENTS_DIR/adversarial-validator.md"
  "$AGENTS_DIR/directive-validator.md"
  "$AGENTS_DIR/doc-validator.md"
  "$AGENTS_DIR/plan-validator.md"
  "$AGENTS_DIR/security-validator.md"
)

validator_missing=()
validator_hashes=()

for f in "${VALIDATOR_FILES[@]}"; do
  name="$(basename "$f")"

  if ! grep -q 'VALIDATOR-GROUNDING:START' "$f"; then
    validator_missing+=("$name (missing VALIDATOR-GROUNDING:START marker)")
    continue
  fi
  if ! grep -q 'VALIDATOR-GROUNDING:END' "$f"; then
    validator_missing+=("$name (missing VALIDATOR-GROUNDING:END marker)")
    continue
  fi

  extracted="$TMPDIR_WORK/$name.validator.block"
  awk '/<!-- VALIDATOR-GROUNDING:START/{found=1} found{print} /VALIDATOR-GROUNDING:END -->/{found=0}' "$f" > "$extracted"

  hash="$($SHA_CMD "$extracted" | awk '{print $1}')"
  validator_hashes+=("$hash $name")
done

if [[ ${#validator_missing[@]} -gt 0 ]]; then
  echo "FAIL: VALIDATOR-GROUNDING markers absent in ${#validator_missing[@]} validator file(s):"
  for m in "${validator_missing[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

validator_unique_hashes="$(printf '%s\n' "${validator_hashes[@]}" | awk '{print $1}' | sort -u)"
validator_unique_count="$(printf '%s\n' "$validator_unique_hashes" | wc -l | tr -d ' ')"

if [[ "$validator_unique_count" -ne 1 ]]; then
  echo "FAIL: VALIDATOR-GROUNDING block is NOT byte-identical across all 5 validator files ($validator_unique_count distinct hashes found)."
  echo ""
  echo "Per-file hashes:"
  printf '  %s\n' "${validator_hashes[@]}"
  echo ""
  echo "Diff (first diverging pair):"
  first_file=""
  for f in "${VALIDATOR_FILES[@]}"; do
    name="$(basename "$f")"
    extracted="$TMPDIR_WORK/$name.validator.block"
    if [[ -z "$first_file" ]]; then
      first_file="$extracted"
      first_name="$name"
    else
      if ! diff -u "$first_file" "$extracted" > /dev/null 2>&1; then
        echo "--- $first_name"
        echo "+++ $name"
        diff -u "$first_file" "$extracted" || true
        break
      fi
    fi
  done
  exit 1
fi

echo "OK: VALIDATOR-GROUNDING block present and byte-identical in all ${#VALIDATOR_FILES[@]} validator files."
echo "    SHA-256: $validator_unique_hashes"
