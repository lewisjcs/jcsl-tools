#!/bin/bash
# Local validation for a drafted README patch — gates (a) link resolution,
# (b) command existence, (c) low-value section flagging, (d) managed-
# section marker-grammar (readme-ownership.md's <id> rules — format,
# uniqueness, matching, nesting — plus the orphan-start/orphan-end
# conditions and a malformed-marker-line branch; `derivation` is not
# mechanically enforced, see core/local-validation.md). Contract: RC-6
# (invocation), RC-8 (report format + exit codes, including the `marker`
# RULE), RC-9 (read-only — reports GAP, never excludes), RC-10 (command
# verification clauses, including the external-tool allowlist), RC-11
# (low-value proxies). Full definitions: core/local-validation.md. This
# script is read-only — it never rewrites README_FILE and writes no file
# of its own.
#
# Run: bash check-readme-patch.sh <README_FILE> [REPO_ROOT]
# REPO_ROOT default: git -C <dir of README_FILE> rev-parse --show-toplevel,
# falling back to that directory if git is unavailable or it is not a repo.
#
# RC-11 — low-value detection signals (Task 6 rule (c)), stated verbatim
# here and in core/local-validation.md. A drafted section is flagged
# LOW_VALUE when it contains none of these four proxies for
# spec-draft.md's "command, path, constraint, or routing rule":
#
#   | Spec term    | Machine-detectable proxy                                                                                |
#   |--------------|----------------------------------------------------------------------------------------------------------|
#   | command      | a fenced block labeled bash/sh/shell/console                                                             |
#   | path         | an inline code span containing /, or a markdown link to a repo-relative path                             |
#   | constraint   | a normative verb (must|shall|never|always|required|do not) or a digit sequence within 20 chars of        |
#   |              | lines|chars|tokens|%                                                                                      |
#   | routing rule | use when|invoke|route|→|-> on a line that also names a path, skill, or slash command                      |

set -u

README_FILE="${1:-}"

if [ -z "$README_FILE" ] || [ ! -f "$README_FILE" ] || [ ! -r "$README_FILE" ]; then
  echo "usage: check-readme-patch.sh <README_FILE> [REPO_ROOT]" >&2
  echo "  README_FILE must be a readable file" >&2
  exit 2
fi

README_DIR="$(cd "$(dirname "$README_FILE")" && pwd)"

if [ -n "${2:-}" ]; then
  REPO_ROOT="$2"
else
  REPO_ROOT="$(git -C "$README_DIR" rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$REPO_ROOT" ]; then
    REPO_ROOT="$README_DIR"
  fi
fi

if [ ! -d "$REPO_ROOT" ]; then
  echo "usage: REPO_ROOT '$REPO_ROOT' is not a directory" >&2
  exit 2
fi

GAPS=0
LOW_VALUE=0

# Published for downstream callers within this process only (Task 4's
# stage-4 scope tag reads it): well-formed managed-section marker pairs,
# each element formatted "<start_line>:<end_line>". Populated by
# scan_markers(). A pair enters this array only when it popped cleanly
# with byte-identical ids, neither marker emitted a format record, its id
# emitted no uniqueness record, and no nesting record fired within its
# line range. See scan_markers() below and core/local-validation.md §
# Managed-section marker grammar.
MARKER_WELLFORMED_PAIRS=()

# RC-10 clause 5 — declared in core/local-validation.md as the visible,
# auditable list; this is the single source the script reads.
ALLOWLIST="claude git jq bash python3 shasum sha256sum"

