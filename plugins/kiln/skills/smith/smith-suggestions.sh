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

# Exit 0 (duplicate — do NOT re-emit) if any record in <dir>/*.md has the same
# (target, change), in ANY status. Dismissed records are included on purpose: a
# dismissed suggestion is suppressed, not resurfaced. Exit 1 if genuinely new.
#
# Implementation note: the natural `while read id; do ... done` inner loop runs
# in a subshell under bash 3.2 (piped from `grep | sed`), so an `exit`/`return`
# inside it cannot propagate a verdict to this function directly. Instead, the
# inner loop appends a hit line to a mktemp file (same pattern cmd_majority
# uses in smith-eval-gate.sh); we check that file's non-emptiness after the
# loop exits, which reliably crosses the subshell boundary via the filesystem.
cmd_is_duplicate() { # $1=dir $2=target $3=change
  local dir="$1" target="$2" change="$3" files f id hit
  [ -d "$dir" ] || return 1
  hit="$(mktemp)"
  files="$(ls "$dir"/*.md 2>/dev/null || true)"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -E '^## ' "$f" | sed 's/^## //' | while IFS= read -r id; do
      [ -n "$id" ] || continue
      if [ "$(cmd_get_field "$f" "$id" target)" = "$target" ] \
         && [ "$(cmd_get_field "$f" "$id" change)" = "$change" ]; then
        echo "duplicate of $id (status: $(cmd_get_field "$f" "$id" status)) in $f" >> "$hit"
      fi
    done
  done <<EOF
$files
EOF
  if [ -s "$hit" ]; then
    cat "$hit" >&2
    rm -f "$hit"
    return 0
  fi
  rm -f "$hit"
  return 1
}

# Rewrite `- <field>: ...` within the `## <id>` section to the new value, in place.
# An empty field value (e.g. `- eval_verdict:`) is a VALID target — get-field
# returns "" for both a present-but-empty field and a genuinely absent one, so
# presence is checked separately via an awk probe that prints "Y" the moment
# it sees the `- <field>:` line inside the matching `## <id>` section. Only
# treat the id/field as absent if BOTH the value and the presence probe are empty.
cmd_set_status() { # $1=file $2=id $3=field $4=value
  local f="$1" id="$2" field="$3" value="$4" tmp
  [ -w "$f" ] || { echo "set-status: cannot write $f" >&2; return 2; }
  [ -n "$(cmd_get_field "$f" "$id" "$field")$(awk -v id="## $id" -v key="- $field:" '
      $0==id{inb=1;next} inb&&/^## /{inb=0} inb&&index($0,key)==1{print "Y";exit}' "$f")" ] \
    || { echo "set-status: no such id/field: $id/$field in $f" >&2; return 2; }
  tmp="$(mktemp)"
  awk -v id="## $id" -v key="- $field:" -v val="$value" '
    $0 == id { inb=1; print; next }
    inb && /^## / { inb=0 }
    inb && index($0, key) == 1 { print key " " val; next }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
}

case "${1:-}" in
  get-field) shift; cmd_get_field "$@" ;;
  list-dismissed) shift; cmd_list_dismissed "$@" ;;
  is-duplicate) shift; cmd_is_duplicate "$@" ;;
  set-status) shift; cmd_set_status "$@" ;;
  *) echo "usage: smith-suggestions.sh {get-field <file> <id> <field>|list-dismissed <dir>|is-duplicate <dir> <target> <change>|set-status <file> <id> <field> <value>}" >&2; exit 2 ;;
esac
