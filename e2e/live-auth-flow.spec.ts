import { test, expect } from '@playwright/test';

const COOKIE_NAME = 'session_token';
const COOKIE_VALUE = process.env.TOOLHUB_E2E_COOKIE || '';

test.describe('US-TH-02 AC-06: authenticated access to merge-pdf and COOP/COEP headers', () => {
  test.skip(!COOKIE_VALUE, 'TOOLHUB_E2E_COOKIE not set in .env');

  test('anonymous request to /tools/merge-pdf.html redirects to login', async ({
    page,
  }) => {
    const response = await page.goto('/tools/merge-pdf.html', {
      waitUntil: 'commit',
    });

    // Playwright follows redirects by default, so we check the final URL
    // should have landed on the login page
    const url = page.url();
    expect(url).toContain('/login');
    // URL is not percent-encoded by the time we see it in page.url()
    expect(url).toContain('next=/tools/merge-pdf.html');
  });

  test('authenticated session reaches /tools/merge-pdf.html with crossOriginIsolated=true', async ({
    page,
    context,
  }) => {
    // Add the session cookie before navigating (playwright requires domain for https)
    await context.addCookies([
      {
        name: COOKIE_NAME,
        value: COOKIE_VALUE,
        domain: 'poster.getaccess.cloud',
        path: '/',
        httpOnly: true,
        secure: true,
        sameSite: 'Lax',
      },
    ]);

    const response = await page.goto('/tools/merge-pdf.html', {
      waitUntil: 'networkidle',
    });

    // authenticated request should receive 200 (served)
    // Note: Playwright follows redirects, so if auth fails it ends at /login
    expect(page.url()).toContain('/tools/merge-pdf.html');
    expect(response?.status()).toBe(200);

    // file input should be present
    const fileInput = page.locator('input[type="file"]').first();
    await expect(fileInput).toBeVisible();

    // COOP/COEP isolation should be enabled
    const crossOriginIsolated = await page.evaluate(
      () => window.crossOriginIsolated
    );
    expect(crossOriginIsolated).toBe(true);

    // verify COOP/COEP headers are present in response
    const headers = response?.headers() || {};
    expect(headers['cross-origin-opener-policy']).toBeDefined();
    expect(headers['cross-origin-embedder-policy']).toBeDefined();
  });

  test('merge-pdf page title and structure are correct', async ({
    page,
    context,
  }) => {
    await context.addCookies([
      {
        name: COOKIE_NAME,
        value: COOKIE_VALUE,
        domain: 'poster.getaccess.cloud',
        path: '/',
        httpOnly: true,
        secure: true,
        sameSite: 'Lax',
      },
    ]);

    await page.goto('/tools/merge-pdf.html', { waitUntil: 'networkidle' });

    // page should have expected structure (title contains the site name)
    const pageTitle = await page.title();
    expect(pageTitle).toContain('toolhub');

    // grid navigation should be accessible
    const gridLink = page.locator('a[href="/tools/"]').first();
    if ((await gridLink.count()) > 0) {
      await expect(gridLink).toBeVisible();
    }
  });
});
