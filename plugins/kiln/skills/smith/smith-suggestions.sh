#!/usr/bin/env bash
# The Smith — durable suggestions-file state machine. Deterministic; no LLM judgment.
# Reads/writes projects/active/kiln-smith/smith-suggestions/YYYY-MM-DD.md records.
# Bash-3.2-safe. Fail-open reads (empty on absence), fail-loud writes.
set -uo pipefail

# Print the value of `- <field>: ` within the `## <id>` section of a file.
# Empty string if the id or field is absent. awk state machine: enter on the
# matching `## <id>` header, exit on the next `## ` header.
cmd_get_field() { # $1=file $2=id $3=field
  local f="$1" id="$2" field="$3"
  [ -r "$f" ] || { printf '%s' ""; return 0; }
  awk -v id="## $id" -v key="- $field:" '
    $0 == id { inb=1; next }
    inb && /^## / { inb=0 }
    inb && index($0, key) == 1 {
      sub(/^- [^:]*:[[:space:]]*/, "", $0); print; exit
    }
  ' "$f"
}

case "${1:-}" in
  get-field) shift; cmd_get_field "$@" ;;
  *) echo "usage: smith-suggestions.sh {get-field <file> <id> <field>}" >&2; exit 2 ;;
esac
