#!/bin/bash
# Ship-gate for cost-statusline.py. Drives the script with synthetic JSONL and stdin
# payloads, asserts classify/cost/parse/cache/field output. Runs against a throwaway
# $HOME so it never touches the real pricing or transcript cache.
# Run: bash cost-statusline.test.sh
set -u

DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$DIR/cost-statusline.py"
PASS=0; FAIL=0

# Throwaway HOME — keeps the pricing cache and transcript cache writes isolated.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP"

assert() {  # $1=label  $2=expected  $3=got
  if [ "$2" = "$3" ]; then
    printf '  ok   — %s\n' "$1"
    PASS=$((PASS+1))
  else
    printf '  FAIL — %s\n    expected: %s\n    got:      %s\n' "$1" "$2" "$3"
    FAIL=$((FAIL+1))
  fi
}

# Strip ANSI escape codes so we can assert on plain text.
strip_ansi() { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g'; }

# Python snippet preamble — loads cost-statusline.py by path to handle the hyphen.
PY_LOAD="import importlib.util, sys
spec = importlib.util.spec_from_file_location('cost_statusline', '$SCRIPT')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)"

# Build a synthetic JSONL transcript with N assistant entries, each with a unique id.
# Each entry has usage tokens controlled by args. All use model claude-opus-4-8.
# $1=count  $2=input_tokens  $3=output_tokens  $4=cache_read_tokens  $5=cache_creation_tokens
make_transcript() {
  local n="$1" inp="${2:-0}" out="${3:-0}" cr="${4:-0}" cw="${5:-0}"
  local f="$TMP/t-$RANDOM.jsonl" i
  : > "$f"
  for ((i=0; i<n; i++)); do
    printf '{"type":"assistant","message":{"id":"msg%d","model":"claude-opus-4-8","usage":{"input_tokens":%d,"output_tokens":%d,"cache_read_input_tokens":%d,"cache_creation_input_tokens":%d}}}\n' \
      "$i" "$inp" "$out" "$cr" "$cw" >> "$f"
  done
  echo "$f"
}

# Run the script with a transcript_path payload; return raw stdout.
run() {  # $1=path  $2=optional --field arg
  local path="$1" field="${2:-}"
  if [ -n "$field" ]; then
    printf '{"transcript_path":"%s"}' "$path" | python3 "$SCRIPT" --field "$field"
  else
    printf '{"transcript_path":"%s"}' "$path" | python3 "$SCRIPT"
  fi
}

# ── classify() round-trips ───────────────────────────────────────────────────

assert "classify: opus family" "opus" \
  "$(python3 - <<EOF
$PY_LOAD
print(s.classify('claude-opus-4-8'))
EOF
)"

assert "classify: sonnet family" "sonnet" \
  "$(python3 - <<EOF
$PY_LOAD
print(s.classify('claude-sonnet-4-6'))
EOF
)"

assert "classify: haiku family" "haiku" \
  "$(python3 - <<EOF
$PY_LOAD
print(s.classify('claude-haiku-4-5'))
EOF
)"

assert "classify: fable family" "fable" \
  "$(python3 - <<EOF
$PY_LOAD
print(s.classify('claude-fable-5'))
EOF
)"

assert "classify: mythos → fable family" "fable" \
  "$(python3 - <<EOF
$PY_LOAD
print(s.classify('claude-mythos-5'))
EOF
)"

assert "classify: unknown model → other" "other" \
  "$(python3 - <<EOF
$PY_LOAD
print(s.classify('gpt-4o'))
EOF
)"

# ── cost_for() against known usage dict ─────────────────────────────────────
# Opus fallback: $5/MTok in. 1M input tokens = $5.00.

assert "cost_for: opus 1M input tokens = 5.0" "5.0" \
  "$(python3 - <<EOF
$PY_LOAD
usage = {'input_tokens': 1000000, 'output_tokens': 0, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': 0}
print(s.cost_for('claude-opus-4-8', usage, {}))
EOF
)"

assert "cost_for: haiku 1M cache_read tokens = 0.1" "0.1" \
  "$(python3 - <<EOF
$PY_LOAD
usage = {'input_tokens': 0, 'output_tokens': 0, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': 1000000}
print(s.cost_for('claude-haiku-4-5', usage, {}))
EOF
)"

assert "cost_for: fable 1M output tokens = 50.0" "50.0" \
  "$(python3 - <<EOF
$PY_LOAD
usage = {'input_tokens': 0, 'output_tokens': 1000000, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': 0}
print(s.cost_for('claude-fable-5', usage, {}))
EOF
)"

