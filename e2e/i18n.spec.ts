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

test('/tools/de/ shows German upstream category names', async ({ page }) => {
  await page.goto('/tools/de/');

  // Upstream category, translated.
  await expect(page.locator('.category-header span').first()).toHaveText(
    /Beliebte|Beliebt/
  );
});

// The ext-category assertion this file originally carried ("Office & Daten" visible)
// asserts a Phase 2 outcome and cannot pass at Phase 1: every entry in
// `extCategories` (tools-ext.ts) still has `tools: []`, and main.ts:313 filters
// empty categories out by design (A12). Re-enable it with the first ext tool.
test.fixme('ext category renders once an extension tool is registered', async ({
  page,
}) => {
  await page.goto('/tools/de/');
  await expect(
    page.locator('.category-header span', { hasText: 'Office & Daten' })
  ).toBeVisible();
});

test('unsupported browser language falls back to VITE_DEFAULT_LANGUAGE=de', async ({
  browser,
}) => {
  // `fi` is genuinely absent from supportedLanguages (i18n.ts:8 — 21 locales, and
  // `fr` IS among them, so the original 'fr-FR' resolved to French and never fell back).
  // Both the full tag and its primary subtag must miss, per i18n.ts:90-97.
  const ctx = await browser.newContext({ locale: 'fi-FI' });
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
