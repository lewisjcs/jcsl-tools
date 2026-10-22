#!/usr/bin/env node
/** Turn one completed native Codex subagent into a Kiln receipt. Reads the child's own rollout, not the parent's retelling. */
import { readFileSync, readdirSync, writeFileSync, renameSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';
import { checkInvocation } from '../check-command.mjs';
import { parseCheckExpectation, checkMatchesExpectation } from '../check-expectation.mjs';

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

function findSession(root, agent) {
  if (!existsSync(root)) throw new MeasureError('CODEX_MEASURE_SESSION_MISSING', 'Codex sessions directory is missing', { root });
  const files = readdirSync(root, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(`-${agent}.jsonl`))
    .map((entry) => path.join(entry.parentPath, entry.name));
  if (files.length !== 1) throw new MeasureError('CODEX_MEASURE_SESSION_MISSING', `expected one rollout for agent ${agent}, found ${files.length}`, { agent, count: files.length });
  return files[0];
}

function entriesOf(file) {
  return readFileSync(file, 'utf8').split('\n').filter(Boolean).map((line, i) => {
    try { return JSON.parse(line); }
    catch { throw new MeasureError('CODEX_MEASURE_MALFORMED', `rollout line ${i + 1} is not JSON`, { file, line: i + 1 }); }
  });
}

function one(list, code, message) {
  if (list.length !== 1) throw new MeasureError(code, message, { count: list.length });
  return list[0];
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

function usageOf(events) {
  const counts = events.filter((e) => e.type === 'event_msg' && e.payload?.type === 'token_count')
    .map((e) => e.payload.info?.total_token_usage).filter(Boolean);
  if (counts.length === 0) throw new MeasureError('CODEX_MEASURE_USAGE_MISSING', 'the subagent has no token count');
  const total = counts.at(-1);
  for (const key of ['input_tokens', 'cached_input_tokens', 'cache_write_input_tokens', 'output_tokens']) {
    if (!Number.isSafeInteger(total[key]) || total[key] < 0) throw new MeasureError('CODEX_MEASURE_USAGE_MALFORMED', `${key} is not a nonnegative integer`);
  }
  const fresh = total.input_tokens - total.cached_input_tokens - total.cache_write_input_tokens;
  if (fresh < 0) throw new MeasureError('CODEX_MEASURE_USAGE_MALFORMED', 'cached and cache-write tokens exceed input tokens');
  const totals = counts.map((c) => c.total_tokens);
  if (totals.some((n, i) => !Number.isSafeInteger(n) || (i > 0 && n <= totals[i - 1]))) {
    throw new MeasureError('CODEX_MEASURE_USAGE_MALFORMED', 'cumulative token counts are not strictly increasing');
  }
  return { inputTokens: fresh, cacheWriteTokens: total.cache_write_input_tokens, cacheReadTokens: total.cached_input_tokens, outputTokens: total.output_tokens, turns: counts.length };
}

function checkedReply(reply, handed, action, run, cli, commands, plannedChecks, finalStartedAt) {
  let result;
  const fenced = /^```json[ \t]*\r?\n([\s\S]*?)\r?\n```[ \t]*$/.exec(reply.trim());
  try { result = JSON.parse(fenced === null ? reply : fenced[1]); }
  catch { throw new MeasureError('CODEX_MEASURE_REPLY_INVALID', 'subagent final message is not JSON'); }
  if (!Array.isArray(result) || result.length !== 1 || typeof result[0] !== 'object' || result[0] === null) {
    throw new MeasureError('CODEX_MEASURE_REPLY_INVALID', 'subagent final message must be a one-item outcome array');
  }
  const item = result[0];
  const records = readdirSync(handed).filter((name) => name.startsWith(`${action}-check-`) && name.endsWith('.json')).map((name) => {
    try { return JSON.parse(readFileSync(path.join(handed, name), 'utf8')); }
    catch { throw new MeasureError('CODEX_MEASURE_CHECK_MALFORMED', `invalid check record ${name}`); }
  });
  if (item.status === 'complete') {
    if (!Array.isArray(item.evidence) || item.evidence.length !== plannedChecks.length || records.length !== plannedChecks.length) {
      throw new MeasureError('CODEX_MEASURE_CHECK_MISMATCH', 'completed reply does not cover every recorded check');
    }
    for (const evidence of item.evidence) {
      const record = records.find((r) => r.check === evidence.check && r.actionId === action);
      const planned = plannedChecks[evidence.check - 1];
      if (!record || !planned || record.command !== planned.command || record.expect !== planned.expect || record.command !== evidence.command || record.exitCode !== evidence.exitCode || typeof evidence.quote !== 'string') {
        throw new MeasureError('CODEX_MEASURE_CHECK_MISMATCH', `evidence for check ${evidence.check} does not match its executed command and output`);
      }
      const expectation = parseCheckExpectation(planned.expect);
      if (expectation === null) throw new MeasureError('CODEX_MEASURE_EXPECT_UNSUPPORTED', `check ${evidence.check} has an unverifiable expected result`);
      const quotable = expectation.kind === 'exit' ? record.output : record.commandOutput;
      if (typeof quotable !== 'string' || !quotable.includes(evidence.quote) || !record.output.includes(evidence.quote)) {
        throw new MeasureError('CODEX_MEASURE_CHECK_MISMATCH', `evidence for check ${evidence.check} does not quote the recorded output`);
      }
      if (typeof record.commandOutput !== 'string' || !checkMatchesExpectation(expectation, record.exitCode, record.commandOutput)) {
        throw new MeasureError('CODEX_MEASURE_CHECK_FAILED', `check ${evidence.check} did not show its planned result`);
      }
      if (!Number.isFinite(Date.parse(record.completedAt)) || Date.parse(record.completedAt) < finalStartedAt) {
        throw new MeasureError('CODEX_MEASURE_CHECK_STALE', `check ${evidence.check} was not recorded in the final subagent turn`);
      }
      const invocation = checkInvocation({ run, action, check: record.check, cli });
      if (!commands.includes(invocation)) throw new MeasureError('CODEX_MEASURE_CHECK_UNSOURCED', `check ${record.check} has no matching runner invocation in the subagent rollout`);
    }
  }
  return { item, toolCalls: records.sort((a, b) => a.check - b.check).map((record) => ({ tool: 'Bash', target: record.command.slice(0, 120) })) };
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
  const file = findSession(v['sessions-root'], v.agent);
  const events = entriesOf(file);
  const meta = one(events.filter((e) => e.type === 'session_meta').map((e) => e.payload), 'CODEX_MEASURE_SESSION_MISSING', 'expected one session header');
  if (meta.id !== v.agent || meta.source?.subagent?.thread_spawn === undefined) throw new MeasureError('CODEX_MEASURE_NOT_SUBAGENT', 'rollout is not the selected native subagent');
  if (meta.source.subagent.thread_spawn.parent_thread_id !== parentSessionId) throw new MeasureError('CODEX_MEASURE_PARENT_MISMATCH', 'subagent does not belong to the active Codex session');
  const userMessages = events.filter((e) => e.type === 'response_item' && e.payload?.type === 'message' && e.payload.role === 'user');
  if (!userMessages.some((e) => JSON.stringify(e.payload.content).includes(v.brief) && JSON.stringify(e.payload.content).includes(v.action))) {
    throw new MeasureError('CODEX_MEASURE_ACTION_MISMATCH', 'subagent prompt does not name this action and brief');
  }
  const completions = events.filter((e) => e.type === 'event_msg' && e.payload?.type === 'task_complete').map((e) => e.payload);
  const starts = events.filter((e) => e.type === 'event_msg' && e.payload?.type === 'task_started').map((e) => e.payload);
  if (completions.length === 0 || completions.length !== starts.length || completions.length > 2) {
    throw new MeasureError('CODEX_MEASURE_INCOMPLETE', 'subagent has an unfinished task or more than one correction', { starts: starts.length, completions: completions.length });
  }
  const done = completions.at(-1);
  if (typeof done.last_agent_message !== 'string' || done.last_agent_message.length === 0) throw new MeasureError('CODEX_MEASURE_INCOMPLETE', 'subagent has no final reply');
  const contexts = events.filter((e) => e.type === 'turn_context').map((e) => e.payload);
  const models = new Set(contexts.map((c) => `${c.model}|${c.effort}`));
  if (models.size !== 1 || !contexts[0]?.model || !contexts[0]?.effort) throw new MeasureError('CODEX_MEASURE_MODEL_UNBOUND', 'subagent model or effort is unavailable or changed');
  if (contexts[0].model !== saved.host.modelBinding.model || contexts[0].effort !== saved.host.modelBinding.reasoningEffort) {
    throw new MeasureError('CODEX_MEASURE_MODEL_MISMATCH', 'subagent model or effort differs from the saved host binding', { expected: saved.host.modelBinding, actual: { model: contexts[0].model, reasoningEffort: contexts[0].effort } });
  }
  const handed = path.join(v.run, 'handed');
  const finalStartIndex = events.findLastIndex((e) => e.type === 'event_msg' && e.payload?.type === 'task_started');
  const finalStartedAt = Date.parse(events[finalStartIndex]?.payload?.started_at);
  if (!Number.isFinite(finalStartedAt)) throw new MeasureError('CODEX_MEASURE_INCOMPLETE', 'the final subagent turn has no start time');
  const plannedChecks = saved.pendingAction?.kind === 'dispatch-changer'
    ? saved.brief.tasks.plan[saved.cursor].doneWhen
    : saved.pendingAction?.kind === 'dispatch-judge'
      ? saved.brief.tasks.plan.flatMap((task) => task.doneWhen)
      : [];
  const { item, toolCalls } = checkedReply(done.last_agent_message, handed, v.action, v.run, v.cli, commandsOf(events.slice(finalStartIndex)), plannedChecks, finalStartedAt);
  validateClassReply(v.cli, item, handed, v.action);
  const usage = usageOf(events);
  const seconds = Math.round((Date.parse(done.completed_at) - Date.parse(starts[0].started_at)) / 1000);
  if (Number.isFinite(seconds) && seconds >= 0) usage.latencySeconds = seconds;
  const writes = writesOf(v);
  if (saved.pendingAction?.kind === 'dispatch-judge') {
    if (writes?.availability !== 'measured' || !Array.isArray(writes.paths)) throw new MeasureError('CODEX_MEASURE_READ_ONLY_UNVERIFIED', 'Inspector needs a measured worktree baseline');
    if (writes.paths.length > 0) throw new MeasureError('CODEX_MEASURE_READ_ONLY_WRITE', 'Inspector changed the worktree', { paths: writes.paths });
  }
  const hostMeta = { modelBinding: { model: contexts[0].model, reasoningEffort: contexts[0].effort }, usage, toolCalls, ...(writes === undefined ? {} : { writes }) };
  writePair(handed, v.action, done.last_agent_message, hostMeta);
  return { agentId: v.agent, actionId: v.action, tokens: usage.inputTokens + usage.cacheWriteTokens + usage.outputTokens, checks: toolCalls.length };
}

try { process.stdout.write(JSON.stringify(main(process.argv.slice(2))) + '\n'); }
catch (err) { process.stderr.write(JSON.stringify({ error: { code: err.code ?? 'CODEX_MEASURE_UNEXPECTED', message: err.message, details: err.details ?? {} } }) + '\n'); process.exit(1); }
