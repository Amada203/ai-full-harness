#!/usr/bin/env node
import { createHash } from 'node:crypto';
import {
  existsSync, lstatSync, mkdirSync, readFileSync, realpathSync,
  renameSync, rmdirSync, unlinkSync, writeFileSync,
} from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = realpathSync(resolve(dirname(fileURLToPath(import.meta.url)), '..'));
const policyPath = join(root, '.ai', 'KNOWLEDGE_SYNC.yml');
const bindingPath = join(root, '.ai-local', 'knowledge-base.json');
const statePath = join(root, '.ai-local', 'knowledge-sync-state.json');
const lockPath = join(root, '.ai-local', '.knowledge-sync.lock');

function finish(classification, details = {}, exitCode = 0) {
  process.stdout.write(`${JSON.stringify({ schemaVersion: 1, classification, ...details })}\n`);
  process.exit(exitCode);
}
function digest(bytes) {
  return `sha256:${createHash('sha256').update(bytes).digest('hex')}`;
}
function regularFile(filePath, label, { withinProject = false } = {}) {
  if (!existsSync(filePath)) throw new Error(`${label} is missing`);
  const stat = lstatSync(filePath);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error(`${label} must be a regular file`);
  // F7: lstat only sees the final component. A parent directory of an
  // allowlisted SOURCE may be a symlink escaping the project, so the whole
  // real path must resolve inside the project root. Mirror files live in
  // the Vault and are deliberately exempt from the project boundary.
  if (withinProject) {
    const real = realpathSync(filePath);
    if (real !== root && !real.startsWith(root + sep)) {
      throw new Error(`${label} resolves outside the project boundary`);
    }
  }
}
function directory(filePath, label) {
  if (!existsSync(filePath)) throw new Error(`${label} is missing`);
  const stat = lstatSync(filePath);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error(`${label} must be a regular directory`);
  return realpathSync(filePath);
}
function safeRelative(value) {
  if (!value.endsWith('.md') || isAbsolute(value) || value.includes('\\') || value.includes('\0')) {
    throw new Error(`unsafe or non-Markdown allowlist path: ${value}`);
  }
  const absolute = resolve(root, value);
  const rel = relative(root, absolute);
  if (rel === '..' || rel.startsWith(`..${sep}`) || isAbsolute(rel)) {
    throw new Error(`allowlist path escapes project root: ${value}`);
  }
  return value;
}
function readPolicy() {
  regularFile(policyPath, 'knowledge sync policy');
  const lines = readFileSync(policyPath, 'utf8').split(/\r?\n/);
  const required = [
    'schema_version: 1',
    'authority: project_repository',
    'direction: project_to_vault',
    'conflict_policy: stop',
    'allowlist:',
  ];
  if (!required.every((line, index) => lines[index] === line)) {
    throw new Error('knowledge sync policy header is invalid');
  }
  const allowlist = lines.slice(required.length).filter(Boolean).map((line) => {
    const match = /^  - ([A-Za-z0-9._/-]+\.md)$/.exec(line);
    if (!match) throw new Error(`invalid knowledge sync allowlist entry: ${line}`);
    return safeRelative(match[1]);
  });
  if (allowlist.length === 0 || new Set(allowlist).size !== allowlist.length) {
    throw new Error('knowledge sync allowlist must be non-empty and unique');
  }
  return allowlist;
}
function projectId() {
  const identityPath = join(root, '.ai', 'PROJECT_ID');
  regularFile(identityPath, 'project identity');
  const match = /^PROJECT_ID=([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12})\n?$/i
    .exec(readFileSync(identityPath, 'utf8'));
  if (!match) throw new Error('project identity is invalid');
  return match[1];
}
function readBinding() {
  if (!existsSync(bindingPath)) return null;
  regularFile(bindingPath, 'knowledge binding');
  let binding;
  try { binding = JSON.parse(readFileSync(bindingPath, 'utf8')); } catch { throw new Error('knowledge binding JSON is invalid'); }
  const vaultRoot = directory(binding.vaultRoot, 'bound Vault root');
  const targetPath = directory(binding.targetPath, 'bound knowledge directory');
  if (binding.schemaVersion !== 1 || binding.projectId !== projectId()
    || binding.projectRoot !== root || binding.vaultRoot !== vaultRoot
    || binding.targetPath !== targetPath || dirname(targetPath) !== vaultRoot
    || !/^sha256:[0-9a-f]{64}$/.test(binding.approvalRef)) {
    throw new Error('knowledge binding does not match this project and Vault');
  }
  return binding;
}
function readState() {
  if (!existsSync(statePath)) return { schemaVersion: 1, status: 'UNINITIALIZED', entries: {} };
  regularFile(statePath, 'knowledge sync state');
  let state;
  try { state = JSON.parse(readFileSync(statePath, 'utf8')); } catch { throw new Error('knowledge sync state JSON is invalid'); }
  if (state.schemaVersion !== 1 || !state.entries || typeof state.entries !== 'object' || Array.isArray(state.entries)) {
    throw new Error('knowledge sync state is invalid');
  }
  return state;
}
function inspect(allowlist, binding, state) {
  const entries = [];
  const conflicts = [];
  for (const relativePath of allowlist) {
    const sourcePath = join(root, relativePath);
    regularFile(sourcePath, `allowlisted source ${relativePath}`, { withinProject: true });
    const sourceBytes = readFileSync(sourcePath);
    const sourceDigest = digest(sourceBytes);
    const mirrorPath = join(binding.targetPath, relativePath);
    let mirrorDigest = null;
    if (existsSync(mirrorPath)) {
      regularFile(mirrorPath, `mirror ${relativePath}`);
      mirrorDigest = digest(readFileSync(mirrorPath));
    }
    const previous = state.entries[relativePath];
    if (previous) {
      if (typeof previous.mirrorDigest !== 'string' || mirrorDigest !== previous.mirrorDigest) {
        conflicts.push(relativePath);
      }
    } else if (mirrorDigest !== null) {
      conflicts.push(relativePath);
    }
    entries.push({ relativePath, sourcePath, sourceBytes, sourceDigest, mirrorPath, mirrorDigest });
  }
  return { entries, conflicts };
}
function ensureSafeParent(targetRoot, filePath) {
  const relativeParent = relative(targetRoot, dirname(filePath));
  if (relativeParent === '..' || relativeParent.startsWith(`..${sep}`) || isAbsolute(relativeParent)) {
    throw new Error('mirror path escapes bound directory');
  }
  let current = targetRoot;
  for (const part of relativeParent.split(sep).filter(Boolean)) {
    current = join(current, part);
    if (existsSync(current)) {
      const stat = lstatSync(current);
      if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error('mirror parent is not a regular directory');
    } else {
      mkdirSync(current, { mode: 0o700 });
    }
  }
}
function writeState(status, binding, entries, pending = []) {
  const record = {
    schemaVersion: 1,
    status,
    projectId: binding.projectId,
    targetPath: binding.targetPath,
    updatedAt: new Date().toISOString(),
    pending,
    entries: Object.fromEntries(entries.map((entry) => [entry.relativePath, {
      sourceDigest: entry.sourceDigest,
      mirrorDigest: entry.sourceDigest,
    }])),
  };
  const temporary = `${statePath}.tmp-${process.pid}`;
  writeFileSync(temporary, `${JSON.stringify(record, null, 2)}\n`, { flag: 'wx', mode: 0o600 });
  renameSync(temporary, statePath);
}
function completedEntries(entries) {
  return entries.filter((entry) => {
    try {
      regularFile(entry.mirrorPath, `mirror ${entry.relativePath}`);
      return digest(readFileSync(entry.mirrorPath)) === entry.sourceDigest;
    } catch {
      return false;
    }
  });
}
function acquireLock() {
  try { mkdirSync(lockPath, { mode: 0o700 }); } catch (error) {
    if (error && error.code === 'EEXIST') finish('BLOCKED', { reason: 'another knowledge sync is active' }, 13);
    throw error;
  }
}

