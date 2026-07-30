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

# Emit "<target>\t<change>" for every status:dismissed record under <dir>/*.md.
cmd_list_dismissed() { # $1=dir
  local dir="$1" files f id
  [ -d "$dir" ] || return 0
  files="$(ls "$dir"/*.md 2>/dev/null || true)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # ids in this file: strip "## " from header lines
    grep -E '^## ' "$f" | sed 's/^## //' | while IFS= read -r id; do
      [ -n "$id" ] || continue
      if [ "$(cmd_get_field "$f" "$id" status)" = "dismissed" ]; then
        printf '%s\t%s\n' "$(cmd_get_field "$f" "$id" target)" "$(cmd_get_field "$f" "$id" change)"
      fi
    done
  done <<EOF
$files
EOF
}

case "${1:-}" in
  get-field) shift; cmd_get_field "$@" ;;
  list-dismissed) shift; cmd_list_dismissed "$@" ;;
  *) echo "usage: smith-suggestions.sh {get-field <file> <id> <field>|list-dismissed <dir>}" >&2; exit 2 ;;
esac
