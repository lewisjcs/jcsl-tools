#!/usr/bin/env node
/**
 * Measure the Designer's window in the Codex main thread. The Designer is a skill, so no child rollout holds its work.
 * Reads the parent session's own rollout: window usage = the last cumulative `token_count` total at or after --since
 * minus the last total before it (zero when none), plus the whole usage of every child the session spawned in the window.
 * Time rule: every rollout line is { timestamp, ordinal, type, payload }. The script reads the top-level `timestamp` of a
 * parent `token_count` line and nothing else for its time; there is no fallback. A parent count with no valid
 * `timestamp` is CODEX_WINDOW_MALFORMED.
 * Child scan: only the date folders (sessions/YYYY/MM/DD) from the day before the --since date on (folders use the local
 * date and --since is UTC); the child's first task_started.started_at then decides, so the extra day costs only a read.
 * A candidate file is first judged by its first line alone (the session_meta). Only a file whose parent is this session gets the
 * strict full parse, so another session's half-written rollout never stops the measurement.
 * Output: { modelBinding, usage: { inputTokens, cacheWriteTokens, cacheReadTokens, outputTokens, turns, children, unmeasuredChildren } }.
 * `children` lists the measured children. A child of this session with no token count adds zero and is named in `unmeasuredChildren`.
 */
import { writeFileSync, renameSync, rmSync, existsSync, readdirSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { RolloutError, findSession, entriesOf, usageOf } from '../rollout.mjs';

const PREFIX = 'CODEX_WINDOW';
const COUNTERS = ['input_tokens', 'cached_input_tokens', 'cache_write_input_tokens', 'output_tokens'];

function flagsOf(args) {
  const { values } = parseArgs({ args, options: { 'sessions-root': { type: 'string' }, since: { type: 'string' }, out: { type: 'string' } } });
  for (const key of ['since', 'out']) {
    if (!values[key]) throw new RolloutError(`${PREFIX}_FLAGS`, `--${key} is required`);
  }
  const since = Date.parse(values.since);
  if (!Number.isFinite(since)) throw new RolloutError(`${PREFIX}_SINCE_INVALID`, '--since is not a timestamp', { since: values.since });
  return { since, out: values.out, sessionsRoot: values['sessions-root'] ?? path.join(process.env.CODEX_HOME ?? path.join(homedir(), '.codex'), 'sessions') };
}

function parentWindow(events, since) {
  const counts = events.filter((e) => e.type === 'event_msg' && e.payload?.type === 'token_count' && e.payload.info?.total_token_usage)
    .map((e) => {
      const at = Date.parse(e.timestamp);
      if (!Number.isFinite(at)) throw new RolloutError(`${PREFIX}_MALFORMED`, 'a parent token count has no valid top-level timestamp');
      const total = e.payload.info.total_token_usage;
      for (const key of COUNTERS) {
        if (!Number.isSafeInteger(total[key]) || total[key] < 0) throw new RolloutError(`${PREFIX}_USAGE_MALFORMED`, `${key} is not a nonnegative integer`);
      }
      return { at, total };
    });
  const inWindow = counts.filter((c) => c.at >= since);
  if (inWindow.length === 0) return { inputTokens: 0, cacheWriteTokens: 0, cacheReadTokens: 0, outputTokens: 0, turns: 0 };
  const base = counts.filter((c) => c.at < since).at(-1)?.total ?? Object.fromEntries(COUNTERS.map((k) => [k, 0]));
  const last = inWindow.at(-1).total;
  const diff = Object.fromEntries(COUNTERS.map((k) => [k, last[k] - base[k]]));
  const fresh = diff.input_tokens - diff.cached_input_tokens - diff.cache_write_input_tokens;
  if (COUNTERS.some((k) => diff[k] < 0) || fresh < 0) throw new RolloutError(`${PREFIX}_USAGE_MALFORMED`, 'cumulative token totals went down inside the window');
  return { inputTokens: fresh, cacheWriteTokens: diff.cache_write_input_tokens, cacheReadTokens: diff.cached_input_tokens, outputTokens: diff.output_tokens, turns: inWindow.length };
}

function bindingOf(events) {
  const context = events.filter((e) => e.type === 'turn_context').at(-1)?.payload;
  if (typeof context?.model !== 'string' || !context.model || typeof context.effort !== 'string' || !context.effort) {
    throw new RolloutError(`${PREFIX}_MODEL_UNBOUND`, 'the session has no model and effort in its last turn context');
  }
  return { model: context.model, reasoningEffort: context.effort };
}

const numbered = (dir) => readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory() && /^\d+$/.test(d.name)).map((d) => d.name).sort();

