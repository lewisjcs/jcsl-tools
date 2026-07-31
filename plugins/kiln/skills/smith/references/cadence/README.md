# Smith cadence trigger (Plan B) — launchd runbook

Runs `/smith --emit-suggestions` unattended each morning. It ONLY writes the
durable suggestions file (read-only harvest + filtered local write). It never
runs the eval gate, never drafts a PR, never mutates the workspace — those stay
attended, via `/smith implement <id>`.

## Install
    bash install-cadence.sh --workspace /path/to/os-workspace [--hour 7 --minute 30]
Renders `~/Library/LaunchAgents/com.jcsl.smith-cadence.plist` and loads it.

## Verify (without waiting for the schedule)
    launchctl kickstart gui/$(id -u)/com.jcsl.smith-cadence
    # then inspect the newest file under:
    #   <workspace>/projects/active/kiln-smith/smith-suggestions/
    #   <workspace>/projects/active/kiln-smith/smith-suggestions/.cadence-logs/<date>.log
A clean run writes either a dated suggestions file or a single
`nothing new since <date>` line. The log shows `langfuse: live|DOWN` and the
`claude -p exit` code.

## Rollback (zero upstream cost)
    bash uninstall-cadence.sh
Removes the job + plist. The attended loop (`/smith`, `/smith --emit-suggestions`,
`/smith implement <id>`) is unaffected — the cadence is only a trigger. Swapping
to `/loop` or manual invocation needs no code change: run `smith-cadence.sh
--workspace <WS>` however you like.

## Headless-fragility notes
- Bedrock: the plist carries `CLAUDE_CODE_USE_BEDROCK=1`, `AWS_PROFILE=bedrock`,
  `AWS_REGION=us-east-1`. If your profile differs, edit the template + reinstall.
- ccusage PATH gap: the wrapper defaults `SMITH_CCUSAGE=npx ccusage@latest`.
- Langfuse liveness: the wrapper probes `localhost:3000/api/public/health`; on
  failure it sets `SMITH_LANGFUSE_DOWN=1` and the cost lens falls open to
  ccusage-only, stamped in the log — never silently degraded.
- Fail-open: a failed morning writes no partial file; the next run catches up.
