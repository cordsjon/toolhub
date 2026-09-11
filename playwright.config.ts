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
        // Serve only — the build is a separate step (`npm run build:e2e`), not part
        // of the readiness window. Chaining `build && preview` here made every
        // failure look like a webServer timeout regardless of cause, because
        // `webServer` can only observe "did `url` become reachable in time".
        // Preview starts in ~2s, so 60s is generous and a hang now fails fast.
        //
        // `BASE_URL=/tools/` is required at PREVIEW time, not just at build time:
        // vite.config.ts:540 reads `base` from it. Without it preview serves base
        // `/` and returns the root `dist/index.html` for `/tools/de/` — HTTP 200
        // with the wrong document, which a status-code-only probe cannot detect.
        //
        // `--host 127.0.0.1` is required: without it preview binds in a way the
        // readiness probe cannot reach, and every request returns 000 while the
        // server reports itself up.
        command:
          'BASE_URL=/tools/ npx vite preview --port 4173 --host 127.0.0.1',
        url: 'http://127.0.0.1:4173/tools/',
        reuseExistingServer: true,
        timeout: 60_000,
      },
});
