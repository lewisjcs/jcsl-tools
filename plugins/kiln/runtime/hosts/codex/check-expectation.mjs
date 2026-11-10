/** The result forms a Codex receipt can verify without interpreting plan prose. */
export function parseCheckExpectation(value) {
  const expect = value.trim();
  const exit = /^exit (0|[1-9][0-9]*)$/i.exec(expect);
  if (exit && Number.isSafeInteger(Number(exit[1])) && Number(exit[1]) <= 255) return { kind: 'exit', code: Number(exit[1]) };
  if (/^[0-9]+$/.test(expect)) return { kind: 'exact-count', count: expect };
  const minimum = /^a count of at least ([0-9]+)$/i.exec(expect);
  if (minimum && Number.isSafeInteger(Number(minimum[1]))) return { kind: 'minimum-count', count: Number(minimum[1]) };
  const line = /^the line `([^`\n]+)`$/i.exec(expect);
  if (line) return { kind: 'line', text: line[1] };
  const literal = /^`([^`\n]+)`$/.exec(expect);
  if (literal) return { kind: 'contains', text: literal[1] };
  return null;
}

/** The number a `grep -c` check printed: bare digits, or one `path:N` line. */
export function countOf(output) {
  const shown = output.trim();
  const digits = /^[0-9]+$/.test(shown) ? shown : /^[^\n]*:([0-9]+)$/.exec(shown)?.[1];
  if (digits === undefined) return null;
  const n = Number(digits);
  return Number.isSafeInteger(n) ? n : null;
}

export function checkMatchesExpectation(parsed, exitCode, output) {
  if (parsed.kind === 'exit') return exitCode === parsed.code;
  if (parsed.kind === 'exact-count' || parsed.kind === 'minimum-count') {
    const n = countOf(output);
    if (n === null) return false;
    if (exitCode !== 0 && !(exitCode === 1 && n === 0)) return false;
    return parsed.kind === 'exact-count' ? n === Number(parsed.count) : n >= parsed.count;
  }
  if (exitCode !== 0) return false;
  if (parsed.kind === 'line') return output.split('\n').some((l) => l.trimEnd() === parsed.text.trimEnd());
  return output.includes(parsed.text);
}