try {
  const [action, ...extra] = process.argv.slice(2);
  if (!['audit', 'sync'].includes(action) || extra.length !== 0) {
    throw new Error('usage: knowledge-sync.mjs audit|sync');
  }
  const allowlist = readPolicy();
  const binding = readBinding();
  if (!binding) finish('UNBOUND', { writesPerformed: false }, 12);
  const state = readState();
  const review = inspect(allowlist, binding, state);
  if (review.conflicts.length > 0) {
    finish('CONFLICT', { writesPerformed: false, paths: review.conflicts }, 10);
  }
  const pending = review.entries.filter((entry) => entry.sourceDigest !== entry.mirrorDigest);
  if (action === 'audit') {
    if (pending.length > 0) finish('PENDING', { writesPerformed: false, paths: pending.map((entry) => entry.relativePath) }, 11);
    finish('CONSISTENT', { writesPerformed: false, paths: [] });
  }

  acquireLock();
  try {
    for (const entry of pending) {
      ensureSafeParent(binding.targetPath, entry.mirrorPath);
      const temporary = `${entry.mirrorPath}.tmp-${process.pid}`;
      try {
        writeFileSync(temporary, entry.sourceBytes, { flag: 'wx', mode: 0o600 });
        renameSync(temporary, entry.mirrorPath);
      } finally {
        try { if (existsSync(temporary)) unlinkSync(temporary); } catch {}
      }
    }
    writeState('CONSISTENT', binding, review.entries);
  } catch (error) {
    const completed = completedEntries(review.entries);
    const completedPaths = new Set(completed.map((entry) => entry.relativePath));
    const remaining = pending
      .map((entry) => entry.relativePath)
      .filter((relativePath) => !completedPaths.has(relativePath));
    try { writeState('PENDING', binding, completed, remaining); } catch {}
    try { rmdirSync(lockPath); } catch {}
    finish('PENDING', { writesPerformed: true, reason: error instanceof Error ? error.message : 'sync failure' }, 11);
  } finally {
    try { rmdirSync(lockPath); } catch {}
  }
  finish(pending.length > 0 ? 'SYNCED' : 'CONSISTENT', {
    writesPerformed: pending.length > 0,
    paths: pending.map((entry) => entry.relativePath),
  });
} catch (error) {
  finish('INVALID', { writesPerformed: false, reason: error instanceof Error ? error.message : 'unknown error' }, 2);
}
