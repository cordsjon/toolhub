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
