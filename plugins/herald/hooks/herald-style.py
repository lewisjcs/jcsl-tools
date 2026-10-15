#!/usr/bin/env python3
"""Prints the Herald style body for the Codex SessionStart hook. Plain stdout becomes developer context."""
import pathlib
import sys

STYLE = pathlib.Path(__file__).resolve().parent.parent / "output-styles" / "herald.md"
try:
    text = STYLE.read_text(encoding="utf-8")
    sys.stdout.write(text.split("\n---\n", 1)[1].strip() + "\n")
except Exception:  # noqa: BLE001  a missing style file must not break session start
    pass
sys.exit(0)
