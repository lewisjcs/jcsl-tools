import path from 'node:path';

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

/** One command string shared by the parent dispatch and the child-rollout receipt reader. */
export function checkInvocation({ run, action, check, cli }) {
  const runner = path.resolve(path.dirname(cli), '../hosts/codex/bin/check.mjs');
  return `node ${shellQuote(runner)} --run ${shellQuote(run)} --action ${shellQuote(action)} --check ${check} --cli ${shellQuote(cli)}`;
}
