#!/usr/bin/env bash
# check-grounding-parity.sh
# Verifies that GROUNDING-CONTRACT:START / GROUNDING-CONTRACT:END sentinel block
# is present and byte-identical across all 10 finder/validator agent files.
# Exit 0 = parity confirmed. Exit non-zero = failure with diff.

set -euo pipefail

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
  hash="$(shasum -a 256 "$extracted" | awk '{print $1}')"
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
