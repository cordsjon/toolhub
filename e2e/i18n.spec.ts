import { test, expect } from '@playwright/test';

// Selectors verified against source, not guessed:
//   .category-header > span  — built at runtime in main.ts (~line 322), so it does
//                              not appear in static HTML; only a browser run sees it.
//   #language-switcher       — language-switcher.ts:14 (the plan's
//                              #simple-mode-lang-switcher / [data-language-switcher]
//                              do not exist).
//   [role="menuitem"]        — language-switcher.ts:94, each carrying
//                              data-lang (line 95), which is stable across locales
//                              in a way the visible language name is not.
//   html[lang]               — i18n.ts:229, `document.documentElement.lang`.

test('/tools/de/ shows German upstream and extension category names', async ({
  page,
}) => {
  await page.goto('/tools/de/');

  // Upstream category, translated.
  await expect(page.locator('.category-header span').first()).toHaveText(
    /Beliebte|Beliebt/
  );

  // An `ext` category from the fork's own locale keys (tools.json ext.categories.officeData).
  // Empty extension categories are filtered out by main.ts (A12), so this also
  // proves the ext registry reached the renderer.
  await expect(
    page.locator('.category-header span', { hasText: 'Office & Daten' })
  ).toBeVisible();
});

test('unsupported browser language falls back to VITE_DEFAULT_LANGUAGE=de', async ({
  browser,
}) => {
  const ctx = await browser.newContext({ locale: 'fr-FR' }); // valid BCP-47, not in {en,de}
  const page = await ctx.newPage();
  await page.goto('/tools/');
  await expect(page.locator('html')).toHaveAttribute('lang', 'de');
  await ctx.close();
});

test('language switcher choice persists across pages', async ({ page }) => {
  await page.goto('/tools/');
  await page.locator('#language-switcher button').first().click();
  await page.locator('[role="menuitem"][data-lang="en"]').click();
  await expect(page.locator('html')).toHaveAttribute('lang', 'en');

  await page.goto('/tools/merge-pdf.html');
  await expect(page.locator('html')).toHaveAttribute('lang', 'en');
});
