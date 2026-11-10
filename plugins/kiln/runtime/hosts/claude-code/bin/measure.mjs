#!/usr/bin/env node
/**
 * The measure script of the Claude Code host (requirements 52 to 54, Design:
 * Brief by reference). After a member dispatch ends, the build skill runs it
 * with the agent id, the action id, the run folder, and the model binding.
 * It finds the dispatch transcript under the Claude configuration directory,
 * takes the member's reply from the hand-back tool input (or, with no
 * hand-back, from the last text block of the last assistant message, noted
 * in the meta's `repairs`), and writes the output file and the meta file
 * into `<run dir>/handed/`. With `--cli`, `--repo`, and `--before`, it also
 * runs the command line's write measurement and puts the result under
 * `writes`. With `--after <ISO time>`, it measures a correction that the
 * build skill sent to the same agent: only the entries stamped after that
 * time count, and an entry with no timestamp is left out. The usage, the tool
 * calls, the latency, the hand-back, and the final text then come from the
 * kept entries alone, and `MEASURE_NO_HANDBACK` applies to them. The build
 * skill reads that time from the `lastTimestamp` of the corrected action's
 * meta file: the latest timestamp the script kept, left out when no kept
 * entry has one. The meta's `agentId` is the `--agent` value, so a resumed
 * session can still send a correction to the same agent. When the reply, with
 * one pair of backticks or quotes stripped, is the path of a reply file
 * `<run dir>/handed/<action id>-outcome.json`, the reply is that file's content
 * (see `replyFileContent`); any other absolute path is the reply as written,
 * with a `repairs` note, and its file is never read.
 * An `--after` value that is not a date is
 * `MEASURE_FLAG_INVALID`. It prints one summary line with no action id and
 * no path, because the build skill shows it to the person. On any failure it
 * prints a typed error on stderr, exits 1, and writes nothing. It imports
 * nothing from `src/`, so it runs from the payload as it is.
 *
 * Usage:
 *   node measure.mjs --agent <id> --action <actionId> --run <run dir> --model <binding> [--after <ISO time>] [--cli <cli.mjs> --repo <root> --before <before.json>]
 *
 * The usage groups the assistant lines by message id and keeps the last line
 * of each group, because a streamed message repeats its earlier lines. No
 * output token figure is ever written: the transcript carries a placeholder.
 * The tool calls are every tool_use block, deduplicated by block id. A Bash
 * call's target is its whole command. Any other call's target is its whole
 * path, pattern, or URL. The latency is the span between
 * the first and last timestamps the script keeps. The final text is the last text
 * block of the last assistant message (one message repeats its id across
 * entries). The hand-back wins when both exist. `MEASURE_NO_HANDBACK` means
 * neither exists. A transcript with a reply has at least one assistant line,
 * so the meta file always holds the usage and the tool calls, and `repairs`
 * (an array of strings, empty when the hand-back was used and, if it named an absolute path, that path was a reply file that was read).
 */
