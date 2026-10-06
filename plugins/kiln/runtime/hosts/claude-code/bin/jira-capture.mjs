#!/usr/bin/env node
/**
 * The Claude Code host's Jira capture hook. It runs before and after the
 * session's Jira read tool. While a kiln run holds an open request for the
 * ticket key, it sets the tool's inputs from the request, saves the tool's
 * answer byte for byte, closes the request, and hands the session one line
 * in place of the answer. With no open request it prints nothing and writes
 * nothing. It imports nothing from `src/`, and it never fails a tool call:
 * any error ends it with exit 0 and no output.
 */
import { readFileSync, writeFileSync, renameSync, rmSync, existsSync, mkdirSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

/** A request older than this is closed. The same number is REQUEST_TTL_MS in src/jira-capture.mjs. */
export const REQUEST_TTL_MS = 600000;
const TOOL = /__getJiraIssue$/;
const KEY = /^[A-Z][A-Z0-9]+-[0-9]+$/;
const SAVED = /Output has been saved to (.+)\.\n/;

/** The folder of the requests and the captures: the rule of the kernel's store root, with no flag. */
export function storeOf(env = process.env, home = homedir()) {
  return env.XDG_STATE_HOME ? path.join(path.resolve(env.XDG_STATE_HOME), 'kiln', 'jira') : path.join(home, '.local', 'state', 'kiln', 'jira');
}

/** The open request for the key, or null: no file, a file that is not a request for this key, or a request past its time. */
export function openRequest(dir, key, now) {
  let request;
  try { request = JSON.parse(readFileSync(path.join(dir, 'request.json'), 'utf8')); } catch { return null; }
  const at = Date.parse(request?.at);
  if (request?.key !== key || !Number.isFinite(at) || now - at > REQUEST_TTL_MS || now < at) return null;
  return request;
}

/** The answer text of a tool response, and the form it came in. The real tool gives one string. A stand-in can give a list of text blocks. */
export function answerOf(response) {
  if (typeof response === 'string') return { text: response, form: 'string' };
  if (Array.isArray(response) && response.every((b) => b !== null && typeof b === 'object' && b.type === 'text' && typeof b.text === 'string')) return { text: response.map((b) => b.text).join(''), form: 'blocks' };
  return { text: null, form: 'other' };
}

function isJsonObject(text) {
  try { const v = JSON.parse(text); return v !== null && typeof v === 'object'; } catch { return false; }
}

/** The ticket JSON as text, or the reason that there is none. A large answer arrives as a message that names a saved file. */
export function ticketTextOf(text) {
  if (text === null) return { text: null, problem: 'the answer is neither a string nor a list of text blocks' };
  if (isJsonObject(text)) return { text, problem: null };
  const saved = SAVED.exec(text);
  if (saved === null) return { text: null, problem: 'the answer is not JSON' };
  if (!existsSync(saved[1])) return { text: null, problem: 'the answer was too large, and the file that the message names is absent' };
  const file = readFileSync(saved[1], 'utf8');
  return isJsonObject(file) ? { text: file, problem: null } : { text: null, problem: 'the answer was too large, and the saved file is not JSON' };
}

function writeAtomic(file, data) {
  writeFileSync(`${file}.tmp`, data);
  renameSync(`${file}.tmp`, file);
}

/** One hook call: the JSON to print, or null for no output. */
export function handle(input, { env = process.env, home = homedir(), now = Date.now() } = {}) {
  if (typeof input?.tool_name !== 'string' || !TOOL.test(input.tool_name)) return null;
  const key = input.tool_input?.issueIdOrKey;
  if (typeof key !== 'string' || !KEY.test(key)) return null;
  const dir = path.join(storeOf(env, home), key);
  const request = openRequest(dir, key, now);
  if (request === null) return null;
  if (input.hook_event_name === 'PreToolUse') {
    return { hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'allow', permissionDecisionReason: `a kiln run asked for ${key}`, updatedInput: { ...input.tool_input, fields: request.fields, responseContentFormat: request.responseContentFormat, updateHistory: request.updateHistory } } };
  }
  if (input.hook_event_name !== 'PostToolUse') return null;
  const answer = answerOf(input.tool_response);
  const ticket = ticketTextOf(answer.text);
  mkdirSync(dir, { recursive: true });
  rmSync(path.join(dir, 'answer.json'), { force: true });
  if (ticket.text !== null) writeAtomic(path.join(dir, 'answer.json'), ticket.text);
  writeAtomic(path.join(dir, 'capture.json'), JSON.stringify({ key, request, toolName: input.tool_name, toolInput: input.tool_input ?? {}, toolUseId: input.tool_use_id ?? null, savedAt: new Date(now).toISOString(), problem: ticket.problem }, null, 2) + '\n');
  rmSync(path.join(dir, 'request.json'), { force: true });
  if (ticket.problem !== null) return null;
  const receipt = `kiln saved the answer for ${key} to a file for the run. This session holds no ticket text. Run the kiln command again.`;
  return { hookSpecificOutput: { hookEventName: 'PostToolUse', updatedToolOutput: answer.form === 'string' ? receipt : [{ type: 'text', text: receipt }] } };
}

if (process.argv[1] !== undefined && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const out = handle(JSON.parse(readFileSync(0, 'utf8')));
    if (out !== null) process.stdout.write(JSON.stringify(out));
  } catch { /* a hook that fails must never fail the tool call */ }
}
