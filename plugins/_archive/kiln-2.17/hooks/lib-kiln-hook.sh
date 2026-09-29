#!/bin/bash
# Shared helpers for Kiln guard hooks. Sourced, not executed.
# Fail-open everywhere: any internal failure must allow the call (exit 0 / return non-deny).

# Declared default so a guard sourced under `set -u` never trips on an unbound
# KILN_INPUT if kiln_field is ever reached before kiln_read_input (a non-zero exit
# under set -u would be read as a deny — i.e. fail-CLOSED, the opposite of our posture).
KILN_INPUT=""

kiln_read_input() { KILN_INPUT=$(cat); }

kiln_field() { # $1 = jq path, e.g. .tool_input.file_path
  command -v jq >/dev/null 2>&1 || { echo ""; return 0; }
  printf '%s' "$KILN_INPUT" | jq -r "$1 // empty" 2>/dev/null || echo ""
}

# Lexically resolve `..`/`.`/duplicate-slash segments in an absolute path — a pure
# string operation, NOT an existence check (the target need not exist on disk).
# Required because PreToolUse hooks receive tool_input.file_path exactly as the model
# wrote it; a literal "../../repos/x" segment would otherwise dodge a repos/ glob despite
# lexically landing inside it. Deliberately NOT realpath/readlink -f (those hit the
# filesystem and differ macOS vs Linux; this must stay fail-open on a not-yet-existing path).
kiln_normalize_path() {
  local path="$1" part
  local -a out=()
  case "$path" in
    /*) : ;;
    *) printf '%s' "$path"; return 0 ;;   # relative — nothing to anchor traversal against; pass through
  esac
  local IFS='/'
  for part in $path; do
    case "$part" in
      ''|'.') continue ;;
      '..') [ ${#out[@]} -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$part") ;;
    esac
  done
  printf '/%s' "${out[*]:-}"
}

# Echo the path of the active run dir this call belongs to (a `.active` sentinel's
# `kiln/` dir), or empty when no run owns this call.
#
# Anchors on the OS WORKSPACE (where Claude Code was launched), NOT a git repo. This
# OS wraps many nested repos and launches from a non-git workspace root, so a
# `git rev-parse --show-toplevel` from the hook cwd resolves the wrong tree — or
# fails outright (exit 128) at the workspace root, leaving every guard fail-open.
# Run folders live at `<workspace>/projects/active/<key>/kiln/`. We probe every
# distinct candidate root — the payload's `.cwd` (session cwd), CLAUDE_PROJECT_DIR
# (project root, stable even if the session cd'd into a subrepo), and $PWD — keep
# only those that actually hold a `projects/active/` tree, and search them all so a
# session standing inside a nested repo still finds the workspace run folder.
#
# SESSION-SCOPED OWNERSHIP (concurrent runs, one window each): the `.active` sentinel
# carries its owning session_id on its first line (empty = legacy/unowned). Claude Code
# runs one Kiln run per session/window, so a call binds to the run OWNED by this call's
# payload `.session_id` — that isolates concurrent windows (session B never binds to
# session A's run) and stops a non-conducting session from binding to a foreign parked
# run (the false-deny that blocked unrelated main-thread work). Precedence:
#   1. A sentinel owned by THIS session_id → bind (newest among mine, defensively).
#   2. Else, if exactly ONE run exists and it is unowned/legacy → bind. Preserves the
#      resume path (`/clear` mints a new session_id, so the resumed run looks unowned
#      until the conductor re-stamps it) and pre-ownership sentinels. Requiring a SINGLE
#      run is load-bearing: with two runs present, an unowned one is NOT claimable by a
#      session that owns neither — that is the multi-run fail-open case.
#   3. Else (multiple runs, none mine) → empty. Fail-open: binding to someone else's run
#      is worse than not binding; the guards are a safety net, not a hard sandbox.
# `ls -t` orders by mtime (portable: macOS BSD `find` has no `-printf`) for the newest
# tie-break; `-exec … +` never runs `ls` on zero matches, so no stray output.
kiln_active_run_dir() {
  local r cand roots=()
  for r in "$(kiln_field '.cwd')" "${CLAUDE_PROJECT_DIR:-}" "$PWD"; do
    [ -n "$r" ] && [ -d "$r/projects/active" ] || continue
    cand="$r/projects/active"
    # Dedupe: the three signals usually coincide at hook runtime — without this,
    # `find` walks the same tree up to 3× and `ls -t` lists the sentinel as dupes.
    case " ${roots[*]-} " in *" $cand "*) continue ;; esac
    roots+=("$cand")
  done
  # Guard the array expansion: on macOS bash 3.2, "${roots[@]}" under `set -u`
  # errors when the array is empty — which would surface as a non-zero exit and
  # be misread as a deny (fail-CLOSED). No candidate root → allow.
  [ ${#roots[@]} -eq 0 ] && { echo ""; return 0; }

  local me; me=$(kiln_field '.session_id')
  # All sentinels newest-first, so the first owner-match is the newest of mine.
  local sentinels; sentinels=$(find "${roots[@]}" -maxdepth 3 -name ".active" -path "*/kiln/.active" \
    -exec ls -t {} + 2>/dev/null)
  [ -z "$sentinels" ] && { echo ""; return 0; }

  local s owner total=0 lone=""
  while IFS= read -r s; do
    [ -n "$s" ] || continue
    total=$((total + 1)); lone="$s"
    owner=$(head -n1 "$s" 2>/dev/null)
    # Precedence 1: a run owned by this session wins outright (newest-first order).
    if [ -n "$me" ] && [ "$owner" = "$me" ]; then dirname "$s"; return 0; fi
  done <<EOF
$sentinels
EOF

  # Precedence 2: exactly one run and it is unowned/legacy → bind (resume + back-compat).
  if [ "$total" -eq 1 ]; then
    owner=$(head -n1 "$lone" 2>/dev/null)
    [ -z "$owner" ] && { dirname "$lone"; return 0; }
  fi
  # Precedence 3: multiple runs, none owned by me → fail-open.
  echo ""
}

# Return 0 if this hook fired inside a subagent (agent_id present), else 1.
kiln_is_subagent() {
  local aid; aid=$(kiln_field '.agent_id')
  [ -n "$aid" ]
}

kiln_deny() { # $1 = reason
  # Build via jq so a reason containing quotes/backslashes can't corrupt the JSON.
  # jq is already a dependency (kiln_field). Fall back to raw printf if it is absent —
  # the lib is fail-open, and every current caller passes a static, quote-free reason.
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  fi
  exit 0
}
