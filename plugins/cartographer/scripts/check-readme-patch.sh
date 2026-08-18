#!/bin/bash
# Local validation for a drafted README patch — gates (a) link resolution,
# (b) command existence, (c) low-value section flagging. Contract: RC-6
# (invocation), RC-8 (report format + exit codes), RC-9 (read-only —
# reports GAP, never excludes), RC-10 (command verification clauses,
# including the external-tool allowlist), RC-11 (low-value proxies).
# Full definitions: core/local-validation.md. This script is read-only —
# it never rewrites README_FILE and writes no file of its own.
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

# RC-10 clause 4 — declared in core/local-validation.md as the visible,
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
  if [[ $argv0 == "npm" || $argv0 == "pnpm" || $argv0 == "yarn" ]] \
     && [ "${tokens[1]:-}" = "run" ] && [ -n "${tokens[2]:-}" ]; then
    local script_name="${tokens[2]}"
    local pkg="$REPO_ROOT/package.json"
    if [ -f "$pkg" ] && jq -e --arg n "$script_name" '(.scripts // {}) | has($n)' "$pkg" >/dev/null 2>&1; then
      printf 'OK|command|%s:%d|%s|verified via package.json .scripts\n' "$README_FILE" "$line_num" "$cmd"
      return
    fi
  fi

  # Clause 2: verbatim match in a file under REPO_ROOT/.github/workflows/
  local wf_dir="$REPO_ROOT/.github/workflows"
  if [ -d "$wf_dir" ] && grep -rFl -- "$cmd" "$wf_dir" >/dev/null 2>&1; then
    printf 'OK|command|%s:%d|%s|verified via .github/workflows verbatim match\n' "$README_FILE" "$line_num" "$cmd"
    return
  fi

  # Clause 3: invokes a path that exists under REPO_ROOT
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

  # Clause 4: external-tool allowlist
  if is_allowlisted "$argv0"; then
    printf 'OK|command|%s:%d|%s|external-tool\n' "$README_FILE" "$line_num" "$cmd"
    return
  fi

  printf 'GAP|command|%s:%d|%s|not verified: no package.json script, no CI match, no in-repo path, not on external-tool allowlist\n' "$README_FILE" "$line_num" "$cmd"
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

check_links
check_commands
check_sections

printf 'SUMMARY|gaps=%d|low_value=%d\n' "$GAPS" "$LOW_VALUE"

if [ "$GAPS" -gt 0 ]; then
  exit 1
fi

exit 0
