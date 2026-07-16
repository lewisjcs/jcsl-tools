#!/bin/bash
# Subtask reconcile — decide create/update/orphan/noop per planned task vs current Jira children.
# Usage: reconcile.sh <plan.json> <children.json> <ledger-map.json|none>
set -uo pipefail
PLAN="${1:?plan.json}"; CHILDREN="${2:?children.json}"; LEDGER="${3:?ledger-map.json|none}"

norm() { jq 'map(.title |= (ascii_downcase | gsub("^\\s+|\\s+$";"")))'; }
plan_n=$(norm < "$PLAN")
child_n=$(norm < "$CHILDREN")

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
  ledger_n=$(norm < "$LEDGER" 2>/dev/null || echo '[]')
  # jq handles: mapped+changed→update handled by the agent (body compare); here mapped→update-candidate.
  jq -n --argjson plan "$plan_n" --argjson children "$child_n" --argjson ledger "$ledger_n" '
    ($ledger | map({(.title): .jira_key}) | add // {}) as $map
    | ($children | map(.title)) as $ctitles
    | [ $plan[] | if ($map[.title]) then {action:"update", title:.title, jira_key:$map[.title]}
        else {action:"create", title:.title, jira_key:null} end ]
    + [ $children[] | select(.title as $t | ($plan | map(.title) | index($t)) | not)
        | {action:"orphan", title:.title, jira_key:.key} ]'
fi
exit 0
