/** The content signature of a worktree, independent of HEAD and the index, so a check record can outlive a correction turn that changed no file. */
// Limit: a submodule or a nested repository hashes as `not-a-file`, so an edit to the content inside one does not move the signature.
import { statSync } from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { RolloutError } from './rollout.mjs';

const MAX_BUFFER = 256 * 1024 * 1024;
const ESCAPES = { '\\': '\\\\', '"': '\\"', '\n': '\\n', '\t': '\\t' };

/** A path in git's C-quoted form. `hash-object --stdin-paths` unquotes a line that starts with `"`, so every line is quoted: a name that starts with a quote or holds a newline then reaches git as itself. */
function cQuoted(rel) {
  return `"${rel.replace(/[\\"\x00-\x1f\x7f]/g, (c) => ESCAPES[c] ?? `\\${c.charCodeAt(0).toString(8).padStart(3, '0')}`)}"`;
}

function gitOf(repo, args, prefix, input) {
  const result = spawnSync('git', ['-C', repo, ...args], { encoding: 'utf8', maxBuffer: MAX_BUFFER, input });
  if (result.error || result.status !== 0) {
    throw new RolloutError(`${prefix}_TREE_UNREADABLE`, `git ${args[0]} could not read the worktree`, { repo, error: (result.error?.message ?? result.stderr ?? '').trim().slice(0, 1000) });
  }
  return result.stdout;
}

/** A path git lists that is gone hashes as `missing`; one that is not a regular file (a submodule or a nested repository) as `not-a-file`, because `hash-object` cannot read a folder. */
function kindOf(repo, rel, prefix) {
  try {
    return statSync(path.join(repo, rel)).isFile() ? 'file' : 'not-a-file';
  } catch (err) {
    if (err.code === 'ENOENT' || err.code === 'ENOTDIR') return 'missing';
    throw new RolloutError(`${prefix}_TREE_UNREADABLE`, `could not read ${rel} in the worktree`, { repo, error: err.message });
  }
}

/** sha256 over sorted `<path>\t<hash>\n` lines for every tracked path and every untracked path that is not ignored. */
export function treeSignatureOf(repo, prefix) {
  const listed = (extra) => gitOf(repo, ['ls-files', '-z', ...extra], prefix).split('\0').filter(Boolean);
  const paths = [...new Set([...listed([]), ...listed(['--others', '--exclude-standard'])])].sort();
  const kinds = paths.map((rel) => kindOf(repo, rel, prefix));
  const files = paths.filter((_, i) => kinds[i] === 'file');
  const hashes = files.length === 0 ? [] : gitOf(repo, ['hash-object', '--no-filters', '--stdin-paths'], prefix, files.map((rel) => `${cQuoted(rel)}\n`).join('')).split('\n').slice(0, files.length);
  if (hashes.length !== files.length || hashes.some((hash) => !/^[0-9a-f]{40,64}$/.test(hash))) {
    throw new RolloutError(`${prefix}_TREE_UNREADABLE`, 'git hash-object did not return one hash per file', { repo });
  }
  const hashOf = new Map(files.map((rel, i) => [rel, hashes[i]]));
  const lines = paths.map((rel, i) => `${rel}\t${kinds[i] === 'file' ? hashOf.get(rel) : kinds[i]}\n`);
  return createHash('sha256').update(lines.join('')).digest('hex');
}
