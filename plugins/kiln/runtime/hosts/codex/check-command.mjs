import path from 'node:path';

function shellQuote(value) {
  return `'${String(value).replaceAll("'", "'\\''")}'`;
}

/** One command string shared by the parent dispatch and the child-rollout receipt reader. */
export function checkInvocation({ run, action, check, cli }) {
  const runner = path.resolve(path.dirname(cli), '../hosts/codex/bin/check.mjs');
  return `node ${shellQuote(runner)} --run ${shellQuote(run)} --action ${shellQuote(action)} --check ${check} --cli ${shellQuote(cli)}`;
}

/** The words `/bin/sh` would pass for one simple command, or null when the command chains, pipes, substitutes, or ends inside a quote. */
function shellWordsOf(command) {
  const words = [];
  let word = null;
  for (let i = 0; i < command.length; i++) {
    const c = command[i];
    if (c === "'") {
      const end = command.indexOf("'", i + 1);
      if (end < 0) return null;
      word = (word ?? '') + command.slice(i + 1, end);
      i = end;
    } else if (c === '"') {
      let text = '';
      for (i++; i < command.length && command[i] !== '"'; i++) {
        if (command[i] === '`' || command.startsWith('$(', i)) return null;
        if (command[i] === '\\' && '$`"\\\n'.includes(command[i + 1] ?? '')) {
          i++;
          if (command[i] === '\n') continue;
        }
        text += command[i];
      }
      if (i >= command.length) return null;
      word = (word ?? '') + text;
    } else if (c === '\\') {
      if (i + 1 >= command.length) return null;
      if (command[i + 1] !== '\n') word = (word ?? '') + command[i + 1];
      i++;
    } else if (';&|\n`'.includes(c) || command.startsWith('$(', i)) {
      return null;
    } else if (c === ' ' || c === '\t') {
      if (word !== null) words.push(word);
      word = null;
    } else if (c === '#' && word === null) {
      const end = command.indexOf('\n', i);
      if (end >= 0) return null;
      break;
    } else {
      word = (word ?? '') + c;
    }
  }
  if (word !== null) words.push(word);
  return words;
}

/** True when the command is a single call of the check runner whose `--run`, `--action`, and `--check` name this check, in any order and either flag form. A mention of the call, such as an `echo` of it or the call inside a chain, is not a call. */
export function invocationMatches(command, { run, action, check }) {
  const words = shellWordsOf(command);
  if (words === null || words.length < 2) return false;
  if (words[0] !== 'node' && !words[0].endsWith('/node')) return false;
  if (!words[1].endsWith('/hosts/codex/bin/check.mjs')) return false;
  const expected = { run, action, check: String(check) };
  const seen = { run: [], action: [], check: [] };
  for (let i = 2; i < words.length; i++) {
    if (words[i] === '--') break;
    const flag = /^--(run|action|check|cli)(?:=(.*))?$/s.exec(words[i]);
    if (!flag) continue;
    const value = flag[2] ?? words[++i];
    if (flag[1] in seen) seen[flag[1]].push(value);
  }
  return Object.keys(expected).every((key) => seen[key].length > 0 && seen[key].every((value) => value === expected[key]));
}
