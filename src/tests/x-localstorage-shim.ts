// toolhub (fork-owned): restore a working `localStorage` under jsdom.
//
// WHY THIS EXISTS
// Node >= 22 ships its own experimental global `localStorage` that is
// `undefined` unless the process was started with `--localstorage-file`, and it
// occupies the global name before jsdom can install its own Storage. Result:
// `window`, `document` and `navigator` all work, but `localStorage` is
// undefined, so every test touching it dies on `localStorage.clear()` with
// "TypeError: Cannot read properties of undefined (reading 'clear')".
//
// The tell is Node's own stderr line, visible in a vitest run:
//   ExperimentalWarning: localStorage is not available because
//   --localstorage-file was not provided
//
// CI pins Node 20 (`.nvmrc`, `.github/workflows/*`), where the global does not
// exist and jsdom wins — so this only bites on a newer local Node, which is
// exactly where it must not silently pass.
//
// TWO FIXES THAT WERE REJECTED, so they are not retried:
//
//  1. `environmentOptions: { jsdom: { url: 'https://localhost/' } }`.
//     jsdom does ALSO refuse Storage on an opaque origin
//     ("SecurityError: localStorage is not available for opaque origins", which
//     `about:blank` is), so a real origin looks like the fix — but it is a
//     different failure and does not help here, because Node's global still
//     shadows jsdom's. Worse, it is not origin-neutral: production code
//     branches on `location.protocol`, and an `https://` origin makes
//     `digital-sign-pdf.ts:363`'s mixed-content guard (`pageIsHttps &&
//     tsaIsHttp`) fire for the first time, failing 6 previously-green TSA
//     tests. Changing the test-page origin has a blast radius.
//
//  2. `NODE_OPTIONS=--localstorage-file=...`. Verified to work, but it makes a
//     green suite depend on an env var and litters a stray DB file.
//
// NOT A CONVENIENCE MOCK: `xss-replay.test.ts` asserts the WasmProvider scrubs
// poisoned `localStorage` entries, so a stubbed-out seam would turn a security
// regression test into a false green. Real Storage semantics are preserved —
// keys and values coerced to strings, `length`/`key()` enumerating in insertion
// order, a missing key reading back as null, and real deletion on
// `removeItem`/`clear` (the scrub assertion depends on entries actually being
// gone). Red/green verified: bypassing the scrub in `wasm-provider.ts` makes
// that test fail, so the assertion can still fail.

function makeStorage(): Storage {
  const map = new Map<string, string>();
  return {
    get length() {
      return map.size;
    },
    key: (i: number) => Array.from(map.keys())[i] ?? null,
    getItem: (k: string) => (map.has(String(k)) ? map.get(String(k))! : null),
    setItem: (k: string, v: string) => void map.set(String(k), String(v)),
    removeItem: (k: string) => void map.delete(String(k)),
    clear: () => map.clear(),
  } as Storage;
}

/** Install Storage on any global the running Node left undefined. No-op otherwise. */
export function installStorageShim(): void {
  if (typeof window === 'undefined') return;
  for (const name of ['localStorage', 'sessionStorage'] as const) {
    if (typeof globalThis[name] !== 'undefined') continue;
    Object.defineProperty(globalThis, name, {
      value: makeStorage(),
      writable: true,
      configurable: true,
    });
  }
}
