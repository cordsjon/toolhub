import { defineConfig } from '@playwright/test';

// TOOLHUB_LIVE=1 runs the `live-*.spec.ts` files against the deployed host;
// the default run builds locally and serves it with `vite preview`.
const live = !!process.env.TOOLHUB_LIVE;

export default defineConfig({
  testDir: 'e2e',
  // Upstream's .gitignore has no `test-results` entry and is outside the
  // integration allowance, so artifacts go to an already-ignored path (`*.local`)
  // rather than leaving untracked output the boundary gate would flag.
  outputDir: 'playwright-results.local',
  testMatch: live ? /live-.*\.spec\.ts/ : /^(?!live-).*\.spec\.ts$/,
  use: {
    baseURL: live ? 'https://poster.getaccess.cloud' : 'http://127.0.0.1:4173',
  },
  webServer: live
    ? undefined
    : {
        // `--host 127.0.0.1` is required: without it preview binds in a way the
        // readiness probe cannot reach, and every request returns 000 while the
        // server reports itself up. Build measured at ~55s; 600s stays as headroom.
        command:
          'SIMPLE_MODE=true BASE_URL=/tools/ SITE_URL=https://poster.getaccess.cloud VITE_DEFAULT_LANGUAGE=de npm run build && npx vite preview --port 4173 --host 127.0.0.1',
        url: 'http://127.0.0.1:4173/tools/',
        reuseExistingServer: true,
        timeout: 600_000,
      },
});
