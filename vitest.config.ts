import { defineConfig } from 'vitest/config';
import { resolve } from 'path';

export default defineConfig({
  test: {
    // Enable global test APIs (describe, it, expect, etc.)
    globals: true,

    // Simulate browser environment.
    //
    // Deliberately NO `environmentOptions.jsdom.url` here. Setting a real
    // origin looks like the natural fix for jsdom's opaque-origin Storage
    // error, but it is not origin-neutral: production code branches on
    // location.protocol, and an `https://` origin makes
    // digital-sign-pdf.ts:363's mixed-content guard (pageIsHttps && tsaIsHttp)
    // fire for the first time, failing 6 TSA tests written against the default
    // about:blank origin. localStorage is provided by the shim in
    // src/tests/setup.ts instead, which fixes the real cause without touching
    // the page origin.
    environment: 'jsdom',

    // Setup files to run before tests
    setupFiles: ['./src/tests/setup.ts'],

    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',
      exclude: [
        'node_modules/',
        'src/tests/',
        'dist/',
        '*.config.ts',
        '*.config.js',
        '**/*.d.ts',
        'public/',
        'scripts/',
      ],
      // Set thresholds (optional)
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
        statements: 80,
      },
    },

    // Include/exclude patterns
    include: ['src/**/*.{test,spec}.{js,ts}'],
    exclude: ['node_modules', 'dist', '.idea', '.git', '.cache'],

    // Test timeout
    testTimeout: 10000,

    // Watch options
    watch: false,
  },

  resolve: {
    alias: {
      '@': resolve(__dirname, './src'),
    },
  },
});
