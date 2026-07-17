#!/bin/bash
# Drafter run-folder ledger — stores description hash + subtask id map for
# fingerprint-free identity and change-detection. Usage:
#   ledger.sh write <ledger> <ticket-key> <desc-file> <subtask-map-json>
#   ledger.sh desc-changed <ledger> <candidate-desc-file>   (exit 0=changed, 1=same)
#   ledger.sh subtask-map <ledger>
set -uo pipefail
cmd="${1:?write|desc-changed|subtask-map}"; shift

hash_of() { shasum -a 256 "$1" | awk '{print $1}'; }
get_field() { grep -m1 "^$1: " "$2" 2>/dev/null | sed "s/^$1: //"; }

case "$cmd" in
  write)
    LGR="${1:?ledger}"; KEY="${2:?key}"; DESC="${3:?desc-file}"; MAP="${4:?map-json}"
    {
      echo "ticket_key: $KEY"
      echo "description_hash: $(hash_of "$DESC")"
      echo "subtask_map: $MAP"
    } > "$LGR"
    ;;
  desc-changed)
    LGR="${1:?ledger}"; CAND="${2:?candidate}"
    [ -f "$LGR" ] || exit 0   # no ledger → treat as changed
    stored="$(get_field description_hash "$LGR")"
    cand="$(hash_of "$CAND")"
    [ "$stored" = "$cand" ] && exit 1 || exit 0
    ;;
  subtask-map)
    LGR="${1:?ledger}"
    [ -f "$LGR" ] && get_field subtask_map "$LGR" || echo "[]"
    ;;
  *) echo "unknown subcommand: $cmd" >&2; exit 2 ;;
esac
