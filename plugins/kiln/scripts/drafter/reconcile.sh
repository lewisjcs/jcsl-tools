#!/bin/bash
# Subtask reconcile — decide create/update/orphan/noop per planned task vs current Jira children.
# Usage: reconcile.sh <plan.json> <children.json> <ledger-map.json|none>
# Exit: 0 on successful reconciliation (any decision mix); 2 on missing/unparseable input.
set -uo pipefail
if [ "$#" -lt 3 ]; then echo "usage: reconcile.sh <plan.json> <children.json> <ledger-map.json|none>" >&2; exit 2; fi
PLAN="$1"; CHILDREN="$2"; LEDGER="$3"

# Validate + normalize an input file; fail LOUDLY (exit 2) on missing/unparseable — never mask.
norm_file() {
  [ -f "$1" ] || { echo "reconcile: no such file: $1" >&2; exit 2; }
  jq 'map(.title |= (ascii_downcase | gsub("^\\s+|\\s+$";"")))' < "$1" 2>/dev/null \
    || { echo "reconcile: unparseable JSON: $1" >&2; exit 2; }
}
plan_n=$(norm_file "$PLAN") || exit 2
child_n=$(norm_file "$CHILDREN") || exit 2

if [ "$LEDGER" = "none" ]; then
  # No-ledger path: create-missing-only, never update.
  jq -n --argjson plan "$plan_n" --argjson children "$child_n" '
    ($children | map(.title)) as $ctitles
    | [ $plan[] | if (.title as $t | $ctitles | index($t)) then
          {action:"noop", title:.title, jira_key:null}
        else {action:"create", title:.title, jira_key:null} end ]
    + [ $children[] | select(.title as $t | ($plan | map(.title) | index($t)) | not)
        | {action:"orphan", title:.title, jira_key:.key} ]'
else
  # With-ledger path: a bad ledger is a caller error — exit 2, do NOT degrade to empty (that would
  # silently turn every update into a create). norm_file handles missing/unparseable.
  ledger_n=$(norm_file "$LEDGER") || exit 2
  # mapped→update-candidate; the agent body-compares before writing (no-delta→noop is Task 3's ledger.sh diff).
  jq -n --argjson plan "$plan_n" --argjson children "$child_n" --argjson ledger "$ledger_n" '
    ($ledger | map({(.title): .jira_key}) | add // {}) as $map
    | ($children | map(.title)) as $ctitles
    | [ $plan[] | if ($map[.title]) then {action:"update", title:.title, jira_key:$map[.title]}
        else {action:"create", title:.title, jira_key:null} end ]
    + [ $children[] | select(.title as $t | ($plan | map(.title) | index($t)) | not)
        | {action:"orphan", title:.title, jira_key:.key} ]'
fi
exit 0
