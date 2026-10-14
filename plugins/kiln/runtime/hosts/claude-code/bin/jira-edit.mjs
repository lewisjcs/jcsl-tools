#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, renameSync, existsSync, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const TOOL = /__editJiraIssue$/;
const KEY = /^[A-Z][A-Z0-9]+-[0-9]+$/;
const sha256 = (text) => createHash('sha256').update(text).digest('hex');
const readJson = (file) => JSON.parse(readFileSync(file, 'utf8'));
const writeJson = (file, value) => writeFileSync(file, JSON.stringify(value, null, 2) + '\n');

function storeOf(env, home) {
  return env.XDG_STATE_HOME ? path.join(path.resolve(env.XDG_STATE_HOME), 'kiln', 'jira') : path.join(home, '.local', 'state', 'kiln', 'jira');
}

function sameTarget(input, request) {
  return input.tool_input?.issueIdOrKey === request.key && input.tool_input?.cloudId === request.site;
}

export function handle(input, { env = process.env, home = homedir() } = {}) {
  if (typeof input?.tool_name !== 'string' || !TOOL.test(input.tool_name)) return null;
  const key = input.tool_input?.issueIdOrKey;
  if (typeof key !== 'string' || !KEY.test(key)) return null;
  const dir = path.join(storeOf(env, home), key);
  const requestPath = path.join(dir, 'write-request.json');
  const attemptPath = path.join(dir, 'write-attempt.json');
  if (input.hook_event_name === 'PreToolUse') {
    if (!existsSync(requestPath) || existsSync(attemptPath)) return null;
    const request = readJson(requestPath);
    const fields = input.tool_input?.fields;
    if (!sameTarget(input, request) || fields?.__kiln_guard__ !== request.token) return null;
    const keys = Object.keys(input.tool_input).sort();
    if (keys.join(',') !== 'cloudId,contentFormat,fields,issueIdOrKey,responseContentFormat' || Object.keys(fields).length !== 1 || input.tool_input.contentFormat !== 'adf' || input.tool_input.responseContentFormat !== 'adf') {
      return { hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: `kiln refused an edited Jira action for ${key}` } };
    }
    const previewBytes = readFileSync(request.previewPath, 'utf8');
    if (sha256(previewBytes) !== request.previewSha256) return null;
    const preview = JSON.parse(previewBytes);
    if (preview.key !== key || preview.site !== request.site || preview.originalSha256 !== request.originalSha256 || preview.newSha256 !== request.newSha256 || sha256(JSON.stringify(preview.newAdf)) !== request.newSha256) return null;
    const attempt = { ...request, toolUseId: input.tool_use_id, at: new Date().toISOString() };
    renameSync(requestPath, attemptPath);
    writeJson(attemptPath, attempt);
    writeJson(`${request.previewPath}.attempt.json`, attempt);
    return { hookSpecificOutput: { hookEventName: 'PreToolUse', permissionDecision: 'allow', permissionDecisionReason: `kiln approved one description edit for ${key}`, updatedInput: { cloudId: request.site, issueIdOrKey: key, contentFormat: 'adf', responseContentFormat: 'adf', fields: { description: preview.newAdf } } } };
  }
  if (!['PostToolUse', 'PostToolUseFailure'].includes(input.hook_event_name) || !existsSync(attemptPath)) return null;
  const attempt = readJson(attemptPath);
  if (attempt.toolUseId !== input.tool_use_id || !sameTarget(input, attempt)) return null;
  const description = input.tool_input?.fields?.description;
  const injected = description !== undefined && sha256(JSON.stringify(description)) === attempt.newSha256;
  writeJson(`${attempt.previewPath}.response.json`, { toolError: input.hook_event_name === 'PostToolUseFailure' || input.is_error === true || input.tool_response?.isError === true, injected, response: input.tool_response ?? input.error ?? null });
  if (input.hook_event_name === 'PostToolUseFailure') return null;
  const receipt = `kiln saved the Jira edit response for ${key}. Run jira-write-finish for readback.`;
  return { hookSpecificOutput: { hookEventName: 'PostToolUse', updatedToolOutput: Array.isArray(input.tool_response) ? [{ type: 'text', text: receipt }] : receipt } };
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === realpathSync(process.argv[1])) {
  try {
    const output = handle(JSON.parse(readFileSync(0, 'utf8')));
    if (output !== null) process.stdout.write(JSON.stringify(output));
  } catch { /* the invalid sentinel remains safe when this hook fails */ }
}
