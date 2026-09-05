#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, readFileSync, readdirSync, realpathSync, writeFileSync, renameSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
function regular(path) {
  if (!lstatSync(path).isFile() || realpathSync(path) !== path) throw Error(`Expected regular non-symlink file: ${path}`);
  return readFileSync(path);
}
function treeHash(home) {
  const hash = createHash('sha256');
  function walk(relative = '') {
    for (const name of readdirSync(join(home, relative)).sort()) {
      if (['.git', 'node_modules', '.DS_Store'].includes(name)) continue;
      const next = relative ? `${relative}/${name}` : name;
      const path = join(home, next);
      const stat = lstatSync(path);
      if (stat.isSymbolicLink()) throw Error(`Tool symlink is forbidden: ${next}`);
      if (stat.isDirectory()) walk(next);
      else if (stat.isFile()) hash.update(`${next}\0${digest(readFileSync(path))}\n`);
      else throw Error(`Unsupported tool file: ${next}`);
    }
  }
  walk();
  return hash.digest('hex');
}
try {
  const mode = process.argv[2];
  if (!['build', 'check'].includes(mode) || process.argv.length !== 3) throw Error('Usage: node scripts/architecture.mjs build|check');
  const candidates = process.env.ARCHIFY_HOME ? [process.env.ARCHIFY_HOME]
    : [join(homedir(), '.agents/skills/archify'), join(homedir(), '.codex/skills/archify')];
  const found = candidates.find(path => existsSync(join(path, 'bin/archify.mjs')));
  if (!found) throw Error('Archify unavailable; set ARCHIFY_HOME to the pinned installation');
  const home = realpathSync(found);
  const lock = JSON.parse(regular(join(root, '.ai/ARCHIFY_LOCK.json')));
  const toolSha = treeHash(home);
  if (lock.treeSha256 !== toolSha) throw Error('Archify content differs from the reviewed tool lock');
  const version = JSON.parse(regular(join(home, 'package.json'))).version;
  if (version !== lock.version) throw Error('Archify version differs from tool lock');
  const folder = join(root, 'docs/architecture');
  const sourcePath = join(folder, 'ARCHITECTURE.archify.json');
  const outputPath = join(folder, 'ARCHITECTURE.html');
  const receiptPath = join(folder, 'ARCHITECTURE.receipt.json');
  if (realpathSync(folder) !== folder) throw Error('Architecture directory must not be a symlink');
  const source = regular(sourcePath);
  const diagram = JSON.parse(source);
  if (diagram.diagram_type !== 'architecture' || diagram.meta?.quality_profile !== 'showcase'
    || !diagram.components?.length || !diagram.connections?.length) throw Error('Complete showcase architecture with components and connections is required');
  const tech = regular(join(root, 'docs/technical/TECHNICAL_PRD.md')).toString();
  if (!tech.includes('../architecture/ARCHITECTURE.html')) throw Error('Technical PRD must link the architecture HTML');
  for (const component of diagram.components) {
    if (!tech.includes(`ARCH:${component.id}`)) throw Error(`Missing technical responsibility reference ARCH:${component.id}`);
  }
  function run(args) {
    const result = spawnSync(process.execPath, [join(home, 'bin/archify.mjs'), ...args], {
      cwd: root, encoding: 'utf8', timeout: 120000, maxBuffer: 16 * 1024 * 1024,
      env: { PATH: process.env.PATH || '/usr/bin:/bin' },
    });
    if (result.status !== 0) throw Error(`Archify failed: ${result.error?.message || result.stderr || result.stdout}`);
    return JSON.parse(result.stdout);
  }
  const validation = run(['validate', 'architecture', sourcePath, '--quality', 'showcase', '--json']);
  if (validation.ok !== true || validation.checks?.length !== 9 || validation.checks.some(x => !x.ok)
    || validation.composition?.summary.errors !== 0 || validation.composition?.summary.warnings !== 0) throw Error('Showcase validation failed');
  if (mode === 'build') {
    for (const path of [outputPath, receiptPath, `${receiptPath}.tmp`]) if (existsSync(path)) regular(path);
    const receipt = run(['deliver', 'architecture', sourcePath, outputPath, '--quality', 'showcase', '--json']);
    receipt.harnessTool = { version, treeSha256: toolSha };
    // Store portable names; native digest and validation fields remain intact.
    receipt.input = 'ARCHITECTURE.archify.json';
    receipt.output = 'ARCHITECTURE.html';
    writeFileSync(`${receiptPath}.tmp`, `${JSON.stringify(receipt, null, 2)}\n`, { flag: 'wx' });
    renameSync(`${receiptPath}.tmp`, receiptPath);
  }
  const receipt = JSON.parse(regular(receiptPath));
  const artifact = regular(outputPath);
  const v = receipt.validation;
  if (receipt.ok !== true || receipt.command !== 'deliver' || receipt.type !== 'architecture'
    || receipt.specification?.sha256 !== digest(source) || receipt.specification?.bytes !== source.length
    || receipt.artifact?.sha256 !== digest(artifact) || receipt.artifact?.bytes !== artifact.length
    || v?.checksPassed !== 9 || v.checkCount !== 9 || v.compositionProfile !== 'showcase'
    || v.compositionStatus !== 'pass' || v.errors !== 0 || v.warnings !== 0
    || receipt.harnessTool?.treeSha256 !== toolSha || receipt.harnessTool?.version !== version) throw Error('Architecture delivery receipt is invalid or stale');
  console.log(`architecture: ${mode} ok (9/9 showcase; browser and perceptual review are separate)`);
} catch (error) {
  console.error(`architecture: ${error.message}`);
  process.exitCode = 1;
}