assert "cost_for: unknown model → 0.0" "0.0" \
  "$(python3 - <<EOF
$PY_LOAD
usage = {'input_tokens': 1000000, 'output_tokens': 0, 'cache_creation_input_tokens': 0, 'cache_read_input_tokens': 0}
print(s.cost_for('gpt-4o', usage, {}))
EOF
)"

# ── parse_transcript() dedup-by-id ──────────────────────────────────────────

assert "parse_transcript: dedup-by-id (2 dupes counted once, cost=5.0)" "5.0" \
  "$(python3 - <<EOF
$PY_LOAD
import json, tempfile
f = tempfile.NamedTemporaryFile(mode='w', suffix='.jsonl', delete=False, dir='$TMP')
line = json.dumps({'type':'assistant','message':{'id':'dup','model':'claude-opus-4-8','usage':{'input_tokens':1000000,'output_tokens':0,'cache_creation_input_tokens':0,'cache_read_input_tokens':0}}})
f.write(line + '\n' + line + '\n')
f.flush()
r = s.parse_transcript(f.name, {})
print(r['cost'])
EOF
)"

assert "parse_transcript: 3 unique ids all counted, cost=0.3" "0.3" \
  "$(python3 - <<EOF
$PY_LOAD
import json, tempfile
f = tempfile.NamedTemporaryFile(mode='w', suffix='.jsonl', delete=False, dir='$TMP')
for i in range(3):
    f.write(json.dumps({'type':'assistant','message':{'id':f'u{i}','model':'claude-haiku-4-5','usage':{'input_tokens':0,'output_tokens':0,'cache_creation_input_tokens':0,'cache_read_input_tokens':1000000}}}) + '\n')
f.flush()
r = s.parse_transcript(f.name, {})
print(round(r['cost'], 4))
EOF
)"

# ── cached_totals() cache hit/miss ──────────────────────────────────────────

assert "cached_totals: cache miss returns correct result" "5.0" \
  "$(python3 - <<EOF
$PY_LOAD
import json, tempfile
f = tempfile.NamedTemporaryFile(mode='w', suffix='.jsonl', delete=False, dir='$TMP')
f.write(json.dumps({'type':'assistant','message':{'id':'c1','model':'claude-opus-4-8','usage':{'input_tokens':1000000,'output_tokens':0,'cache_creation_input_tokens':0,'cache_read_input_tokens':0}}}) + '\n')
f.flush()
r = s.cached_totals(f.name, {})
print(r.get('cost'))
EOF
)"

assert "cached_totals: cache hit returns same result" "ok" \
  "$(python3 - <<EOF
$PY_LOAD
import json, tempfile
f = tempfile.NamedTemporaryFile(mode='w', suffix='.jsonl', delete=False, dir='$TMP')
f.write(json.dumps({'type':'assistant','message':{'id':'c2','model':'claude-opus-4-8','usage':{'input_tokens':1000000,'output_tokens':0,'cache_creation_input_tokens':0,'cache_read_input_tokens':0}}}) + '\n')
f.flush()
r1 = s.cached_totals(f.name, {})
r2 = s.cached_totals(f.name, {})
print('ok' if r1 == r2 else 'fail')
EOF
)"

# ── --field both smoke test ──────────────────────────────────────────────────
# 1 assistant message: 1M input+cache_read; both output contain $ and %.

T="$(make_transcript 1 500000 0 500000 0)"
RAW="$(run "$T" both)"
PLAIN="$(strip_ansi "$RAW")"

assert "--field both: output contains dollar sign" "1" \
  "$(echo "$PLAIN" | grep -c '\$')"

assert "--field both: output contains percent" "1" \
  "$(echo "$PLAIN" | grep -c '%')"

# ── fail-silent paths ────────────────────────────────────────────────────────

assert "missing transcript_path: exits 0 with no output" "" \
  "$(printf '{}' | python3 "$SCRIPT" --field both)"

assert "non-existent path: exits 0 with no output" "" \
  "$(printf '{"transcript_path":"/nonexistent/path.jsonl"}' | python3 "$SCRIPT" --field both)"

assert "--field with no value: exits 0 with no output" "" \
  "$(T="$(make_transcript 1 1000000 0 0 0)"; printf '{"transcript_path":"%s"}' "$T" | python3 "$SCRIPT" --field)"

assert "malformed stdin JSON: exits 0 with no output" "" \
  "$(printf 'not json' | python3 "$SCRIPT" --field both)"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
