#!/bin/bash
# EARS anti-pattern linter — greps a markdown file's AC bullets against the
# Designer's ears.md checklist. Exit 1 on any finding, 0 if clean.
# Usage: ears-lint.sh <markdown-file>
set -uo pipefail
if [ "$#" -lt 1 ]; then
  echo "usage: ears-lint.sh <markdown-file>" >&2
  exit 2
fi
FILE="${1:?usage: ears-lint.sh <markdown-file>}"
[ -f "$FILE" ] || { echo "ears-lint: no such file: $FILE" >&2; exit 2; }

findings=0
emit() { echo "LINE:$1:$2:$3"; findings=$((findings+1)); }

# Only lint requirement-bearing lines (bullets or lines containing "shall").
while IFS= read -r line; do
  n="${line%%:*}"; text="${line#*:}"
  # vague response
  echo "$text" | grep -qiE '\b(appropriately|correctly|properly|as needed)\b' && emit "$n" vague-response "$text"
  # compound shall (two 'shall' in one requirement)
  [ "$(echo "$text" | grep -oiE '\bshall\b' | wc -l | tr -d ' ')" -ge 2 ] && emit "$n" compound-shall "$text"
  # non-trigger
  echo "$text" | grep -qiE 'when needed|if necessary|where appropriate' && emit "$n" non-trigger "$text"
  # 'When' used on an error/invalid/fail path (should be If...then) — checked only in the
  # trigger clause (before the first 'shall'), so a correct shall-clause mentioning "error"
  # (e.g. "the system shall return an error code") doesn't false-positive.
  trigger=$(echo "$text" | sed 's/[Ss][Hh][Aa][Ll][Ll].*//')
  echo "$trigger" | grep -qiE '\bwhen\b.*\b(invalid|error|failure|denied|reject|fail)\b' && emit "$n" when-on-error "$text"
  # passive 'is <verb>ed by the system' (no active system subject)
  echo "$text" | grep -qiE '\bis\b.*\bby the system\b' && emit "$n" passive-voice "$text"
  # solution-in-requirement: shall-clause prescribes a mechanism instead of a behavior
  echo "$text" | grep -qiE '\bshall\b.*\b(using|via|by means of|through|leveraging)\b' && emit "$n" solution-in-requirement "$text"
done < <(grep -nE '(^\s*[-*]\s)|(\bshall\b)' "$FILE")

if [ "$findings" -gt 0 ]; then exit 1; fi
exit 0
