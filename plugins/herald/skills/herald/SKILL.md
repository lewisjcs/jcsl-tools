---
name: herald
description: Rewrite a document in plain, natural English and report what the Herald linter still flags. Use when the person says "rewrite in plain English", "herald this", "make this readable", "de-slop", "plain English", "STE", "Simplified Technical English", or "write for non-native readers", or asks for a README, runbook, CHANGELOG, or release note that reads on one pass.
---

# Herald rewrite

Rewrite one document so a smart reader outside the field understands it on one read. The rules live in one place, the output style file beside this skill. Read them, apply them, then run the linter on the result.

## Procedure

1. Read the document register. Open `../../output-styles/herald.md` from this skill's folder and read the section that starts with THE DOCUMENT and the paragraph after it that starts with "Everything else keeps its own shape".
2. Decide the tier. The document register applies to README files, files under a docs or runbooks folder, CHANGELOG files, and release notes. It does not apply to tickets and requirements (EARS "shall" bullets), plans, handoffs, decision records, ADRs, RFCs, commit messages, pull request bodies, or memory files. If the file is one of those, say so, apply only the reply register's word rules (no filler, no slop words, no em-dashes, no local paths), and stop there, unless the person says to apply the document register anyway.
3. Classify each passage. Procedural text tells the reader what to do: imperative mood, one instruction per sentence, 20 words per sentence. Descriptive text explains: 25 words per sentence, one topic per paragraph.
4. Rewrite. Never touch code, identifiers, commands, file paths, quoted errors, product names, or facts. When the source gives no number or cause, keep the general statement.
5. Run the linter on the result and report what remains, with line numbers:

   ```bash
   python3 ../../hooks/herald-lint.py --file <path> --tier document
   ```

   Resolve the two `..` against this skill's folder, so the path is the plugin's `hooks/herald-lint.py`. Fix what the linter reports when the fix keeps the meaning. Report the rest with the line number and the reason it stays.

## Scope

There is no strict dictionary mode. If the person asks for ASD-STE100 compliance, say once that the official dictionary is free at asd-ste100.org and that no tool guarantees compliance, then apply the document register as written.
