import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(new URL('..', import.meta.url).pathname);
const temp = mkdtempSync(join(tmpdir(), 'harness-kb-'));
const projectParent = join(temp, 'projects');
const vault = join(temp, 'vault');
mkdirSync(projectParent); mkdirSync(vault);
assert.equal(spawnSync(join(root, 'bin/new-full-project'), ['--no-git', 'Project A', projectParent]).status, 0);
const project = join(projectParent, 'Project A');
const command = join(root, 'bin/knowledge-base');
const run = (...args) => spawnSync(process.execPath, [command, ...args], { encoding: 'utf8' });

assert.match(
  readFileSync(join(project, '.gitignore'), 'utf8'),
  /^\.ai-local\/$/m,
  'generated projects must keep machine-local knowledge bindings out of Git',
);

let result = run('preview', '--project', project, '--vault', vault, '--folder', 'Project-A');
assert.equal(result.status, 0, result.stderr);
const preview = JSON.parse(result.stdout);
assert.equal(preview.action, 'PREVIEW');
assert.equal(preview.writesPerformed, false);
assert.match(preview.approvalRef, /^sha256:[0-9a-f]{64}$/);
assert.equal(existsSync(join(vault, 'Project-A')), false, 'preview created the knowledge directory');
assert.equal(existsSync(join(project, '.ai-local')), false, 'preview persisted a binding');

result = run('bind', '--project', project, '--vault', vault, '--folder', 'Project-A', '--approval-ref', 'sha256:' + '0'.repeat(64));
assert.notEqual(result.status, 0);
assert.equal(existsSync(join(vault, 'Project-A')), false, 'invalid approval created a directory');

result = run('bind', '--project', project, '--vault', vault, '--folder', 'Project-A', '--approval-ref', preview.approvalRef);
assert.equal(result.status, 0, result.stderr);
assert.equal(existsSync(join(vault, 'Project-A')), true);
const binding = JSON.parse(readFileSync(join(project, '.ai-local/knowledge-base.json'), 'utf8'));
assert.equal(binding.approvalRef, preview.approvalRef);
assert.equal(binding.vaultRoot, realpathSync(vault));

result = run('bind', '--project', project, '--vault', vault, '--folder', 'Project-A', '--approval-ref', preview.approvalRef);
assert.equal(result.status, 0, result.stderr);
assert.equal(JSON.parse(result.stdout).idempotent, true);

const otherVault = join(temp, 'other-vault'); mkdirSync(otherVault);
result = run('bind', '--project', project, '--vault', otherVault, '--folder', 'Project-A', '--approval-ref', preview.approvalRef);
assert.notEqual(result.status, 0, 'approval was replayed for another path');

const linked = join(temp, 'linked-vault'); symlinkSync(vault, linked);
result = run('preview', '--project', project, '--vault', linked, '--folder', 'Linked');
assert.notEqual(result.status, 0, 'symlink vault was accepted');

writeFileSync(join(vault, 'occupied'), 'user data\n');
result = run('preview', '--project', project, '--vault', vault, '--folder', 'occupied');
assert.notEqual(result.status, 0, 'file collision was accepted');

console.log('test-knowledge-base: ok');
