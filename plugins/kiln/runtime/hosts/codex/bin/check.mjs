#!/usr/bin/env node
/** Execute one saved done-when command for a native Codex member and record what actually ran. */
import { readFileSync, writeFileSync, renameSync, rmSync } from 'node:fs';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';

class CheckError extends Error {
  constructor(code, message, details = {}) { super(message); this.code = code; this.details = details; }
}

function flagsOf(args) {
  const { values } = parseArgs({ args, options: { run: { type: 'string' }, action: { type: 'string' }, check: { type: 'string' }, cli: { type: 'string' } } });
  for (const key of ['run', 'action', 'check', 'cli']) if (!values[key]) throw new CheckError('CODEX_CHECK_FLAGS', `--${key} is required`);
  if (!path.isAbsolute(values.run) || !path.isAbsolute(values.cli)) throw new CheckError('CODEX_CHECK_FLAGS', '--run and --cli must be absolute paths');
  const check = Number(values.check);
  if (!Number.isSafeInteger(check) || check < 1) throw new CheckError('CODEX_CHECK_FLAGS', '--check must be a positive integer');
  return { ...values, check };
}

function main(args) {
  const v = flagsOf(args);
  const meta = JSON.parse(readFileSync(path.join(v.run, 'run.json'), 'utf8'));
  const state = JSON.parse(readFileSync(path.join(v.run, 'state.json'), 'utf8'));
  if (state.host?.id !== 'codex') throw new CheckError('CODEX_CHECK_HOST_MISMATCH', 'the saved run is not bound to Codex');
  const result = spawnSync(process.execPath, [v.cli, 'next', '--root', path.dirname(v.run), '--ticket', meta.ticketRef], { encoding: 'utf8' });
  if (result.status !== 0) throw new CheckError('CODEX_CHECK_STATE_INVALID', 'Kiln could not verify the pending action', { error: result.stderr.trim().slice(0, 1000) });
  const next = JSON.parse(result.stdout).next;
  if (next.terminal || next.actionId !== v.action || next.hostBinding?.kind !== 'subagent') {
    throw new CheckError('CODEX_CHECK_ACTION_MISMATCH', 'the requested action is not the pending Codex member', { requested: v.action, pending: next.actionId ?? null });
  }
  const checks = next.kind === 'dispatch-changer'
    ? state.brief.tasks.plan[state.cursor].doneWhen
    : next.kind === 'dispatch-judge'
      ? state.brief.tasks.plan.flatMap((task) => task.doneWhen)
      : null;
  if (checks === null || v.check > checks.length) throw new CheckError('CODEX_CHECK_NUMBER', 'no planned check has this number', { check: v.check, kind: next.kind });
  const selected = checks[v.check - 1];
  if (selected.repo !== state.repo.root) throw new CheckError('CODEX_CHECK_REPO_MISMATCH', 'planned check is outside the selected worktree');
  const ran = spawnSync('/bin/sh', ['-c', selected.command], { cwd: selected.repo, encoding: 'utf8', timeout: 900000, maxBuffer: 4 * 1024 * 1024 });
  if (ran.error || !Number.isInteger(ran.status)) throw new CheckError('CODEX_CHECK_EXEC_FAILED', 'the planned check did not finish', { error: ran.error?.message ?? `signal ${ran.signal}` });
  const commandOutput = `${ran.stdout ?? ''}${ran.stderr ?? ''}`;
  const output = `${commandOutput}${commandOutput && !commandOutput.endsWith('\n') ? '\n' : ''}[kiln check ${v.check} exit ${ran.status}]\n`;
  const record = { actionId: v.action, check: v.check, command: selected.command, expect: selected.expect, exitCode: ran.status, commandOutput, output, completedAt: new Date().toISOString() };
  const file = path.join(v.run, 'handed', `${v.action}-check-${v.check}.json`);
  const temp = `${file}.tmp-${process.pid}`;
  try {
    writeFileSync(temp, JSON.stringify(record) + '\n');
    renameSync(temp, file);
  } finally { rmSync(temp, { force: true }); }
  return { check: v.check, command: selected.command, exitCode: ran.status, output: output.slice(-2400) };
}

try { process.stdout.write(JSON.stringify(main(process.argv.slice(2))) + '\n'); }
catch (err) { process.stderr.write(JSON.stringify({ error: { code: err.code ?? 'CODEX_CHECK_UNEXPECTED', message: err.message, details: err.details ?? {} } }) + '\n'); process.exit(1); }
