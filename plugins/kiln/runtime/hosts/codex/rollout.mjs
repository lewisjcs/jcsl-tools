/** Read one native Codex subagent's own rollout. Every function takes a code prefix last, so each script keeps its own error codes. */
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import path from 'node:path';

export class RolloutError extends Error {
  constructor(code, message, details = {}) { super(message); this.code = code; this.details = details; }
}

export function findSession(root, agent, prefix) {
  if (!existsSync(root)) throw new RolloutError(`${prefix}_SESSION_MISSING`, 'Codex sessions directory is missing', { root });
  const files = readdirSync(root, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(`-${agent}.jsonl`))
    .map((entry) => path.join(entry.parentPath, entry.name));
  if (files.length !== 1) throw new RolloutError(`${prefix}_SESSION_MISSING`, `expected one rollout for agent ${agent}, found ${files.length}`, { agent, count: files.length });
  return files[0];
}

export function entriesOf(file, prefix) {
  return readFileSync(file, 'utf8').split('\n').filter(Boolean).map((line, i) => {
    try { return JSON.parse(line); }
    catch { throw new RolloutError(`${prefix}_MALFORMED`, `rollout line ${i + 1} is not JSON`, { file, line: i + 1 }); }
  });
}

export function usageOf(events, prefix) {
  const counts = events.filter((e) => e.type === 'event_msg' && e.payload?.type === 'token_count')
    .map((e) => e.payload.info?.total_token_usage).filter(Boolean);
  if (counts.length === 0) throw new RolloutError(`${prefix}_USAGE_MISSING`, 'the subagent has no token count');
  const total = counts.at(-1);
  for (const key of ['input_tokens', 'cached_input_tokens', 'cache_write_input_tokens', 'output_tokens']) {
    if (!Number.isSafeInteger(total[key]) || total[key] < 0) throw new RolloutError(`${prefix}_USAGE_MALFORMED`, `${key} is not a nonnegative integer`);
  }
  const fresh = total.input_tokens - total.cached_input_tokens - total.cache_write_input_tokens;
  if (fresh < 0) throw new RolloutError(`${prefix}_USAGE_MALFORMED`, 'cached and cache-write tokens exceed input tokens');
  const totals = counts.map((c) => c.total_tokens);
  if (totals.some((n, i) => !Number.isSafeInteger(n) || (i > 0 && n <= totals[i - 1]))) {
    throw new RolloutError(`${prefix}_USAGE_MALFORMED`, 'cumulative token counts are not strictly increasing');
  }
  return { inputTokens: fresh, cacheWriteTokens: total.cache_write_input_tokens, cacheReadTokens: total.cached_input_tokens, outputTokens: total.output_tokens, turns: counts.length };
}

export function sessionMetaOf(events, prefix) {
  const metas = events.filter((e) => e.type === 'session_meta').map((e) => e.payload);
  if (metas.length !== 1) throw new RolloutError(`${prefix}_SESSION_MISSING`, 'expected one session header', { count: metas.length });
  return metas[0];
}

export function assertChildOf(meta, agentId, parentSessionId, prefix) {
  if (meta.id !== agentId || meta.source?.subagent?.thread_spawn === undefined) throw new RolloutError(`${prefix}_NOT_SUBAGENT`, 'rollout is not the selected native subagent');
  if (meta.source.subagent.thread_spawn.parent_thread_id !== parentSessionId) throw new RolloutError(`${prefix}_PARENT_MISMATCH`, 'subagent does not belong to the active Codex session');
}

export function modelOf(events, prefix) {
  const contexts = events.filter((e) => e.type === 'turn_context').map((e) => e.payload);
  const models = new Set(contexts.map((c) => `${c.model}|${c.effort}`));
  if (models.size !== 1 || !contexts[0]?.model || !contexts[0]?.effort) throw new RolloutError(`${prefix}_MODEL_UNBOUND`, 'subagent model or effort is unavailable or changed');
  return { model: contexts[0].model, reasoningEffort: contexts[0].effort };
}

export function finalReplyOf(events, prefix) {
  const completions = events.filter((e) => e.type === 'event_msg' && e.payload?.type === 'task_complete').map((e) => e.payload);
  const starts = events.filter((e) => e.type === 'event_msg' && e.payload?.type === 'task_started').map((e) => e.payload);
  if (completions.length === 0 || completions.length !== starts.length || completions.length > 2) {
    throw new RolloutError(`${prefix}_INCOMPLETE`, 'subagent has an unfinished task or more than one correction', { starts: starts.length, completions: completions.length });
  }
  const done = completions.at(-1);
  if (typeof done.last_agent_message !== 'string' || done.last_agent_message.length === 0) throw new RolloutError(`${prefix}_INCOMPLETE`, 'subagent has no final reply');
  return { reply: done.last_agent_message, startedAt: starts[0].started_at, completedAt: done.completed_at, corrections: completions.length - 1 };
}
