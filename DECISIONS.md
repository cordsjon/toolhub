# DECISIONS — toolhub

Fork-local decision journal. Format matches `00_Governance/DECISIONS.md`
(`## <id> — <area> — <category>` / Question / Options considered / Chosen /
Decided-by / Justification / Outcome / Ref).

Entries **A1–A5** were assumed by the spec author and confirmed at spec review
(panel score 8.2), so they carry `Decided-by: human`. Governance-level decisions
about this project live in `00_Governance/DECISIONS.md` (Q168–Q171, Q174, Q178,
Q180) — this file is for decisions made _inside_ the fork.

---

## A1 — identity and port — gate-resolution

**Question:** What identity and VPS port does the deployed container claim?
**Options considered:** `toolhub` on a fresh port / reuse a retired allocation / a subdomain-scoped identity
**Chosen:** identity `toolhub`; VPS container port **9103**, bound `127.0.0.1:9103:8080` **and** `172.17.0.1:9103:8080`.
**Decided-by:** human
**Justification:** The identity `toolhub` is unclaimed after the unrelated ToolHub static index was retired (00_Governance Q171/Q174). The port is **not** the 9100 originally planned: Phase 0 measured VPS 9100 held by portmgr's own service (146d uptime), and 9101/9102 held by it-tools/searxng, so 9103 was chosen after enumerating the range — free by three checks and unclaimed among portmgr's 18 allocations (00_Governance Q178/Q180). The second `172.17.0.1` binding is required, not optional: Uptime Kuma is bridge-networked on this VPS and cannot reach a loopback-only bind. Not yet reserved in portmgr — its `POST /allocate` assigns the port itself, so registration happens at T17 against the running container, with a re-verify immediately before binding.
**Outcome:** applied
**Ref:** 00_Governance Q178, Q180; `docs/superpowers/plans/2026-09-10-toolhub-phase0-results.md`

## A2 — locales — tradeoff

**Question:** Which languages does the fork ship?
**Options considered:** en only / en+de / all upstream locales
**Chosen:** `en` + `de` only.
**Decided-by:** human
**Justification:** The deployment is single-operator and German-primary (`VITE_DEFAULT_LANGUAGE=de`), so the upstream locale set is cost without a consumer — every added locale widens the `ext` i18n parity surface that `scripts/check-ext-i18n.mjs` must gate. The tradeoff is that adding a third locale later means backfilling every `ext.*` key at once rather than incrementally. German strings are written by the implementer and reviewed by the operator; the parity gate fails the build on any `ext.*` key present in `en` but missing in `de`.
**Outcome:** applied
**Ref:** spec "Solution"; plan Global Constraints, T4

## A3 — allowlist posture — gate-resolution

**Question:** Who may reach the deployed toolhub?
**Options considered:** deny-by-default allowlist / any authenticated PosterEngine user / public
**Chosen:** Deny by default — `PE_TOOLS_USERS`, empty means deny everyone, with a startup WARNING.
**Decided-by:** human
**Justification:** Fail-closed is the only safe default for a gate: a misconfigured or unset allowlist must lock the door, never open it. An empty `PE_TOOLS_USERS` therefore 403s every `scope=tools` verify even with a valid session cookie, and PosterEngine logs a startup warning so the closed state is visible rather than silent. This mirrors the existing `PE_AUTHORIZED_USERS` idiom (`app.py:71-80`) rather than inventing a second pattern. Matching is case-insensitive on email.
**Outcome:** applied
**Ref:** spec US-TH-02; plan T9, T10

## A4 — `next` parameter shape — gate-resolution

**Question:** What may the login redirect's `next` parameter contain?
**Options considered:** path-only / full URL with host allowlist / arbitrary URL
**Chosen:** Path-only. `next` carries a path such as `/tools/x.html`, never a scheme or host.
**Decided-by:** human
**Justification:** An open redirect is the classic failure of a login `next` parameter — accepting a full URL lets an attacker bounce an authenticated user to an arbitrary host. Path-only is the narrow form that cannot express another origin, so it needs no host allowlist to maintain and no parser that could be tricked by scheme-relative (`//evil.com`) or encoded input. The query string of the original request is preserved by nginx; only the redirect target is constrained.
**Outcome:** applied
**Ref:** spec US-TH-02 AC-04; plan T12 Step 3

