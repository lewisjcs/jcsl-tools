#!/usr/bin/env node
/** Hand back one completed native Codex subagent's reply and usage for a kickoff or direct Class call. Reads the child's own rollout. Runs no Class check. */
import { writeFileSync, renameSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { RolloutError, findSession, entriesOf, usageOf, sessionMetaOf, assertChildOf, modelOf, finalReplyOf } from '../rollout.mjs';

const PREFIX = 'CODEX_REPLY';

function flagsOf(args) {
  const { values } = parseArgs({ args, options: { 'sessions-root': { type: 'string' }, agent: { type: 'string' }, marker: { type: 'string' }, out: { type: 'string' } } });
  for (const key of ['agent', 'marker', 'out']) {
    if (!values[key]) throw new RolloutError(`${PREFIX}_FLAGS`, `--${key} is required`);
  }
  return { ...values, 'sessions-root': values['sessions-root'] ?? path.join(process.env.CODEX_HOME ?? path.join(homedir(), '.codex'), 'sessions') };
}

function itemOf(reply) {
  const fenced = /^```json[ \t]*\r?\n([\s\S]*?)\r?\n```[ \t]*$/.exec(reply.trim());
  const text = fenced === null ? reply : fenced[1];
  let result;
  try { result = JSON.parse(text); }
  catch { throw new RolloutError(`${PREFIX}_INVALID`, 'subagent final message is not JSON'); }
  if (!Array.isArray(result) || result.length !== 1 || typeof result[0] !== 'object' || result[0] === null || Array.isArray(result[0])) {
    throw new RolloutError(`${PREFIX}_INVALID`, 'subagent final message must be a one-item outcome array');
  }
  return { item: result[0], text };
}

function writeAll(out, files) {
  const finals = Object.keys(files).map((name) => path.join(out, name));
  if (finals.some((file) => existsSync(file))) throw new RolloutError(`${PREFIX}_ALREADY_WRITTEN`, 'reply files already exist in this folder');
  const temps = finals.map((file) => `${file}.tmp-${process.pid}`);
  const installed = [];
  try {
    Object.values(files).forEach((content, i) => writeFileSync(temps[i], content, { flag: 'wx' }));
    finals.forEach((file, i) => { renameSync(temps[i], file); installed.push(file); });
  } catch (err) {
    for (const file of installed) rmSync(file, { force: true });
    throw err;
  } finally {
    for (const temp of temps) rmSync(temp, { force: true });
  }
}

function main(args) {
  const v = flagsOf(args);
  const parentSessionId = process.env.CODEX_SESSION_ID;
  if (!/^[0-9a-f-]{36}$/.test(parentSessionId ?? '')) throw new RolloutError(`${PREFIX}_PARENT_UNAVAILABLE`, 'the active Codex parent session ID is unavailable');
  const events = entriesOf(findSession(v['sessions-root'], v.agent, PREFIX), PREFIX);
  assertChildOf(sessionMetaOf(events, PREFIX), v.agent, parentSessionId, PREFIX);
  const userMessages = events.filter((e) => e.type === 'response_item' && e.payload?.type === 'message' && e.payload.role === 'user');
  if (!userMessages.some((e) => JSON.stringify(e.payload.content).includes(JSON.stringify(v.marker).slice(1, -1)))) {
    throw new RolloutError(`${PREFIX}_PROMPT_MISMATCH`, 'subagent prompt does not name the marker');
  }
  const done = finalReplyOf(events, PREFIX);
  const { item, text } = itemOf(done.reply);
  const binding = modelOf(events, PREFIX);
  const usage = usageOf(events, PREFIX);
  const seconds = Math.round((Date.parse(done.completedAt) - Date.parse(done.startedAt)) / 1000);
  if (Number.isFinite(seconds) && seconds >= 0) usage.latencySeconds = seconds;
  writeAll(v.out, {
    'reply.txt': text,
    'reply.json': JSON.stringify(item, null, 2) + '\n',
    'meta.json': JSON.stringify({ modelBinding: binding, usage }, null, 2) + '\n'
  });
  return { agentId: v.agent, corrections: done.corrections, tokens: usage.inputTokens + usage.cacheWriteTokens + usage.outputTokens };
}

try { process.stdout.write(JSON.stringify(main(process.argv.slice(2))) + '\n'); }
catch (err) { process.stderr.write(JSON.stringify({ error: { code: err.code ?? `${PREFIX}_UNEXPECTED`, message: err.message, details: err.details ?? {} } }) + '\n'); process.exit(1); }
