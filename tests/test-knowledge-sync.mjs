import assert from 'node:assert/strict';
import {
  existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync,
  symlinkSync, unlinkSync, writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = resolve(new URL('..', import.meta.url).pathname);
const temp = mkdtempSync(join(tmpdir(), 'harness-kb-sync-'));
const projectParent = join(temp, 'projects');
const vault = join(temp, 'vault');
mkdirSync(projectParent); mkdirSync(vault);
assert.equal(spawnSync(join(root, 'bin/new-full-project'), ['--no-git', 'Project A', projectParent]).status, 0);
const project = join(projectParent, 'Project A');
const syncCommand = join(project, 'scripts/knowledge-sync.mjs');
const bindingCommand = join(root, 'bin/knowledge-base');
const runSync = (action) => spawnSync(process.execPath, [syncCommand, action], { cwd: project, encoding: 'utf8' });
const runBinding = (...args) => spawnSync(process.execPath, [bindingCommand, ...args], { encoding: 'utf8' });

assert.equal(existsSync(join(project, '.ai/KNOWLEDGE_SYNC.yml')), true, 'versioned sync policy missing');
assert.equal(existsSync(syncCommand), true, 'generated sync command missing');
assert.match(readFileSync(join(project, '.ai/WORKFLOW.md'), 'utf8'), /knowledge-sync\.mjs sync/);
assert.match(readFileSync(join(project, '.ai/PROJECT_RULES.md'), 'utf8'), /project repository is the authority/i);

let result = runSync('audit');
assert.equal(result.status, 12, result.stderr);
assert.equal(JSON.parse(result.stdout).classification, 'UNBOUND');

const preview = JSON.parse(runBinding(
  'preview', '--project', project, '--vault', vault, '--folder', 'Project-A',
).stdout);
result = runBinding(
  'bind', '--project', project, '--vault', vault, '--folder', 'Project-A',
  '--approval-ref', preview.approvalRef,
);
assert.equal(result.status, 0, result.stderr);

writeFileSync(join(project, '.env'), 'SECRET=must-not-copy\n');
result = runSync('sync');
assert.equal(result.status, 0, result.stderr);
assert.equal(JSON.parse(result.stdout).classification, 'SYNCED');
const mirrorRoot = join(realpathSync(vault), 'Project-A');
assert.equal(existsSync(join(mirrorRoot, '.ai/PROJECT_CONTEXT.md')), true);
assert.equal(existsSync(join(mirrorRoot, '.env')), false, 'non-allowlisted secret was copied');

result = runSync('sync');
assert.equal(result.status, 0, result.stderr);
assert.equal(JSON.parse(result.stdout).classification, 'CONSISTENT');

const mirrorContext = join(mirrorRoot, '.ai/PROJECT_CONTEXT.md');
const sourceContext = join(project, '.ai/PROJECT_CONTEXT.md');
const originalSource = readFileSync(sourceContext, 'utf8');
writeFileSync(mirrorContext, 'manual Obsidian edit\n');
result = runSync('audit');
assert.equal(result.status, 10, result.stderr);
assert.equal(JSON.parse(result.stdout).classification, 'CONFLICT');
result = runSync('sync');
assert.equal(result.status, 10, result.stderr);
assert.equal(readFileSync(mirrorContext, 'utf8'), 'manual Obsidian edit\n', 'conflict was overwritten');
assert.equal(readFileSync(sourceContext, 'utf8'), originalSource, 'mirror edit changed repository source');

writeFileSync(mirrorContext, originalSource);
writeFileSync(sourceContext, `${originalSource}\nRepository update.\n`);
result = runSync('sync');
assert.equal(result.status, 0, result.stderr);
assert.equal(readFileSync(mirrorContext, 'utf8'), readFileSync(sourceContext, 'utf8'));

const projectB = join(projectParent, 'Project B');
assert.equal(spawnSync(join(root, 'bin/new-full-project'), ['--no-git', 'Project B', projectParent]).status, 0);
const previewB = JSON.parse(runBinding(
  'preview', '--project', projectB, '--vault', vault, '--folder', 'Project-B',
).stdout);
result = runBinding(
  'bind', '--project', projectB, '--vault', vault, '--folder', 'Project-B',
  '--approval-ref', previewB.approvalRef,
);
assert.equal(result.status, 0, result.stderr);
const mirrorB = join(realpathSync(vault), 'Project-B');
mkdirSync(join(mirrorB, 'docs'));
writeFileSync(join(mirrorB, 'docs/product'), 'temporary collision\n');
const runSyncB = (action) => spawnSync(
  process.execPath, [join(projectB, 'scripts/knowledge-sync.mjs'), action],
  { cwd: projectB, encoding: 'utf8' },
);
result = runSyncB('sync');
assert.equal(result.status, 11, result.stderr);
assert.equal(JSON.parse(result.stdout).classification, 'PENDING');
unlinkSync(join(mirrorB, 'docs/product'));
result = runSyncB('sync');
assert.equal(result.status, 0, result.stderr);
assert.equal(JSON.parse(result.stdout).classification, 'SYNCED');
assert.equal(existsSync(join(mirrorB, 'docs/product/PRD.md')), true, 'partial sync did not resume');

unlinkSync(sourceContext);
symlinkSync(join(project, '.env'), sourceContext);
result = runSync('sync');
assert.equal(result.status, 2, result.stderr);
assert.equal(JSON.parse(result.stdout).classification, 'INVALID');
assert.equal(readFileSync(mirrorContext, 'utf8').includes('SECRET='), false, 'symlink target leaked to mirror');

console.log('test-knowledge-sync: ok');