import { readFileSync, readdirSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';

const TARGET_KEYS = ['file_path', 'pattern', 'path', 'notebook_path', 'url'];
const HANDBACK = 'SubagentHandback';

class MeasureError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function flagsOf(argv) {
  let values;
  try {
    ({ values } = parseArgs({ args: argv, options: { agent: { type: 'string' }, action: { type: 'string' }, run: { type: 'string' }, model: { type: 'string' }, after: { type: 'string' }, cli: { type: 'string' }, repo: { type: 'string' }, before: { type: 'string' } }, allowPositionals: false }));
  } catch (err) {
    throw new MeasureError('MEASURE_FLAG_MISSING', err.message);
  }
  for (const name of ['agent', 'action', 'run', 'model']) if (values[name] === undefined) throw new MeasureError('MEASURE_FLAG_MISSING', `--${name} is required`);
  if (values.after !== undefined && Number.isNaN(Date.parse(values.after))) throw new MeasureError('MEASURE_FLAG_INVALID', `--after must be an ISO date and time, got ${JSON.stringify(values.after)}`);
  const writeFlags = ['cli', 'repo', 'before'].filter((n) => values[n] !== undefined);
  if (writeFlags.length !== 0 && writeFlags.length !== 3) throw new MeasureError('MEASURE_FLAG_MISSING', '--cli, --repo, and --before go together', { given: writeFlags });
  return values;
}

/** Under `--after`, the entries stamped after it; an entry at or before it, or with no string timestamp, is left out. */
function entriesAfter(entries, after) {
  if (after === undefined) return entries;
  const cut = Date.parse(after);
  return entries.filter((e) => typeof e.timestamp === 'string' && Date.parse(e.timestamp) > cut);
}

/** Every `projects/<project>/<session>/subagents/agent-<id>.jsonl` under the configuration directory. */
function transcriptsFor(configDir, agentId) {
  const projects = path.join(configDir, 'projects');
  if (!existsSync(projects)) return [];
  const found = [];
  for (const project of readdirSync(projects, { withFileTypes: true }).filter((e) => e.isDirectory())) {
    const projectDir = path.join(projects, project.name);
    for (const session of readdirSync(projectDir, { withFileTypes: true }).filter((e) => e.isDirectory())) {
      const file = path.join(projectDir, session.name, 'subagents', `agent-${agentId}.jsonl`);
      if (existsSync(file)) found.push(file);
    }
  }
  return found;
}

function entriesOf(file) {
  return readFileSync(file, 'utf8').split('\n').filter((l) => l.length > 0).map((l, i) => {
    try { return JSON.parse(l); } catch { throw new MeasureError('MEASURE_TRANSCRIPT_MALFORMED', `line ${i + 1} of the transcript is not JSON`, { file, line: i + 1 }); }
  });
}

function targetOf(block) {
  const input = block.input ?? {};
  if (block.name === 'Bash') return String(input.command ?? '');
  const key = TARGET_KEYS.find((k) => typeof input[k] === 'string');
  return key === undefined ? '' : input[key];
}

/** The usage, the tool calls, the reply, and the latency of one transcript. */
function measureEntries(entries) {
  const assistant = entries.filter((e) => e.type === 'assistant' && e.message !== undefined && e.message !== null);
  const lastOf = new Map();
  for (const e of assistant) lastOf.set(e.message.id, e);
  const turns = [...lastOf.values()];
  const sum = (key) => turns.reduce((n, e) => n + (e.message.usage?.[key] ?? 0), 0);
  const usage = { inputTokens: sum('input_tokens'), cacheWriteTokens: sum('cache_creation_input_tokens'), cacheReadTokens: sum('cache_read_input_tokens'), turns: turns.length };
  const blocks = new Map();
  let reply = null;
  for (const e of assistant) {
    for (const block of e.message.content ?? []) {
      if (block.type !== 'tool_use') continue;
      blocks.set(block.id, { tool: block.name, target: targetOf(block) });
      if (block.name === HANDBACK && typeof block.input?.message === 'string') reply = block.input.message;
    }
  }
  const lastId = assistant.at(-1)?.message.id;
  let finalText = null;
  for (const e of assistant) {
    if (e.message.id !== lastId) continue;
    for (const block of e.message.content ?? []) {
      if (block.type === 'text' && typeof block.text === 'string' && block.text.trim() !== '') finalText = block.text;
    }
  }
  const stamps = entries.map((e) => e.timestamp).filter((t) => typeof t === 'string').sort();
  const latencySeconds = stamps.length < 2 ? null : Math.round((Date.parse(stamps.at(-1)) - Date.parse(stamps[0])) / 1000);
  return { usage, toolCalls: [...blocks.values()], reply, finalText, latencySeconds, lastTimestamp: stamps.at(-1) };
}

/** The command line's write measurement, when the action has a write boundary (choice 15). */
function writesOf(v) {
  if (v.before === undefined) return undefined;
  const res = spawnSync(process.execPath, [v.cli, 'writes', 'measure', '--repo', v.repo, '--before', v.before], { encoding: 'utf8' });
  if (res.status !== 0) throw new MeasureError('MEASURE_WRITES_FAILED', `writes measure exited ${res.status}: ${(res.error?.message ?? res.stderr ?? '').trim()}`);
  try {
    return JSON.parse(res.stdout);
  } catch {
    throw new MeasureError('MEASURE_WRITES_FAILED', 'writes measure printed output that is not JSON', { output: res.stdout });
  }
}

/**
 * A member that wrote its reply to a file hands back that file's path. With one
 * pair of surrounding backticks or quotes stripped and the whitespace trimmed,
 * a one-line absolute path directly in `<run>/handed/` that ends `-outcome.json`
 * is a reply file: its content is the reply when it is readable. Any other
 * absolute path, such as a reply-file path with a trailing period or the path
 * of a report, is not read: like a reply file that cannot be read, the reply
 * stays as written with a `repairs` note, so the engine refuses it as malformed
 * and the build skill corrects the same agent. Any other reply is returned as
 * it is.
 */
function replyFileContent(reply, runDir, repairs) {
  const file = reply.trim().replace(/^(["'`])(.*)\1$/s, '$2').trim();
  if (file.includes('\n') || !path.isAbsolute(file)) return reply;
  if (path.dirname(file) !== path.resolve(runDir, 'handed') || !file.endsWith('-outcome.json')) {
    repairs.push(`the hand-back names ${file}, which is not a reply file: a reply file is ${path.resolve(runDir, 'handed')}/<action id>-outcome.json`);
    return reply;
  }
  try {
    return readFileSync(file, 'utf8');
  } catch {
    repairs.push(`the hand-back names ${file}, which is not a readable file`);
    return reply;
  }
}

function main(argv, env) {
  const v = flagsOf(argv);
  const configDir = env.CLAUDE_CONFIG_DIR ?? path.join(homedir(), '.claude');
  const files = transcriptsFor(configDir, v.agent);
  if (files.length === 0) throw new MeasureError('MEASURE_TRANSCRIPT_MISSING', `no transcript agent-${v.agent}.jsonl under ${path.join(configDir, 'projects')}/*/*/subagents/`, { configDir });
  if (files.length > 1) throw new MeasureError('MEASURE_TRANSCRIPT_AMBIGUOUS', `${files.length} transcripts are named agent-${v.agent}.jsonl`, { files });
  const measured = measureEntries(entriesAfter(entriesOf(files[0]), v.after));
  const { usage, toolCalls, latencySeconds, lastTimestamp } = measured;
  const chosen = measured.reply ?? measured.finalText;
  const span = v.after === undefined ? '' : ` after ${v.after}`;
  if (chosen === null) throw new MeasureError('MEASURE_NO_HANDBACK', `the transcript has no ${HANDBACK} tool call and no text in its last assistant message${span}, so the member ended without a reply`, { file: files[0] });
  const repairs = measured.reply === null ? ['reply taken from the final assistant text; no hand-back tool call'] : [];
  const reply = replyFileContent(chosen, v.run, repairs);
  const writes = writesOf(v);
  const meta = { modelBinding: { model: v.model }, usage: latencySeconds === null ? usage : { ...usage, latencySeconds }, toolCalls, repairs, agentId: v.agent, ...(lastTimestamp === undefined ? {} : { lastTimestamp }) };
  if (writes !== undefined) meta.writes = writes;
  const handed = path.join(v.run, 'handed');
  mkdirSync(handed, { recursive: true });
  writeFileSync(path.join(handed, `${v.action}-output.txt`), reply);
  writeFileSync(path.join(handed, `${v.action}-meta.json`), JSON.stringify(meta, null, 2) + '\n');
  const seconds = latencySeconds === null ? '' : `, ${latencySeconds} s`;
  const wrote = writes === undefined ? '' : `, writes ${writes.availability === 'measured' ? `${writes.paths.length} paths` : 'unmeasured'}`;
  return `measured: ${usage.inputTokens + usage.cacheWriteTokens} fresh tokens, ${usage.turns} turns, ${toolCalls.length} tool calls${seconds}${wrote}; reply ${Buffer.byteLength(reply, 'utf8')} bytes`;
}

try {
  process.stdout.write(`${main(process.argv.slice(2), process.env)}\n`);
} catch (err) {
  process.stderr.write(`${JSON.stringify({ error: { code: err.code ?? 'MEASURE_UNEXPECTED', message: err.message, details: err.details ?? {} } })}\n`);
  process.exit(1);
}
