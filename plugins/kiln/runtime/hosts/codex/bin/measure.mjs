#!/usr/bin/env node
/** Turn one completed native Codex subagent into a Kiln receipt. Reads the child's own rollout, not the parent's retelling. */
import { readFileSync, readdirSync, writeFileSync, renameSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';
import { invocationMatches } from '../check-command.mjs';
import { outcomeArrayOf, findSession, entriesOf, usageOf, sessionMetaOf, assertChildOf, modelOf, finalReplyOf, timeOf } from '../rollout.mjs';
import { parseCheckExpectation, checkMatchesExpectation } from '../check-expectation.mjs';
import { treeSignatureOf } from '../tree.mjs';

const PREFIX = 'CODEX_MEASURE';

class MeasureError extends Error {
  constructor(code, message, details = {}) { super(message); this.code = code; this.details = details; }
}

function flagsOf(args) {
  const { values } = parseArgs({ args, options: {
    'sessions-root': { type: 'string' }, agent: { type: 'string' }, action: { type: 'string' },
    brief: { type: 'string' }, run: { type: 'string' }, cli: { type: 'string' },
    repo: { type: 'string' }, before: { type: 'string' }
  } });
  for (const key of ['agent', 'action', 'brief', 'run', 'cli']) {
    if (!values[key]) throw new MeasureError('CODEX_MEASURE_FLAGS', `--${key} is required`);
  }
  if ((values.repo === undefined) !== (values.before === undefined)) {
    throw new MeasureError('CODEX_MEASURE_FLAGS', '--repo and --before must be supplied together');
  }
  return { ...values, 'sessions-root': values['sessions-root'] ?? path.join(process.env.CODEX_HOME ?? path.join(homedir(), '.codex'), 'sessions') };
}

function nestedCommands(source) {
  const commands = [];
  for (let i = 0; i < source.length;) {
    if (source.startsWith('//', i)) { i = source.indexOf('\n', i + 2); if (i < 0) break; continue; }
    if (source.startsWith('/*', i)) { i = source.indexOf('*/', i + 2); if (i < 0) break; i += 2; continue; }
    if ('"\'`'.includes(source[i])) {
      const quote = source[i++];
      while (i < source.length && source[i] !== quote) i += source[i] === '\\' ? 2 : 1;
      i++;
      continue;
    }
    if (source.startsWith('tools.exec_command', i) && !/[\w$.]/.test(source[i - 1] ?? '')) {
      const head = /^tools\.exec_command\s*\(\s*\{\s*cmd\s*:\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')/.exec(source.slice(i));
      if (head) {
        const literal = head[1];
        try {
          const command = literal[0] === '"' ? JSON.parse(literal) : literal.slice(1, -1).replace(/\\([\\'])/g, '$1');
          commands.push(command);
        } catch { /* An unparseable command cannot establish an invocation. */ }
        i += head[0].length;
        continue;
      }
    }
    i++;
  }
  return commands;
}

function commandsOf(events) {
  return events.filter((e) => e.type === 'response_item').flatMap(({ payload: p }) => {
    if (p?.namespace === 'functions' && p.name === 'exec' && p.type === 'custom_tool_call' && typeof p.input === 'string') return nestedCommands(p.input);
    if (p?.namespace === 'functions' && p.name === 'exec_command' && p.type === 'function_call') {
      try { return [JSON.parse(p.arguments).cmd].filter((cmd) => typeof cmd === 'string'); }
      catch { return []; }
    }
    return [];
  });
}

/** Each run of whitespace as one space, so a quote may differ from the record in spacing and line breaks. */
const ws = (s) => s.replace(/\s+/g, ' ').trim();

/**
 * Check a complete claim against the runner records and fill each evidence item's command and exit code from its record.
 * A record from before the final turn stays valid while the worktree's content signature still matches the one it recorded.
 */
function checkedReply(reply, handed, action, run, repo, finalCommands, allCommands, plannedChecks, finalStartedAt) {
  const { array, repairs } = outcomeArrayOf(reply, 'CODEX_MEASURE_REPLY');
  if (array.length !== 1 || typeof array[0] !== 'object' || array[0] === null || Array.isArray(array[0])) {
    throw new MeasureError('CODEX_MEASURE_REPLY_INVALID', 'subagent final message must be a one-item outcome array');
  }
  const records = readdirSync(handed).filter((name) => name.startsWith(`${action}-check-`) && name.endsWith('.json')).map((name) => {
    try { return JSON.parse(readFileSync(path.join(handed, name), 'utf8')); }
    catch { throw new MeasureError('CODEX_MEASURE_CHECK_MALFORMED', `invalid check record ${name}`); }
  });
  const toolCalls = records.sort((a, b) => a.check - b.check).map((record) => ({ tool: 'Bash', target: record.command }));
  if (array[0].status !== 'complete') return { item: array[0], repairs, toolCalls };
  if (!Array.isArray(array[0].evidence)) throw new MeasureError('CODEX_MEASURE_CHECK_MISMATCH', 'completed reply has no evidence list');
  const own = records.filter((r) => r.actionId === action);
  const notes = [...repairs];
  let tree;
  const currentTree = () => (tree ??= treeSignatureOf(repo, PREFIX));
  // A claimed item numbered past the planned total is dropped with a note, as the runtime drops one on Claude Code, so the runtime counts what remains.
  const evidence = array[0].evidence.filter((claimed) => {
    if (!Number.isInteger(claimed.check) || claimed.check <= plannedChecks.length) return true;
    notes.push(`dropped evidence item numbered ${claimed.check}; the plan has ${plannedChecks.length} checks`);
    return false;
  }).map((claimed) => {
    const planned = plannedChecks[claimed.check - 1];
    const record = own.find((r) => r.check === claimed.check)
      ?? (planned && own.find((r) => r.command === planned.command && r.expect === planned.expect));
    if (!record || !planned || record.command !== planned.command || record.expect !== planned.expect || typeof claimed.quote !== 'string') {
      throw new MeasureError('CODEX_MEASURE_CHECK_MISMATCH', `evidence for check ${claimed.check} does not match its executed command and output`);
    }
    const expectation = parseCheckExpectation(planned.expect);
    if (expectation === null) throw new MeasureError('CODEX_MEASURE_EXPECT_UNSUPPORTED', `check ${claimed.check} has an unverifiable expected result`);
    const quotable = expectation.kind === 'exit' ? record.output : record.commandOutput;
    if (typeof quotable !== 'string' || !ws(quotable).includes(ws(claimed.quote))) {
      throw new MeasureError('CODEX_MEASURE_CHECK_MISMATCH', `evidence for check ${claimed.check} does not quote the recorded output`);
    }
    if (typeof record.commandOutput !== 'string' || !checkMatchesExpectation(expectation, record.exitCode, record.commandOutput)) {
      throw new MeasureError('CODEX_MEASURE_CHECK_FAILED', `check ${claimed.check} did not show its planned result`);
    }
    const beforeFinalTurn = !Number.isFinite(timeOf(record.completedAt)) || timeOf(record.completedAt) < finalStartedAt;
    if (beforeFinalTurn && (repo === undefined || record.tree === undefined || record.tree !== currentTree())) {
      throw new MeasureError('CODEX_MEASURE_CHECK_STALE', `check ${claimed.check} was recorded before the final subagent turn, and no matching worktree signature shows the worktree unchanged since`);
    }
    const sources = beforeFinalTurn ? allCommands : finalCommands;
    if (!sources.some((command) => invocationMatches(command, { run, action, check: record.check }))) {
      throw new MeasureError('CODEX_MEASURE_CHECK_UNSOURCED', `check ${record.check} has no matching runner invocation in the subagent rollout`);
    }
    if (claimed.command !== record.command || claimed.exitCode !== record.exitCode) {
      const note = `check ${claimed.check}: command and exit code taken from the runner record`;
      if (!notes.includes(note)) notes.push(note);
    }
    return { ...claimed, command: record.command, exitCode: record.exitCode };
  });
  return { item: { ...array[0], evidence }, repairs: notes, toolCalls };
}

function validateClassReply(cli, item, handed, action) {
  const temp = path.join(handed, `.${action}-validate-${process.pid}.json`);
  try {
    writeFileSync(temp, JSON.stringify(item), { flag: 'wx' });
    const result = spawnSync(process.execPath, [cli, 'class-check', '--host', 'codex', '--class', item.classId, '--output', temp], { encoding: 'utf8' });
    if (result.status !== 0) throw new MeasureError('CODEX_MEASURE_REPLY_INVALID', 'subagent reply fails its Class contract', { error: result.stderr.trim().slice(0, 1000) });
  } finally { rmSync(temp, { force: true }); }
}

function writesOf(v) {
  if (v.repo === undefined) return undefined;
  const result = spawnSync(process.execPath, [v.cli, 'writes', 'measure', '--repo', v.repo, '--before', v.before], { encoding: 'utf8' });
  if (result.status !== 0) throw new MeasureError('CODEX_MEASURE_WRITES_FAILED', 'write measurement failed', { error: result.stderr.trim().slice(0, 1000) });
  try { return JSON.parse(result.stdout); }
  catch { throw new MeasureError('CODEX_MEASURE_WRITES_FAILED', 'write measurement did not return JSON'); }
}

function writePair(handed, action, reply, meta) {
  const out = path.join(handed, `${action}-output.txt`);
  const hostMeta = path.join(handed, `${action}-meta.json`);
  if (existsSync(out) || existsSync(hostMeta)) throw new MeasureError('CODEX_MEASURE_ALREADY_WRITTEN', 'receipt files already exist for this action');
  const outTemp = `${out}.tmp-${process.pid}`;
  const metaTemp = `${hostMeta}.tmp-${process.pid}`;
  let outputInstalled = false;
  try {
    writeFileSync(outTemp, reply, { flag: 'wx' });
    writeFileSync(metaTemp, JSON.stringify(meta, null, 2) + '\n', { flag: 'wx' });
    renameSync(outTemp, out);
    outputInstalled = true;
    renameSync(metaTemp, hostMeta);
  } catch (err) {
    if (outputInstalled) rmSync(out, { force: true });
    throw err;
  } finally {
    rmSync(outTemp, { force: true });
    rmSync(metaTemp, { force: true });
  }
}

function main(args) {
  const v = flagsOf(args);
  const saved = JSON.parse(readFileSync(path.join(v.run, 'state.json'), 'utf8'));
  if (saved.host?.id !== 'codex' || !saved.host.modelBinding) {
    throw new MeasureError('CODEX_MEASURE_HOST_UNBOUND', 'the saved run has no Codex model binding');
  }
  const parentSessionId = process.env.CODEX_SESSION_ID;
  if (!/^[0-9a-f-]{36}$/.test(parentSessionId ?? '')) throw new MeasureError('CODEX_MEASURE_PARENT_UNAVAILABLE', 'the active Codex parent session ID is unavailable');
  const file = findSession(v['sessions-root'], v.agent, PREFIX);
  const events = entriesOf(file, PREFIX);
  assertChildOf(sessionMetaOf(events, PREFIX), v.agent, parentSessionId, PREFIX);
  const userMessages = events.filter((e) => e.type === 'response_item' && e.payload?.type === 'message' && e.payload.role === 'user');
  if (!userMessages.some((e) => JSON.stringify(e.payload.content).includes(v.brief) && JSON.stringify(e.payload.content).includes(v.action))) {
    throw new MeasureError('CODEX_MEASURE_ACTION_MISMATCH', 'subagent prompt does not name this action and brief');
  }
  const done = finalReplyOf(events, PREFIX);
  const binding = modelOf(events, PREFIX);
  if (binding.model !== saved.host.modelBinding.model || binding.reasoningEffort !== saved.host.modelBinding.reasoningEffort) {
    throw new MeasureError('CODEX_MEASURE_MODEL_MISMATCH', 'subagent model or effort differs from the saved host binding', { expected: saved.host.modelBinding, actual: binding });
  }
  const handed = path.join(v.run, 'handed');
  const finalStartIndex = events.findLastIndex((e) => e.type === 'event_msg' && e.payload?.type === 'task_started');
  const finalStartedAt = timeOf(events[finalStartIndex]?.payload?.started_at);
  if (!Number.isFinite(finalStartedAt)) throw new MeasureError('CODEX_MEASURE_INCOMPLETE', 'the final subagent turn has no start time');
  const plannedChecks = saved.pendingAction?.kind === 'dispatch-changer'
    ? saved.brief.tasks.plan[saved.cursor].doneWhen
    : saved.pendingAction?.kind === 'dispatch-judge'
      ? saved.brief.tasks.plan.flatMap((task) => task.doneWhen)
      : [];
  const { item, repairs, toolCalls } = checkedReply(done.reply, handed, v.action, v.run, v.repo, commandsOf(events.slice(finalStartIndex)), commandsOf(events), plannedChecks, finalStartedAt);
  validateClassReply(v.cli, item, handed, v.action);
  const usage = usageOf(events, PREFIX);
  const seconds = Math.round((timeOf(done.completedAt) - timeOf(done.startedAt)) / 1000);
  if (Number.isFinite(seconds) && seconds >= 0) usage.latencySeconds = seconds;
  const writes = writesOf(v);
  if (saved.pendingAction?.kind === 'dispatch-judge') {
    if (writes?.availability !== 'measured' || !Array.isArray(writes.paths)) throw new MeasureError('CODEX_MEASURE_READ_ONLY_UNVERIFIED', 'Inspector needs a measured worktree baseline');
    if (writes.paths.length > 0) throw new MeasureError('CODEX_MEASURE_READ_ONLY_WRITE', 'Inspector changed the worktree', { paths: writes.paths });
  }
  const hostMeta = { modelBinding: binding, usage, toolCalls, repairs, ...(writes === undefined ? {} : { writes }) };
  writePair(handed, v.action, JSON.stringify([item]), hostMeta);
  return { agentId: v.agent, actionId: v.action, tokens: usage.inputTokens + usage.cacheWriteTokens + usage.outputTokens, checks: toolCalls.length };
}

try { process.stdout.write(JSON.stringify(main(process.argv.slice(2))) + '\n'); }
catch (err) { process.stderr.write(JSON.stringify({ error: { code: err.code ?? 'CODEX_MEASURE_UNEXPECTED', message: err.message, details: err.details ?? {} } }) + '\n'); process.exit(1); }