## A5 — spec location — deviation

**Question:** Where does the design spec live once the fork exists?
**Options considered:** move to the fork / keep only in 00_Governance / duplicate in both
**Chosen:** Copy into the fork at `docs/specs/`; leave the 00_Governance original in place.
**Decided-by:** human
**Justification:** The fork should carry the spec it implements so the repo is self-describing to anyone who clones it (the AGPL §13 source offer makes this repo publicly reachable). The 00_Governance copy stays because it holds the review sections and is the target of the plan's `Spec:` link — deleting it would break that reference and lose the panel history. The cost is two copies that can drift; mitigated by a one-line pointer added at the top of the 00_Governance copy. The fork's copy is the implementation reference; the governance copy is the review record.
**Outcome:** applied
**Ref:** plan T1 Step 3

## A6 — Node 26 shadows jsdom's localStorage — deviation

**Question:** The upstream suite reports 12 failures on this machine. Is that a broken baseline to accept, or an environment artifact to correct?
**Options considered:** record 911/12 as the AC-05 baseline / patch `vitest.config.ts` / patch the `test:run` script / pin the runtime and document the flag
**Chosen:** Environment artifact. True baseline is **923 passed, 0 failed**, obtained with `NODE_OPTIONS="--no-experimental-webstorage"`. Added `.nvmrc` (20) and `TESTING.md`; no upstream file touched.
**Decided-by:** agent
**Justification:** Node 23+ ships an experimental global `localStorage` that is `undefined` without `--localstorage-file` and **shadows** the jsdom implementation vitest supplies, so `localStorage.clear()` in `beforeEach` throws `TypeError` against correct code. Isolated by control run rather than inference — `npx vitest run src/tests/i18n.test.ts` gives 10 failed; the identical command with the flag gives 10 passed; the full suite goes 911→923. Confirmed the global is the culprit: `node -e "console.log(typeof localStorage)"` prints `undefined` with the matching ExperimentalWarning. Upstream CI pins Node 20 (`.github/workflows/tests.yml:26`), where the issue does not arise — this machine runs 26.8.1. **Recording 911/12 as the AC-05 baseline would have been the harmful choice:** the 10 failures are in `getLanguageFromUrl`, precisely the language-resolution surface T3 and T8 extend, so a real regression there would have hidden inside an accepted-failure set. Fixed neither in `vitest.config.ts` (upstream-owned and NOT in the integration allowance — only `tools.ts`, `main.ts`, `vite.config.ts`, `nginx.conf` are; editing it trips AC-01's boundary gate) nor by changing `test:run` (the allowance permits additions to `package.json`, not edits to upstream values). Future fork-owned test scripts should take a new name such as `test:fork`.
**Outcome:** applied
**Ref:** TESTING.md; .nvmrc; baseline measured at UPSTREAM_BASE 597e3690 on Node 26.8.1

## A7 — blank separator line in the nginx.conf deletion — tradeoff

**Question:** The plan specifies a 9-line deletion (`nginx.conf:61-66,116-118`), but removing both blocks cleanly leaves an orphaned blank separator. Delete 9 lines and keep a stray blank, or 10 and keep the file's spacing convention?
**Options considered:** exactly 9 as written / 10 including the orphaned separator / 11 (collapsing both separators)
**Chosen:** **10 deletions, 0 insertions.** The two `/tools/` `if` blocks (6 lines) + the trailing-slash `if` block (3) + the now-orphaned blank line that separated the deleted `/tools/` group from the `getting-started` block.
**Decided-by:** agent
**Justification:** The plan's "9" counted directive lines only; it did not account for the separator the deletion orphans. Every other `if` group in the file is blank-line separated, so keeping a doubled blank there would break the file's own convention for no benefit. An initial edit took 11 (collapsing the separator before `location ~ /src/pages/` too), which harmed readability by butting a `}` against a `location` block — that blank was restored. `git diff --numstat 597e3690 -- nginx.conf` → `0 10`, well inside AC-01's ≤25-line allowance, so the boundary is not at risk either way.
**Outcome:** applied
**Ref:** commit 43b7450

## A8 — generate-blog.mjs hardcodes SITE_URL, failing the AC-04 image build — gate-resolution

**Question:** The Task 2 Step 4 full-image build fails: `seo-audit.mjs` rejects three blog pages whose canonical host is `www.bentopdf.com` instead of the fork's `poster.getaccess.cloud`. The fix is a one-line change to an upstream file outside the integration allowance. Patch it, or stop and ask?
**Options considered:** patch `scripts/generate-blog.mjs` (outside allowance, trips AC-01) / disable or narrow the `seo-audit` canonical check / drop `build:with-docs` for a blog-free build target / carry the failure as a known-broken AC-04 / escalate
**Chosen:** — (blocked on a human)
**Decided-by:** agent
**Justification:** Root cause is measured, not inferred: `scripts/generate-blog.mjs:11` sets `const SITE_URL = 'https://www.bentopdf.com'` as a literal, whereas `generate-sitemap.mjs:11`, `generate-i18n-pages.mjs:11` and `seo-audit.mjs:10` all read `process.env.SITE_URL` with that value only as a fallback. The blog generator therefore ignores the `SITE_URL` build arg and emits upstream canonicals, which the audit — correctly reading the override — rejects. It is an upstream latent bug that only manifests when `SITE_URL` is overridden, which every fork deploy does by definition. **Confirmed unrelated to Task 2 by control run:** the identical `docker build` with `nginx.conf` stashed back to `597e3690` fails with byte-identical `[canonical]` errors, so the 10-line nginx deletion neither causes nor masks it. The reason this escalates rather than being assumed: `scripts/` is not among the four allowed files (`tools.ts`, `main.ts`, `vite.config.ts`, `nginx.conf`), so every repair option either breaches AC-01's boundary gate or weakens an SEO correctness check the fork inherits — and the choice between "widen the allowance" and "weaken the audit" is a spec-owner call, exactly as A6 treated `vitest.config.ts`. Task 2's own config-layer behaviour is fully verified independently of this (see A7 / commit 43b7450); only Step 4's image-level confirmation of `/tools/de/` and the COOP/COEP headers is blocked.
**Outcome:** escalated
**Ref:** commit 43b7450; control build at 597e3690 reproduces identical failure

## A9 — resolving A8: blog SITE_URL fix and the widened allowance — gate-resolution

**Question:** A8 escalated the `generate-blog.mjs` hardcoded `SITE_URL`. Which repair, and does the integration allowance widen to admit it?
**Options considered:** patch `generate-blog.mjs` / narrow the `seo-audit` canonical check / drop `build:with-docs` / carry AC-04 as known-broken
**Chosen:** **Patch `generate-blog.mjs`**, and widen the AC-01 allowance to include it. The operator selected this option directly.
**Decided-by:** human
**Justification:** It repairs the defect rather than suppressing the check that caught it, and makes the outlier match the convention its three siblings already follow (`process.env.SITE_URL || '<upstream>'`). **Scope was larger than A8 estimated:** the audit's `expectedCanonicalForFile` composes `SITE_URL + BASE_PATH + 'blog' + slug`, so `BASE_PATH` had to be threaded through as well — a `SITE_URL`-only change would still have failed for want of `/tools/`. A second producer also surfaced: `author-alam.html` is hand-authored and merely protected by the generator's `keep` set, so patching render paths fixed only 2 of 3 failing pages; `rebaseStaticPages()` rewrites the third in place, scoped to `/blog/` and `/images/` so the upstream source-repo links required by AGPL §13 stay accurate. **The fix is a true no-op upstream** — with default env its output is byte-identical to the unmodified generator's (verified by `diff -r`, not by inspection), which keeps it clean to contribute back. Root-relative asset refs were deliberately NOT touched: `vite.config.ts:655` registers `blog/*.html` as rollup inputs, so Vite's `base` already rewrites them; an earlier reading that the blog bypasses Vite entirely was wrong and was corrected against the config.
**Outcome:** applied
**Ref:** commit c67dd65; supersedes the escalation in A8

## A10 — docs/specs breaks the VitePress build — deviation

**Question:** `docs:build` fails parsing the fork's own spec (`Element is missing end tag`). Exclude it, reword it, or move it?
**Options considered:** `srcExclude` in the VitePress config / escape the angle brackets in the spec prose / move the spec out of `docs/`
**Chosen:** `srcExclude: ['specs/**']` in `docs/.vitepress/config.mts`.
**Decided-by:** agent
**Justification:** A latent regression from Task 1: copying the spec into `docs/` (A5) enlisted it in VitePress's content glob, where Vue's SFC compiler scans for HTML tags before markdown-it protects inline code — so backticked placeholders like `<slug>` read as unclosed tags. The spec is a fork-local design document, not user documentation, so excluding it states the intent directly; rewording would corrupt the spec to satisfy an unrelated build step, and moving it would undo A5 without cause. Assumed rather than escalated because it is reversible, determinable from the VitePress config, and does not change any shipped artifact. **Why it went unnoticed:** `npm run test:run` never invokes `docs:build`, so Task 1's verification could not have caught it — only the full image build exercises VitePress. `docs/.vitepress/config.mts` also hardcodes `SITE_URL` (line 3) exactly as `generate-blog.mjs` did; it is not fixed here because `docs/` is in the audit's `SKIP_DIRS` and so does not block the build — logged as a follow-up rather than scope creep.
**Outcome:** applied
**Ref:** commit c3e0ed1

## A11 — the container serves nginx's default page at `/` — tradeoff

**Question:** The AC-04 probe expects `/` → `403`; the built image returns `200` with nginx's "Welcome to nginx!" page. Fix the Dockerfile, or accept and document?
**Options considered:** delete the stock files in the Dockerfile / add an nginx `location = /` returning 404 / accept, document, and defer
**Chosen:** — (accepted for now, deferred to the operator; nothing changed)
**Decided-by:** agent
**Justification:** `Dockerfile:98` copies `dist` to `/usr/share/nginx/html${BASE_URL%/}`. At `BASE_URL=/` the app's `index.html` overwrites the base image's welcome page; at `/tools/` it lands in a subdirectory and the stock `index.html` and `50x.html` survive at the root. This is the **third** upstream construct in this task that is correct at `/` and wrong at a subpath (after the `/tools/` 301 collision and the hardcoded `SITE_URL`). **Not a public exposure:** the plan binds the container to `127.0.0.1:9103` and `172.17.0.1:9103` only, and NPM host `17.conf` proxies just `location /tools/`, so `/` is reachable from VPS loopback and the docker bridge, never the internet. It is still wrong — it contradicts a stated acceptance criterion and would give a health monitor a misleading `200`. Deferred rather than fixed because `Dockerfile` is a **fourth** upstream file outside the allowance, and the operator widened it in A9 only for the blog fix; expanding again unprompted would be exactly the scope creep AC-01 exists to prevent. The plan's `403` premise was measured against a bare `nginx:alpine` fixture with no default webroot, which is why it was not caught at planning time. **Recommended fix (one line, T6 or the Dockerfile):** `RUN rm -f /usr/share/nginx/html/index.html /usr/share/nginx/html/50x.html` after the dist copy.
**Outcome:** escalated
**Ref:** measured against toolhub:local at commit c3e0ed1

## A12 — empty extension categories break an upstream invariant — deviation

**Question:** The plan merges all three extension categories with empty tool lists, but upstream's `tools.test.ts:20` asserts every category has a non-empty `tools` array — three tests fail. Weaken the test, defer the merge, or filter?
**Options considered:** spread unconditionally and edit `tools.test.ts` / spread only populated categories / delay the whole merge until the tools epic / give each category a placeholder tool
**Chosen:** Spread only populated categories: `...extCategories.filter((c) => c.tools.length > 0)`.
**Decided-by:** agent
**Justification:** Checked whether the upstream invariant is right before trying to satisfy it, and it is: both renderers already drop zero-tool categories (`main.ts:313` for the tool grid, `main.ts:974` for the shortcuts panel), so an empty category renders nowhere and is pure dead weight in `categories`. `tools.test.ts` is upstream-owned and outside the integration allowance, so weakening it would breach AC-01 to accommodate a construct that has no effect — the worst of both. Filtering keeps the registry honest in both states and needs no upstream edit. Deferring the merge entirely was rejected because it would leave the wiring untested until the tools epic. Assumed rather than escalated: reversible, determinable from the code, and no shipped artifact changes while the lists are empty. Consequence for the plan's own test: its `names.slice(-3)` assertion presumed an unconditional spread, so it was rewritten to derive the expectation from the populated set — it now stays correct as the tools epic fills categories one at a time, instead of needing an edit per category.
**Outcome:** applied
**Ref:** commit 3d61909

## A13 — the i18nKey fallback belongs at five sites, not two — deviation

**Question:** The plan specifies the `?? i18nKey` fallback at `main.ts` lines 328 and 403. Grep finds five lookup sites. Patch two as written, or all five?
**Options considered:** exactly the two named / all five / two now and the rest in the tools epic
**Chosen:** All five — `categoryTranslationKeys` at 329 and 984, `toolTranslationKeys` at 406, 1016 and 1109.
**Decided-by:** agent
**Justification:** The three unnamed sites render the shortcuts / command palette, and they read the same `categories` export the extension categories are merged into (`main.ts:965`), so extension entries reach them by the same path. Patching only the grid would leave the palette showing raw English names the moment the tools epic populates a category — a defect invisible today (the palette filters zero-tool categories) and therefore likely to ship unnoticed. The change is the identical one-line pattern with identical fallback semantics at every site, so consistency costs nothing and divergence would be arbitrary. Line numbers in the plan had already drifted (`tools.ts` `baseCategories` closes at 838, not the stated 843), so the count of sites was verified by grep rather than trusted from the plan.
**Outcome:** applied
**Ref:** commit 3d61909

## A14 — the recorded lint baseline no longer reproduces — gate-resolution

**Question:** The handover records a lint baseline of "0 errors, 516 warnings"; the same command now reports 1 error and 2620 warnings. Did this session introduce it?
**Options considered:** treat as a regression from Task 3 / verify by control run / fix the error
**Chosen:** Pre-existing, not introduced here. Nothing changed.
**Decided-by:** agent
**Justification:** Established by control, not inference: stashing all five Task 3 files and re-running `npm run lint` reproduces the identical `1 error, 2620 warnings`. The error is `preserve-caught-error` on `public/sw.js:9` — a generated service worker, unmodified since `UPSTREAM_BASE` (`git diff --numstat` against the base is empty for it). The rule appears to have arrived with a lint dependency update after the baseline was measured. Not fixed here: `public/sw.js` is upstream-owned, outside the allowance, and unrelated to this task. **Process note:** warning and error counts drift with dependency updates in a way commit SHAs do not, so they age badly as handover "measurements — do not re-derive"; they belong in the `## Premises` block where a resume re-measures them, and the next handover records it that way.
**Outcome:** applied
**Ref:** control run at commit 3d61909

## A15 — resolving A11: remove the stock webroot in the Dockerfile — gate-resolution

**Question:** A11 escalated the container serving nginx's default page at `/`. Fix it, and does the allowance widen to `Dockerfile`?
**Options considered:** `rm` the stock files in the Dockerfile / an nginx `location = /` returning 404 / accept and document
**Chosen:** `RUN rm -f /usr/share/nginx/html/index.html /usr/share/nginx/html/50x.html`, placed **before** the dist COPY. The operator accepted the route.
**Decided-by:** human
**Justification:** Removes the artefact rather than masking it with a routing rule, and needs no `nginx.conf` change (keeping that file's diff at the 10 lines Task 2 established). **The placement corrects the recommendation given in A11:** that entry proposed the `rm` _after_ the dist copy, which is right at `BASE_URL=/tools/` but at `BASE_URL=/` would delete the application's own `index.html`, since dist lands directly in the webroot there. Running it before the COPY is correct at every base path — at root the app simply lands on the cleared directory. Bracketed `USER root`/`USER nginx` because the stage runs as `nginx` and cannot unlink from the root-owned webroot; that bracket mirrors the adjacent `apk upgrade` rather than introducing a new idiom. Verified by building and probing **both** base paths, not just the failing one: at `/tools/` the webroot holds only `tools` and the AC-04 probe returns `200 200 200 403`; at `/` the real `index.html` survives, `/` returns 200 with the tool grid, and "Welcome to nginx" appears zero times. `Dockerfile` diff vs base is 8 lines (≤25).
**Outcome:** applied
**Ref:** commit bcd993b; supersedes the escalation in A11
