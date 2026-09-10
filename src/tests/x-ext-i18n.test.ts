import { describe, it, expect } from 'vitest';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

function run(en: object, de: object) {
  const root = mkdtempSync(join(tmpdir(), 'ext-i18n-'));
  for (const [lang, obj] of [
    ['en', en],
    ['de', de],
  ] as const) {
    mkdirSync(join(root, lang), { recursive: true });
    writeFileSync(join(root, lang, 'tools.json'), JSON.stringify(obj));
  }
  return spawnSync('node', ['scripts/check-ext-i18n.mjs', '--locales', root], {
    encoding: 'utf8',
  });
}

describe('check-ext-i18n', () => {
  it('passes when every ext.* key in en exists in de', () => {
    const r = run({ ext: { a: { name: 'A' } } }, { ext: { a: { name: 'Ä' } } });
    expect(r.status).toBe(0);
  });
  it('fails naming the missing key', () => {
    const r = run(
      { ext: { a: { name: 'A', subtitle: 'S' } } },
      { ext: { a: { name: 'Ä' } } }
    );
    expect(r.status).toBe(1);
    expect(r.stderr).toContain('ext.a.subtitle');
  });
  it('ignores keys outside ext', () => {
    const r = run({ mergePdf: { name: 'x' }, ext: {} }, { ext: {} });
    expect(r.status).toBe(0);
  });
});
