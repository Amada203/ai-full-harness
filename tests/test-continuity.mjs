import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(new URL('..', import.meta.url).pathname);
const parent = mkdtempSync(join(tmpdir(), 'full-harness-continuity-'));
const generated = spawnSync(join(root, 'bin/new-full-project'), ['--no-git', 'continuity-fixture', parent], { encoding: 'utf8' });
assert.equal(generated.status, 0, generated.stderr);
const project = join(parent, 'continuity-fixture');
const script = join(project, 'scripts/project-continuity.mjs');

function run(...args) {
  return spawnSync(process.execPath, [script, ...args], { cwd: project, encoding: 'utf8' });
}
function json(result) {
  assert(result.stdout.trim(), result.stderr);
  return JSON.parse(result.stdout);
}
function git(...args) {
  const result = spawnSync('git', args, { cwd: project, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
}

git('init', '-q');
git('config', 'user.email', 'fixture@example.invalid');
git('config', 'user.name', 'Fixture');

let result = run('audit');
assert.equal(result.status, 12);
assert.equal(json(result).classification, 'UNINITIALIZED');

const maliciousTarget = join(parent, 'must-not-exist');
result = run('snapshot', '--note', `$(touch ${maliciousTarget})`);
assert.equal(result.status, 0, result.stderr);
assert.equal(existsSync(maliciousTarget), false, 'checkpoint note was executed');
let checkpoint = JSON.parse(readFileSync(join(project, '.ai/CONTINUITY_CHECKPOINT.json'), 'utf8'));
assert.equal(checkpoint.schemaVersion, 1);
assert.match(checkpoint.projectId, /^[0-9a-f-]{36}$/);
assert.equal(checkpoint.git.head, null);
assert.equal(checkpoint.note, `$(touch ${maliciousTarget})`);
assert.equal(json(run('audit')).classification, 'CONSISTENT');

writeFileSync(join(project, 'staged.txt'), 'one\n');
git('add', 'staged.txt');
writeFileSync(join(project, 'unstaged.txt'), 'two\n');
writeFileSync(join(project, 'untracked.txt'), 'three\n');
result = run('audit');
assert.equal(result.status, 10, result.stderr);
assert.equal(json(result).classification, 'CHANGED');
assert(json(result).differences.includes('WORKTREE'));
assert.equal(run('snapshot', '--note', 'dirty state recorded').status, 0);
assert.equal(json(run('audit')).classification, 'CONSISTENT');

writeFileSync(join(project, '.gitignore'), `${readFileSync(join(project, '.gitignore'), 'utf8')}\nignored-secret\n`);
writeFileSync(join(project, 'ignored-secret'), 'first secret fixture\n');
assert.equal(run('snapshot').status, 0);
writeFileSync(join(project, 'ignored-secret'), 'changed secret fixture\n');
assert.equal(json(run('audit')).classification, 'CONSISTENT', 'ignored content must not enter checkpoint inventory');

git('add', '.');
git('commit', '-qm', 'fixture baseline');
assert.equal(json(run('audit')).classification, 'STALE_EVIDENCE');
assert.equal(run('snapshot').status, 0);
writeFileSync(join(project, 'staged.txt'), 'after commit\n');
git('add', 'staged.txt');
git('commit', '-qm', 'advance head');
result = run('audit');
assert.equal(result.status, 11);
assert.equal(json(result).classification, 'STALE_EVIDENCE');

writeFileSync(join(project, '.ai/CONTINUITY_CHECKPOINT.json'), '{broken');
result = run('audit');
assert.equal(result.status, 2);
assert.equal(json(result).classification, 'INVALID');

const outside = join(parent, 'outside.txt');
writeFileSync(outside, 'outside\n');
symlinkSync(outside, join(project, 'outside-link'));
result = run('snapshot');
assert.equal(result.status, 2);
assert.equal(json(result).classification, 'INVALID');

console.log('test-continuity: ok');