is_allowlisted() {
  local tool="$1"
  local t
  for t in $ALLOWLIST; do
    [ "$t" = "$tool" ] && return 0
  done
  return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# UTILITIES — anchor slugging (GitHub style), shared with check-knowledge-grounding.sh
# ──────────────────────────────────────────────────────────────────────────────

make_slug() {
  local text="$1"
  text="${text//[^[:alnum:] -]/}"
  text="${text,,}"
  text="${text// /-}"
  printf '%s' "$text"
}

extract_slugs() {
  local file="$1"
  local heading_pattern='^#+[[:space:]]+'
  local slug
  while IFS= read -r line; do
    if [[ $line =~ $heading_pattern ]]; then
      local text="${line#*[[:space:]]}"
      slug="$(make_slug "$text")"
      printf '%s\n' "#$slug"
    fi
  done < "$file"
}

# ──────────────────────────────────────────────────────────────────────────────
# GATE (d): managed-section marker grammar (readme-ownership.md's <id>
# rules — format, uniqueness, matching, nesting — plus orphan-start,
# orphan-end, and the malformed-marker-line branch). Runs FIRST in MAIN,
# before gates (a)-(c). `derivation` is not enforced — see
# core/local-validation.md.
# ──────────────────────────────────────────────────────────────────────────────

# Anchored recognition: exactly one non-space id token between the
# marker keyword and `-->`.
MARKER_START_RE='^[[:space:]]*<!--[[:space:]]*cartographer:managed:start[[:space:]]+([^[:space:]]+)[[:space:]]*-->[[:space:]]*$'
MARKER_END_RE='^[[:space:]]*<!--[[:space:]]*cartographer:managed:end[[:space:]]+([^[:space:]]+)[[:space:]]*-->[[:space:]]*$'
# Loose recognition — applied only to lines that matched neither anchored
# pattern above — catches zero-token and multi-token marker lines.
MARKER_LOOSE_RE='^[[:space:]]*<!--[[:space:]]*cartographer:managed:(start|end)([[:space:]]+.*)?[[:space:]]*-->[[:space:]]*$'
MARKER_FORMAT_RE='^[a-z0-9]+(-[a-z0-9]+)*$'

scan_markers() {
  local fence_state=0
  local line_num=0

  # Open-start stack (parallel arrays), for pairing/nesting.
  local stack_ids=()
  local stack_lines=()

  # Every well-formed start marker's (id, line) — for uniqueness + format.
  local all_start_ids=()
  local all_start_lines=()
  # Every well-formed start-or-end marker's (id, line) — for format only.
  local all_marker_ids=()
  local all_marker_lines=()
  # Lines where a nesting record fired (always a start line).
  local nesting_lines=()
  # Candidate pairs that popped cleanly with matching ids: "start:end:id".
  local candidates=()

  local id top_idx id0 line0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    if [[ $line =~ ^[[:space:]]*\`{3,} ]] || [[ $line =~ ^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
      continue
    fi
    [ "$fence_state" -ne 0 ] && continue

    if [[ $line =~ $MARKER_START_RE ]]; then
      id="${BASH_REMATCH[1]}"
      all_start_ids+=("$id")
      all_start_lines+=("$line_num")
      all_marker_ids+=("$id")
      all_marker_lines+=("$line_num")
      if [ "${#stack_ids[@]}" -gt 0 ]; then
        top_idx=$(( ${#stack_ids[@]} - 1 ))
        printf 'GAP|marker|%s:%d|%s|marker violates the nesting rule: a managed block opened at line %d is still open\n' \
          "$README_FILE" "$line_num" "$id" "${stack_lines[$top_idx]}"
        GAPS=$((GAPS + 1))
        nesting_lines+=("$line_num")
      fi
      stack_ids+=("$id")
      stack_lines+=("$line_num")
      continue
    fi

    if [[ $line =~ $MARKER_END_RE ]]; then
      id="${BASH_REMATCH[1]}"
      all_marker_ids+=("$id")
      all_marker_lines+=("$line_num")
      if [ "${#stack_ids[@]}" -eq 0 ]; then
        printf 'GAP|marker|%s:%d|%s|end marker has no matching start marker\n' \
          "$README_FILE" "$line_num" "$id"
        GAPS=$((GAPS + 1))
      else
        top_idx=$(( ${#stack_ids[@]} - 1 ))
        id0="${stack_ids[$top_idx]}"
        line0="${stack_lines[$top_idx]}"
        # Pop is always the top element (LIFO nesting stack), so a
        # truncating slice is equivalent to unset+recompact and never
        # expands a possibly-empty array bare (stack_ids is non-empty
        # here, per the count check above).
        stack_ids=("${stack_ids[@]:0:top_idx}")
        stack_lines=("${stack_lines[@]:0:top_idx}")
        if [ "$id" != "$id0" ]; then
          printf 'GAP|marker|%s:%d|%s|marker pair violates the matching rule: end id does not match the start id at line %d\n' \
            "$README_FILE" "$line_num" "$id" "$line0"
          GAPS=$((GAPS + 1))
        else
          candidates+=("$line0:$line_num:$id")
        fi
      fi
      continue
    fi

    if [[ $line =~ $MARKER_LOOSE_RE ]]; then
      printf 'GAP|marker|%s:%d|-|marker line violates the format rule: expected exactly one id token between the marker keyword and -->\n' \
        "$README_FILE" "$line_num"
      GAPS=$((GAPS + 1))
      continue
    fi
  done < "$README_FILE"

  # EOF — every entry left on the stack is an orphan-start.
  local i
  for ((i = 0; i < ${#stack_ids[@]}; i++)); do
    printf 'GAP|marker|%s:%d|%s|start marker has no matching end marker\n' \
      "$README_FILE" "${stack_lines[$i]}" "${stack_ids[$i]}"
    GAPS=$((GAPS + 1))
  done

  # uniqueness — across every start marker's id, in encounter order.
  local dup_ids=()
  local seen_ids=()
  local seen_lines=()
  local j ln first_line already_dup d
  for ((i = 0; i < ${#all_start_ids[@]}; i++)); do
    id="${all_start_ids[$i]}"
    ln="${all_start_lines[$i]}"
    first_line=""
    for ((j = 0; j < ${#seen_ids[@]}; j++)); do
      if [ "${seen_ids[$j]}" = "$id" ]; then
        first_line="${seen_lines[$j]}"
        break
      fi
    done
    if [ -n "$first_line" ]; then
      printf 'GAP|marker|%s:%d|%s|marker id violates the uniqueness rule: id already used by a start marker at line %s\n' \
        "$README_FILE" "$ln" "$id" "$first_line"
      GAPS=$((GAPS + 1))
      already_dup=0
      for d in "${dup_ids[@]+"${dup_ids[@]}"}"; do
        [ "$d" = "$id" ] && already_dup=1 && break
      done
      [ "$already_dup" -eq 0 ] && dup_ids+=("$id")
    else
      seen_ids+=("$id")
      seen_lines+=("$ln")
    fi
  done

  # format — every well-formed start and end marker line.
  local bad_format_lines=()
  for ((i = 0; i < ${#all_marker_ids[@]}; i++)); do
    id="${all_marker_ids[$i]}"
    ln="${all_marker_lines[$i]}"
    if ! [[ $id =~ $MARKER_FORMAT_RE ]] || [ "${#id}" -gt 64 ]; then
      printf 'GAP|marker|%s:%d|%s|marker id violates the format rule: must match ^[a-z0-9]+(-[a-z0-9]+)*$ and be at most 64 characters\n' \
        "$README_FILE" "$ln" "$id"
      GAPS=$((GAPS + 1))
      bad_format_lines+=("$ln")
    fi
  done

  # Publish the well-formed-pair set: a candidate pair qualifies only when
  # its id was never flagged for uniqueness, neither its start nor its end
  # line was flagged for format, and no nesting record fell inside its
  # [start_line, end_line] range (this also excludes a pair whose OWN
  # start triggered nesting, since that start line is its own range's
  # lower bound).
  local c rest start_ln end_ln pid excluded b n
  for c in "${candidates[@]+"${candidates[@]}"}"; do
    start_ln="${c%%:*}"
    rest="${c#*:}"
    end_ln="${rest%%:*}"
    pid="${rest#*:}"

    excluded=0
    for d in "${dup_ids[@]+"${dup_ids[@]}"}"; do
      [ "$d" = "$pid" ] && excluded=1 && break
    done
    if [ "$excluded" -eq 0 ]; then
      for b in "${bad_format_lines[@]+"${bad_format_lines[@]}"}"; do
        if [ "$b" = "$start_ln" ] || [ "$b" = "$end_ln" ]; then
          excluded=1
          break
        fi
      done
    fi
    if [ "$excluded" -eq 0 ]; then
      for n in "${nesting_lines[@]+"${nesting_lines[@]}"}"; do
        if [ "$n" -ge "$start_ln" ] && [ "$n" -le "$end_ln" ]; then
          excluded=1
          break
        fi
      done
    fi
    [ "$excluded" -eq 0 ] && MARKER_WELLFORMED_PAIRS+=("$start_ln:$end_ln")
  done
}

# ──────────────────────────────────────────────────────────────────────────────
# GATE (a): internal link resolution
# ──────────────────────────────────────────────────────────────────────────────

check_links() {
  local fence_state=0
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    if [[ $line =~ ^[[:space:]]*\`{3,} ]] || [[ $line =~ ^[[:space:]]*~{3,} ]]; then
      fence_state=$((1 - fence_state))
      continue
    fi
    [ "$fence_state" -ne 0 ] && continue

    while IFS= read -r match; do
      [ -z "$match" ] && continue
      local target
      target="$(sed -E 's/^\[[^]]*\]\(([^)]+)\)$/\1/' <<<"$match")"

      # Out of scope for Slice 1: any scheme:// target (no network), incl. mailto:
      if [[ $target =~ ^[a-zA-Z][a-zA-Z0-9+.-]*: ]]; then
        continue
      fi

      if [[ $target == \#* ]]; then
        local anchor="${target#\#}"
        local found=0
        while IFS= read -r slug; do
          if [ "$slug" = "#$anchor" ]; then
            found=1
            break
          fi
        done < <(extract_slugs "$README_FILE")
        if [ "$found" -eq 1 ]; then
          printf 'OK|link|%s:%d|%s|anchor resolves within README\n' "$README_FILE" "$line_num" "$target"
        else
          printf 'GAP|link|%s:%d|%s|anchor does not resolve within README\n' "$README_FILE" "$line_num" "$target"
          GAPS=$((GAPS + 1))
        fi
        continue
      fi

      local path_part="${target%%#*}"
      if [ -e "$REPO_ROOT/$path_part" ]; then
        printf 'OK|link|%s:%d|%s|resolves under REPO_ROOT\n' "$README_FILE" "$line_num" "$target"
      else
        printf 'GAP|link|%s:%d|%s|does not resolve under REPO_ROOT\n' "$README_FILE" "$line_num" "$target"
        GAPS=$((GAPS + 1))
      fi
    done < <(grep -oE '\[[^]]*\]\([^)]+\)' <<<"$line")
  done < "$README_FILE"
}

# ──────────────────────────────────────────────────────────────────────────────
# GATE (b): documented command verification (RC-10)
# ──────────────────────────────────────────────────────────────────────────────

verify_command() {
  local cmd="$1"
  local line_num="$2"

  [ -z "$cmd" ] && return

  local tokens=()
  read -r -a tokens <<< "$cmd"
  local argv0="${tokens[0]:-}"
  [ -z "$argv0" ] && return

  # Clause 1: npm/pnpm/yarn run <name>, <name> a key under package.json .scripts
  # Disjoint from clause 2: "run" is not in {install,ci,audit,outdated,list,prune}
  if [[ $argv0 == "npm" || $argv0 == "pnpm" || $argv0 == "yarn" ]] \
     && [ "${tokens[1]:-}" = "run" ] && [ -n "${tokens[2]:-}" ]; then
    local script_name="${tokens[2]}"
    local pkg="$REPO_ROOT/package.json"
    if [ -f "$pkg" ] && jq -e --arg n "$script_name" '(.scripts // {}) | has($n)' "$pkg" >/dev/null 2>&1; then
      printf 'OK|command|%s:%d|%s|verified via package.json .scripts\n' "$README_FILE" "$line_num" "$cmd"
      return
    fi
  fi

  # Clause 2: npm/pnpm/yarn with built-in verbs (install, ci, audit, outdated, list, prune)
  if [[ $argv0 == "npm" || $argv0 == "pnpm" || $argv0 == "yarn" ]]; then
    local verb="${tokens[1]:-}"
    case "$verb" in
      install|ci|audit|outdated|list|prune)
        printf 'OK|command|%s:%d|%s|npm-builtin\n' "$README_FILE" "$line_num" "$cmd"
        return
        ;;
    esac
  fi

  # Clause 3: verbatim match in a file under REPO_ROOT/.github/workflows/
  local wf_dir="$REPO_ROOT/.github/workflows"
  if [ -d "$wf_dir" ] && grep -rFl -- "$cmd" "$wf_dir" >/dev/null 2>&1; then
    printf 'OK|command|%s:%d|%s|verified via .github/workflows verbatim match\n' "$README_FILE" "$line_num" "$cmd"
    return
  fi

  # Clause 4: invokes a path that exists under REPO_ROOT
  local tok candidate
  for tok in "${tokens[@]}"; do
    candidate="$tok"
    candidate="${candidate%\"}"; candidate="${candidate#\"}"
    candidate="${candidate%\'}"; candidate="${candidate#\'}"
    if [ -n "$candidate" ] && [ -e "$REPO_ROOT/$candidate" ]; then
      printf 'OK|command|%s:%d|%s|verified via in-repo path %s\n' "$README_FILE" "$line_num" "$cmd" "$candidate"
      return
    fi
  done

  # Clause 5: external-tool allowlist
  if is_allowlisted "$argv0"; then
    printf 'OK|command|%s:%d|%s|external-tool\n' "$README_FILE" "$line_num" "$cmd"
    return
  fi

  printf 'GAP|command|%s:%d|%s|not verified: no package.json script, no npm-builtin verb, no CI match, no in-repo path, not on external-tool allowlist\n' "$README_FILE" "$line_num" "$cmd"
  GAPS=$((GAPS + 1))
}

check_commands() {
  local fence_state=0
  local fence_lang=""
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    if [[ $line =~ ^[[:space:]]*\`{3,}(.*)$ ]] || [[ $line =~ ^[[:space:]]*~{3,}(.*)$ ]]; then
      if [ "$fence_state" -eq 0 ]; then
        fence_state=1
        fence_lang="$(printf '%s' "${BASH_REMATCH[1]:-}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
      else
        fence_state=0
        fence_lang=""
      fi
      continue
    fi

    [ "$fence_state" -eq 0 ] && continue

    case "$fence_lang" in
      bash|sh|shell|console) ;;
      *) continue ;;
    esac

    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ $line =~ ^[[:space:]]*# ]] && continue

    local cmd="$line"
    if [[ $cmd == '$ '* ]]; then
      cmd="${cmd#\$ }"
    fi

    verify_command "$cmd" "$line_num"
  done < "$README_FILE"
}

# ──────────────────────────────────────────────────────────────────────────────
# GATE (c): low-value section flagging (RC-11)
# ──────────────────────────────────────────────────────────────────────────────

check_sections() {
  shopt -s nocasematch

  local in_section=0
  local section_start=0
  local heading=""
  local has_proxy=0
  local fence_state=0
  local fence_lang=""
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    if [[ $line =~ ^[[:space:]]*\`{3,}(.*)$ ]] || [[ $line =~ ^[[:space:]]*~{3,}(.*)$ ]]; then
      if [ "$fence_state" -eq 0 ]; then
        fence_state=1
        fence_lang="$(printf '%s' "${BASH_REMATCH[1]:-}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"
        if [ "$in_section" -eq 1 ]; then
          case "$fence_lang" in
            bash|sh|shell|console) has_proxy=1 ;;
          esac
        fi
      else
        fence_state=0
        fence_lang=""
      fi
      continue
    fi

    if [[ $line =~ ^##[[:space:]]+([^#].*)$ ]]; then
      if [ "$in_section" -eq 1 ] && [ "$has_proxy" -eq 0 ]; then
        printf 'LOW_VALUE|section-value|%s:%d|%s|no command, path, constraint, or routing-rule proxy found\n' "$README_FILE" "$section_start" "$heading"
        LOW_VALUE=$((LOW_VALUE + 1))
      fi
      heading="${BASH_REMATCH[1]}"
      section_start=$line_num
      in_section=1
      has_proxy=0
      continue
    fi

    [ "$in_section" -eq 0 ] && continue
    [ "$fence_state" -ne 0 ] && continue

    # path proxy: inline code span containing '/'
    if [[ $line =~ \`[^\`]*/[^\`]*\` ]]; then
      has_proxy=1
    fi

    # path proxy: a markdown link whose target is not an absolute URL
    while IFS= read -r match; do
      [ -z "$match" ] && continue
      local target
      target="$(sed -E 's/^\[[^]]*\]\(([^)]+)\)$/\1/' <<<"$match")"
      if ! [[ $target =~ ^[a-zA-Z][a-zA-Z0-9+.-]*: ]]; then
        has_proxy=1
      fi
    done < <(grep -oE '\[[^]]*\]\([^)]+\)' <<<"$line")

    # constraint proxy: normative verb or digit sequence near a unit word
    if [[ $line =~ (must|shall|never|always|required|do\ not) ]]; then
      has_proxy=1
    fi
    if [[ $line =~ [0-9]+.{0,20}(lines|chars|tokens|%) ]] || [[ $line =~ (lines|chars|tokens|%).{0,20}[0-9]+ ]]; then
      has_proxy=1
    fi

    # routing-rule proxy: routing token on a line that also contains '/'
    if [[ $line =~ (use[[:space:]]when|invoke|route|→|-\>) ]] && [[ $line == */* ]]; then
      has_proxy=1
    fi
  done < "$README_FILE"

  if [ "$in_section" -eq 1 ] && [ "$has_proxy" -eq 0 ]; then
    printf 'LOW_VALUE|section-value|%s:%d|%s|no command, path, constraint, or routing-rule proxy found\n' "$README_FILE" "$section_start" "$heading"
    LOW_VALUE=$((LOW_VALUE + 1))
  fi

  shopt -u nocasematch
}

# ──────────────────────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────────────────────

scan_markers
check_links
check_commands
check_sections

printf 'SUMMARY|gaps=%d|low_value=%d\n' "$GAPS" "$LOW_VALUE"

if [ "$GAPS" -gt 0 ]; then
  exit 1
fi

exit 0
