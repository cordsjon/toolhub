# Testing this fork

## Run the suite

```bash
NODE_OPTIONS="--no-experimental-webstorage" npm run test:run
```

**The `NODE_OPTIONS` flag is required on Node 23+ and is not optional.** Without it the
suite reports **12 failures that are not real** (see below). Upstream CI runs Node 20
(`.github/workflows/tests.yml:26`), where the flag is unnecessary and harmless.

## Baseline (AC-05 reference)

`Verified: NODE_OPTIONS="--no-experimental-webstorage" npm run test:run`
`  → Test Files  48 passed (48) · Tests  923 passed (923)`

Measured 2026-09-11 at `UPSTREAM_BASE` (`597e36904e8ccacc0af98463589805cb9ee910d2`),
Node 26.8.1 / npm 11.19.0.

**AC-05 requires the upstream tests to stay unchanged. The number to compare against is
923 passed, 0 failed — not 911.** Recording the un-flagged 911/12 as the baseline would
have silently accepted 10 broken language-resolution tests, which is exactly the surface
T3 and T8 extend. A genuine regression there would then have hidden inside the accepted
failure set.

## Why the flag

Node 23+ ships an experimental global `localStorage`. Without `--localstorage-file` it is
`undefined`, and it **shadows the jsdom implementation** vitest provides
(`vitest.config.ts` → `environment: 'jsdom'`). Tests calling `localStorage.clear()` in
`beforeEach` therefore throw `TypeError: Cannot read properties of undefined (reading
'clear')` against code that is entirely correct.

Affected without the flag:

- `src/tests/i18n.test.ts > getLanguageFromUrl` — 10 failures
- `src/tests/xss-replay.test.ts` — 2 failures (WASM provider localStorage poisoning)

Isolated by control run, not inference — same file, same code, one variable:

```
npx vitest run src/tests/i18n.test.ts                        → Tests 10 failed (10)
NODE_OPTIONS=--no-experimental-webstorage  (same command)    → Tests 10 passed (10)
```

Confirmation that the global is the culprit:

```
$ node -e "console.log(typeof localStorage)"
undefined
(node:41809) ExperimentalWarning: localStorage is not available because
--localstorage-file was not provided.
```

## Why it is not fixed in config

`vitest.config.ts` is **upstream-owned and outside the integration allowance** (which
covers only `src/js/config/tools.ts`, `src/js/main.ts`, `vite.config.ts`, `nginx.conf`).
Editing it would trip `scripts/check-upstream-boundary.sh` (AC-01). Changing the existing
`test:run` script in `package.json` is likewise out — the allowance permits _additions_
to `package.json`, not edits to upstream values.

So the flag lives here and in `.nvmrc`, and the constraint is recorded as fork decision
**A6** in `DECISIONS.md`. If a future task adds a fork-owned test script, prefer a **new**
script name (e.g. `test:fork`) over modifying `test:run`.
