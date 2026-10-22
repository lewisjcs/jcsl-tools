/** The result forms a Codex receipt can verify without interpreting plan prose. */
export function parseCheckExpectation(value) {
  const expect = value.trim();
  const exit = /^exit (0|[1-9][0-9]*)$/i.exec(expect);
  if (exit && Number.isSafeInteger(Number(exit[1])) && Number(exit[1]) <= 255) return { kind: 'exit', code: Number(exit[1]) };
  if (/^[0-9]+$/.test(expect)) return { kind: 'exact-count', count: expect };
  const minimum = /^a count of at least ([0-9]+)$/i.exec(expect);
  if (minimum && Number.isSafeInteger(Number(minimum[1]))) return { kind: 'minimum-count', count: Number(minimum[1]) };
  const literal = /^`([^`\n]+)`$/.exec(expect);
  if (literal) return { kind: 'contains', text: literal[1] };
  return null;
}

export function checkMatchesExpectation(parsed, exitCode, output) {
  if (parsed.kind === 'exit') return exitCode === parsed.code;
  if (exitCode !== 0) return false;
  if (parsed.kind === 'exact-count') return output.trim() === parsed.count;
  if (parsed.kind === 'minimum-count') {
    const shown = output.trim();
    return /^[0-9]+$/.test(shown) && Number.isSafeInteger(Number(shown)) && Number(shown) >= parsed.count;
  }
  return output.includes(parsed.text);
}
