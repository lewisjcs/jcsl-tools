#!/bin/bash
# Portability guard — the skill root must carry no harness-specific token.
# The skill root is the shipped unit (SKILL.md + core/ + scripts/); a copy
# of it must work with no environment variable, no plugin-cache path, and
# no Claude-Code-only API name. This is a token grep, not a semantic
# proof: a differently-phrased harness-specific reference slips past.
# Tokens:
#   CLAUDE_PLUGIN_ROOT   — plugin-cache env var; text substitution does
#                          not exist in a vendored copy
#   plugins/cartographer/ — repo-relative self-reference; wrong once the
#                          skill root is copied out of this repo
#   Task-tool / Task tool — Claude Code dispatch API name; a Codex
#                          executor cannot follow it (dispatch naming is
#                          harness-neutral per core/dispatch-contract.md)
#   /Users/, $HOME, ${HOME}, ~/ — absolute/home paths
# Run: bash check-portability.sh [SKILL_ROOT]
set -u

if [ -n "${1:-}" ]; then
  SKILL_ROOT="$1"
else
  SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/cartograph-report" && pwd)"
fi

FAIL=0
scan() {
  local pattern="$1" label="$2"
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    printf 'ERROR|portability|%s|%s\n' "$hit" "$label"
    FAIL=$((FAIL + 1))
  done < <(grep -rn -E "$pattern" "$SKILL_ROOT" | cut -d'|' -f1 | sed "s|^$SKILL_ROOT/||" | cut -d: -f1,2)
}

scan 'CLAUDE_PLUGIN_ROOT'        'CLAUDE_PLUGIN_ROOT'
scan 'plugins/cartographer/'     'plugins/cartographer/'
scan 'Task[- ]tool'              'Task-tool'
scan '/Users/'                   'absolute path /Users/'
scan '\$\{?HOME\}?'              '$HOME'
scan '(^|[[:space:](`"])~/'      'home-relative path ~/'

if [ $FAIL -gt 0 ]; then
  printf 'SUMMARY|portability|errors=%d\n' "$FAIL"
  exit 1
fi
printf 'SUMMARY|portability|errors=0\n'
exit 0
