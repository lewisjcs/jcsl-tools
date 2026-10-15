#!/usr/bin/env bash
# Keeps hooks/rules.json, output-styles/herald.md, and rules/herald.mdc equal.
# Exit 0 when every check passes, 1 otherwise.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$(cd "$HERE/.." && pwd)"
python3 - "$PLUGIN" <<'PY'
import json, pathlib, re, sys

plugin = pathlib.Path(sys.argv[1])
rules = json.loads((plugin / "hooks" / "rules.json").read_text(encoding="utf-8"))
style = (plugin / "output-styles" / "herald.md").read_text(encoding="utf-8")
rule = (plugin / "rules" / "herald.mdc").read_text(encoding="utf-8")
fails = []


def body(text):
    return text.split("\n---\n", 1)[1].strip()


low = body(style).lower()

for word in rules["slop"] + rules["modals"]:
    if word.lower() not in low:
        fails.append(f"rules.json word missing from the style: {word}")

for key in ("sentence_words", "list_item_sentence_words"):
    if f"{rules['limits'][key]} words" not in low:
        fails.append(f"limit {key}={rules['limits'][key]} missing from the style")


def listed(pattern):
    m = re.search(pattern, low, re.S)
    if not m:
        fails.append(f"style list not found: {pattern}")
        return []
    return [w.strip().strip('"') for w in m.group(1).split(",") if w.strip()]


for word in listed(r"no words that carry no fact: (.*?)\.\s"):
    if word not in [s.lower() for s in rules["slop"]]:
        fails.append(f"style slop word missing from rules.json: {word}")
for word in listed(r"never (should.*?)\."):
    if word not in [s.lower() for s in rules["modals"]]:
        fails.append(f"style modal missing from rules.json: {word}")

if body(style) != body(rule):
    fails.append("rules/herald.mdc body differs from output-styles/herald.md body")

tokens = len(body(style)) / 4
if tokens >= rules["limits"]["style_tokens"]:
    fails.append(f"style body is about {tokens:.0f} tokens, limit {rules['limits']['style_tokens']}")

for f in fails:
    print("FAIL:", f)
print("ALL PASS" if not fails else "FAILURES")
sys.exit(1 if fails else 0)
PY
