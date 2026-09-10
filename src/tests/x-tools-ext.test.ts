import { describe, it, expect } from 'vitest';
import { extCategories } from '@/js/config/tools-ext';
import { categories } from '@/js/config/tools';

describe('extension registry', () => {
  const EXT_NAMES = ['Image', 'Office & Data', 'Text & Dev'] as const;

  it('declares the three extension categories in order', () => {
    expect(extCategories.map((c) => c.name)).toEqual([...EXT_NAMES]);
  });

  it('appends populated extension categories after every upstream category', () => {
    // Only non-empty extension categories join `categories`: upstream's
    // tools.test.ts requires every category to be non-empty. Until the tools
    // epic populates them, none are merged — so assert the rule, not a count.
    const populated = extCategories
      .filter((c) => c.tools.length > 0)
      .map((c) => c.name);
    const names = categories.map((c) => c.name);

    expect(names.slice(names.length - populated.length)).toEqual(populated);
    for (const name of EXT_NAMES) {
      const isPopulated = populated.includes(name);
      expect(names.includes(name)).toBe(isPopulated);
    }
  });

  it('keeps href first and name second on every tool (upstream regex contract)', () => {
    for (const c of extCategories)
      for (const t of c.tools) {
        expect(Object.keys(t).slice(0, 2)).toEqual(['href', 'name']);
        expect(t.href.startsWith(import.meta.env.BASE_URL + 'x-')).toBe(true);
        expect(t.i18nKey).toMatch(/^tools:ext\.[a-z][A-Za-z0-9]*$/);
      }
  });
});
