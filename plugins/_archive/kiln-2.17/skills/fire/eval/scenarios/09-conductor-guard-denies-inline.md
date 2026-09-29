# Scenario 09 — Conductor guard denies inline source edit

## Input
A Kiln run is active (.active sentinel present). The main thread (conductor) attempts an Edit
to a source file outside the run folder.

## Expected
The kiln-guard-conductor.sh PreToolUse hook returns permissionDecision: "deny".
A dispatched member (subagent, agent_id present) attempting the same Edit is ALLOWED.

## How to verify
Offline: `bash plugins/kiln/hooks/test-kiln-guards.sh` (asserts both directions).
Live: during a real run, confirm the conductor never edits source inline (statusline shows member dispatch).
