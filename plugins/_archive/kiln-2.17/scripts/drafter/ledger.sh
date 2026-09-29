#!/bin/bash
# Drafter run-folder ledger — stores description hash + subtask id map for
# fingerprint-free identity and change-detection. Usage:
#   ledger.sh write <ledger> <ticket-key> <desc-file> <subtask-map-json>
#   ledger.sh desc-changed <ledger> <candidate-desc-file>   (exit 0=changed, 1=same)
#   ledger.sh subtask-map <ledger>
# Exit: 0 success / 1 (desc-changed: identical) / 2 bad usage or missing/unparseable input.
set -uo pipefail
if [ "$#" -lt 1 ]; then echo "usage: ledger.sh write|desc-changed|subtask-map ..." >&2; exit 2; fi
cmd="$1"; shift

hash_of() {
  [ -f "$1" ] || { echo "ledger: no such file: $1" >&2; exit 2; }
  shasum -a 256 "$1" | awk '{print $1}'
}
# subtask_map is stored as ONE compact line; get_field reads that whole line back.
get_field() { grep -m1 "^$1: " "$2" 2>/dev/null | sed "s/^$1: //"; }

case "$cmd" in
  write)
    if [ "$#" -lt 4 ]; then echo "usage: ledger.sh write <ledger> <key> <desc-file> <map-json>" >&2; exit 2; fi
    LGR="$1"; KEY="$2"; DESC="$3"; MAP="$4"
    # Normalize the map to compact single-line JSON so a pretty-printed caller (reconcile.sh
    # emits non-compact jq output) round-trips through the single-line store without truncation.
    MAP_C="$(printf '%s' "$MAP" | jq -c '.')" \
      || { echo "ledger: unparseable subtask-map JSON" >&2; exit 2; }
    DHASH="$(hash_of "$DESC")" || exit 2   # propagate hash_of's subshell exit (Task 2 lesson)
    {
      echo "ticket_key: $KEY"
      echo "description_hash: $DHASH"
      echo "subtask_map: $MAP_C"
    } > "$LGR"
    ;;
  desc-changed)
    if [ "$#" -lt 2 ]; then echo "usage: ledger.sh desc-changed <ledger> <candidate-file>" >&2; exit 2; fi
    LGR="$1"; CAND="$2"
    [ -f "$LGR" ] || exit 0   # no ledger → treat as changed
    stored="$(get_field description_hash "$LGR")"
    cand="$(hash_of "$CAND")" || exit 2
    [ "$stored" = "$cand" ] && exit 1 || exit 0
    ;;
  subtask-map)
    if [ "$#" -lt 1 ]; then echo "usage: ledger.sh subtask-map <ledger>" >&2; exit 2; fi
    LGR="$1"
    [ -f "$LGR" ] && get_field subtask_map "$LGR" || echo "[]"
    ;;
  *) echo "unknown subcommand: $cmd" >&2; exit 2 ;;
esac
