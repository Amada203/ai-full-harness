#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { lstat, readFile, readlink, realpath, rename, writeFile } from 'node:fs/promises';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { spawnSync } from 'node:child_process';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const checkpointRelative = '.ai/CONTINUITY_CHECKPOINT.json';
const root = await realpath(resolve(dirname(fileURLToPath(import.meta.url)), '..'));
const checkpointPath = join(root, checkpointRelative);

function output(classification, details = {}, exitCode = 0) {
  process.stdout.write(`${JSON.stringify({ schemaVersion: 1, classification, ...details })}\n`);
  process.exitCode = exitCode;
}
function hash(value) {
  return `sha256:${createHash('sha256').update(value).digest('hex')}`;
}
function git(args, allowFailure = false) {
  const result = spawnSync('git', ['-C', root, ...args], { encoding: null });
  if (result.status !== 0 && !allowFailure) {
    throw new Error(`Git inspection failed: ${Buffer.from(result.stderr ?? '').toString('utf8').trim()}`);
  }
  return result;
}
function nulEntries(buffer) {
  return buffer.toString('utf8').split('\0').filter(Boolean);
}
function safePath(relativePath) {
  if (relativePath.length === 0 || isAbsolute(relativePath) || relativePath.includes('\0')) {
    throw new Error('Git returned an unsafe project path');
  }
  const absolute = resolve(root, relativePath);
  const rel = relative(root, absolute);
  if (rel === '..' || rel.startsWith(`..${sep}`) || isAbsolute(rel)) throw new Error('Path escapes project root');
  return absolute;
}
async function projectId() {
  const source = await readFile(join(root, '.ai/PROJECT_ID'), 'utf8');
  const match = /^PROJECT_ID=([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\n?$/i.exec(source);
  if (!match) throw new Error('Invalid .ai/PROJECT_ID');
  return match[1].toLowerCase();
}
async function facts() {
  const top = git(['rev-parse', '--show-toplevel']);
  const canonicalTop = await realpath(Buffer.from(top.stdout).toString('utf8').trim());
  if (canonicalTop !== root) throw new Error('Continuity command must run at the repository root');

  const headResult = git(['rev-parse', '--verify', 'HEAD'], true);
  const head = headResult.status === 0 ? Buffer.from(headResult.stdout).toString('utf8').trim().toLowerCase() : null;
  const branchResult = git(['symbolic-ref', '--quiet', '--short', 'HEAD'], true);
  const branch = branchResult.status === 0 ? Buffer.from(branchResult.stdout).toString('utf8').trim() : null;

  const indexRecords = nulEntries(git(['ls-files', '-s', '-z']).stdout)
    .filter((entry) => entry.slice(entry.indexOf('\t') + 1) !== checkpointRelative)
    .sort();
  const paths = nulEntries(git(['ls-files', '-z', '--cached', '--others', '--exclude-standard']).stdout)
    .filter((path) => path !== checkpointRelative)
    .sort();
  const inventory = [];
  for (const path of paths) {
    const absolute = safePath(path);
    let stat;
    try { stat = await lstat(absolute); } catch (error) {
      if (error && error.code === 'ENOENT') { inventory.push(`${path}\0MISSING`); continue; }
      throw error;
    }
    if (stat.isSymbolicLink()) {
      const target = await readlink(absolute);
      let resolved;
      try { resolved = await realpath(resolve(dirname(absolute), target)); } catch { throw new Error(`Broken symbolic link: ${path}`); }
      const rel = relative(root, resolved);
      if (rel === '..' || rel.startsWith(`..${sep}`) || isAbsolute(rel)) throw new Error(`Symbolic link escapes project root: ${path}`);
      inventory.push(`${path}\0SYMLINK\0${target}`);
    } else if (stat.isFile()) {
      inventory.push(`${path}\0FILE\0${hash(await readFile(absolute))}`);
    } else {
      throw new Error(`Unsupported project entry type: ${path}`);
    }
  }
  return {
    projectId: await projectId(),
    git: { branch, head, indexDigest: hash(indexRecords.join('\n')) },
    worktreeDigest: hash(inventory.join('\n')),
  };
}
function parseArgs(argv) {
  const [command, ...rest] = argv;
  if (!['snapshot', 'audit'].includes(command)) throw new Error('Usage: project-continuity.mjs snapshot [--note TEXT] | audit');
  let note = '';
  if (command === 'snapshot' && rest.length === 2 && rest[0] === '--note') note = rest[1];
  else if (rest.length !== 0) throw new Error('Unexpected continuity arguments');
  if (note.includes('\0') || note.length > 500) throw new Error('Checkpoint note must be at most 500 characters of inert text');
  return { command, note };
}
function validateCheckpoint(value) {
  if (!value || typeof value !== 'object' || value.schemaVersion !== 1
    || !['UNINITIALIZED', 'CAPTURED'].includes(value.status)
    || typeof value.projectId !== 'string'
    || value.status === 'CAPTURED' && (!value.git || typeof value.git !== 'object'
    || !('branch' in value.git) || !('head' in value.git)
    || typeof value.git.indexDigest !== 'string' || typeof value.worktreeDigest !== 'string')) {
    throw new Error('Invalid or uninitialized continuity checkpoint');
  }
}

try {
  const { command, note } = parseArgs(process.argv.slice(2));
  const current = await facts();
  if (command === 'snapshot') {
    const record = { schemaVersion: 1, status: 'CAPTURED', capturedAt: new Date().toISOString(), ...current, note };
    const temporary = `${checkpointPath}.tmp.${process.pid}`;
    await writeFile(temporary, `${JSON.stringify(record, null, 2)}\n`, { encoding: 'utf8', mode: 0o600, flag: 'wx' });
    await rename(temporary, checkpointPath);
    output('CAPTURED', { projectId: current.projectId });
  } else {
    let saved;
    try { saved = JSON.parse(await readFile(checkpointPath, 'utf8')); } catch { throw new Error('Invalid continuity checkpoint JSON'); }
    validateCheckpoint(saved);
    if (saved.status === 'UNINITIALIZED') {
      if (saved.projectId !== current.projectId) output('INVALID', { differences: ['PROJECT_ID'] }, 2);
      else output('UNINITIALIZED', { differences: [] }, 12);
      process.exit();
    }
    const differences = [];
    if (saved.projectId !== current.projectId) differences.push('PROJECT_ID');
    if (saved.git.branch !== current.git.branch) differences.push('BRANCH');
    if (saved.git.head !== current.git.head) differences.push('HEAD');
    if (saved.git.indexDigest !== current.git.indexDigest) differences.push('INDEX');
    if (saved.worktreeDigest !== current.worktreeDigest) differences.push('WORKTREE');
    if (differences.includes('PROJECT_ID')) output('INVALID', { differences }, 2);
    else if (differences.includes('HEAD') || differences.includes('BRANCH')) output('STALE_EVIDENCE', { differences }, 11);
    else if (differences.length > 0) output('CHANGED', { differences }, 10);
    else output('CONSISTENT', { differences: [] });
  }
} catch (error) {
  output('INVALID', { error: error instanceof Error ? error.message.slice(0, 500) : 'Unknown continuity error' }, 2);
}
