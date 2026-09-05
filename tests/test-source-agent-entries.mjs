import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const read = (path) => readFileSync(new URL(path, root), 'utf8');
const sources = ['.ai/PROJECT_CONTEXT.md', '.ai/PROJECT_RULES.md', '.ai/PROJECT_HISTORY.md'];
for (const file of ['AGENTS.md', 'CLAUDE.md', 'GEMINI.md', '.cursor/rules/project-context.mdc']) {
  const entry = read(file);
  const positions = sources.map((source) => entry.indexOf(source));
  assert(positions.every((position) => position >= 0), `${file}: missing shared source`);
  assert.deepEqual(positions, [...positions].sort((a, b) => a - b));
  assert(entry.includes('Do not treat this entry as an independent rule source.'));
  assert(entry.length < 1000, `${file}: keep the adapter thin`);
}
for (const source of sources) assert(read(source).trim().length > 100);
assert.match(read('.cursor/rules/project-context.mdc'), /alwaysApply: true/);
assert.match(read('.ai/PROJECT_CONTEXT.md'), /NO-GO/);
assert.match(read('.ai/PROJECT_RULES.md'), /explicit user approval/);
console.log('source-agent-entries: PASS (four shared adapters; structural evidence only)');