function dayFolders(root, since) {
  const from = new Date(since - 24 * 3600 * 1000).toISOString().slice(0, 10);
  const days = [];
  for (const y of numbered(root)) for (const m of numbered(path.join(root, y))) for (const d of numbered(path.join(root, y, m))) {
    if (`${y}-${m}-${d}` >= from) days.push(path.join(root, y, m, d));
  }
  return days;
}

/** The payload of the file's first line when that line is a session_meta, else null. Never throws on a bad line. */
function firstMetaOf(file) {
  try {
    const event = JSON.parse(readFileSync(file, 'utf8').split('\n', 1)[0]);
    return event?.type === 'session_meta' ? event.payload : null;
  } catch { return null; }
}

function childrenIn(root, parentId, since) {
  const found = [];
  for (const day of dayFolders(root, since)) {
    for (const entry of readdirSync(day, { withFileTypes: true })) {
      if (!entry.isFile() || !entry.name.endsWith('.jsonl')) continue;
      const file = path.join(day, entry.name);
      if (firstMetaOf(file)?.source?.subagent?.thread_spawn?.parent_thread_id !== parentId) continue;
      const events = entriesOf(file, PREFIX);
      const meta = events.find((e) => e.type === 'session_meta').payload;
      const startedAt = Date.parse(events.find((e) => e.type === 'event_msg' && e.payload?.type === 'task_started')?.payload.started_at);
      if (!Number.isFinite(startedAt) || startedAt < since) continue;
      let usage = null;
      try { usage = usageOf(events, PREFIX); }
      catch (err) { if (err.code !== `${PREFIX}_USAGE_MISSING`) throw err; }
      found.push({ id: meta.id, usage });
    }
  }
  return found.sort((a, b) => (a.id < b.id ? -1 : 1));
}

function main(args) {
  const v = flagsOf(args);
  const sessionId = process.env.CODEX_SESSION_ID;
  if (!/^[0-9a-f-]{36}$/.test(sessionId ?? '')) throw new RolloutError(`${PREFIX}_SESSION_UNAVAILABLE`, 'the active Codex session ID is unavailable');
  if (existsSync(v.out)) throw new RolloutError(`${PREFIX}_ALREADY_WRITTEN`, 'the output file already exists', { out: v.out });
  const events = entriesOf(findSession(v.sessionsRoot, sessionId, PREFIX), PREFIX);
  const usage = parentWindow(events, v.since);
  const all = childrenIn(v.sessionsRoot, sessionId, v.since);
  const children = all.filter((c) => c.usage !== null);
  for (const c of children) {
    for (const key of ['inputTokens', 'cacheWriteTokens', 'cacheReadTokens', 'outputTokens']) usage[key] += c.usage[key];
  }
  usage.children = children.map((c) => c.id);
  usage.unmeasuredChildren = all.filter((c) => c.usage === null).map((c) => c.id);
  const temp = `${v.out}.tmp-${process.pid}`;
  try {
    writeFileSync(temp, JSON.stringify({ modelBinding: bindingOf(events), usage }, null, 2) + '\n', { flag: 'wx' });
    renameSync(temp, v.out);
  } finally { rmSync(temp, { force: true }); }
  return { children: usage.children.length, turns: usage.turns };
}

try { process.stdout.write(JSON.stringify(main(process.argv.slice(2))) + '\n'); }
catch (err) { process.stderr.write(JSON.stringify({ error: { code: err.code ?? `${PREFIX}_UNEXPECTED`, message: err.message, details: err.details ?? {} } }) + '\n'); process.exit(1); }
