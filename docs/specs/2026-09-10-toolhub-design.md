# Capability: Private browser tool box (toolhub) behind the PosterBuilder login

> **Retargeted 2026-09-11 (00_Governance Q178/Q180).** Phase 0 measured that
> `posterbuilder.gtxs.eu` does not exist (DNS -> all-inkl 85.13.164.176, unreachable) and that
> VPS port 9100 is held by portmgr itself. Deploy target is now
> **`https://poster.getaccess.cloud/tools/`** (NPM proxy host 17, alongside the existing
> `/meeting` gate) on **port 9103**. Occurrences of the old host/port in this copy have been
> rewritten. The 00_Governance copy retains the original review record.

One bento-style site, hosted on the VPS at `https://poster.getaccess.cloud/tools/`, that offers small client-side tools (PDF, image, office/data, text and developer utilities) in one consistent UI, with every file processed in the browser and nothing reachable without a PosterBuilder OAuth session from an allowlisted account.

Glossary: **PosterBuilder** is the deployed app at `https://poster.getaccess.cloud`; **PosterEngine** is its repo at `~/projects/15_SAAS/20_PosterEngine` (Python package `poster_engine`, container `poster-engine`, bound to `127.0.0.1:9120` on the VPS per its `docker-compose.yml`). The login page, the verify endpoint and the `PE_TOOLS_USERS` change all live in PosterEngine. **NPM** is the Nginx Proxy Manager container (`npm`, Docker network mode `host`) that terminates TLS for `poster.getaccess.cloud`. **toolhub** is the new site and its container.

Decisions settled during brainstorming (2026-09-10): fork BentoPDF (AGPL-3.0) and extend it rather than build a new grid or merely self-host the stock image; gate the whole site, not just additions; host as a path under PosterBuilder using its existing nginx `auth_request` verify endpoint (subdomain `tools.gtxs.eu` deferred); first additions are Image, Office/Data and Text & Dev tools; Text & Dev tools are ported natively into the same UI, not linked to the `it-tools` container already running on the VPS (operator: "consolidate all under same UI").

Decisions assumed by the author, to be confirmed at spec review: reuse the existing portfolio identity `toolhub` and its reserved port 9103 instead of registering a new app; locales limited to `en` and `de`, with the German strings written by the implementer and reviewed by the operator, who is a native German speaker; allowlist is deny-by-default (empty list means nobody gets in); tool pages carry no state in the query string, so the login redirect preserves the path only; the spec lives in `00_Governance` until the fork repo exists, then moves with the first commit.

## Relationship to the existing `pdf-tools` fleet CLI (no overlap by design)

The fleet already has an agent-invocable PDF capability: `pdf-tools` in `a2a-cli-registry/fleet-clis/pdf-tools/`, five verbs (`split`, `compress`, `convert`, `redact`, `form-fill`) backed by a self-managed local Stirling PDF container, discoverable via `search_clis("pdf")` (built 2026-07-13, spec-panel 8.6). Its README maps each verb to a Stirling endpoint at `fleet-clis/pdf-tools/README.md:15-19`.

The two capabilities are deliberately disjoint in consumer, not in feature:

- `pdf-tools` serves **agents**, headlessly, on the Mac, against a local container. Batch and scriptable; no UI.
- toolhub serves the **human operator**, interactively, in a browser, on the VPS, with files that never leave the device.

Consequences this spec accepts: (a) `compress` and `convert` exist in both, with different engines and different trust models — that duplication is intentional and is not a defect to reconcile; (b) toolhub does **not** get an a2a registry entry, because a gated static site offers no headless invocation contract and `pdf-tools` already covers the agent consumer; (c) if a future story wants agent-invocable versions of toolhub's new image or media tools, they belong in a `pdf-tools`-style fleet CLI, not bolted onto this site. The operator-surface answer for this spec is therefore: human consumer = the browser grid behind the gate; agent consumer = out of scope, already served elsewhere.

## Solution: BentoPDF fork with a namespaced extension layer, gated by PosterBuilder

BentoPDF is a Vite + TypeScript static site (125 tool pages, per-tool logic modules, i18next locales, nginx container). The fork keeps upstream files untouched except for an enumerated integration allowance, and adds tools through files under an `x-` / `ext` namespace, so rebasing onto upstream releases is a bounded task (expected conflict surface: the allowance files only). The site is built in Simple Mode (no marketing chrome) with `BASE_URL=/tools/` and served by its own container on the VPS. NPM gets a custom location `/tools/` that proxies to that container and runs `auth_request` against PosterEngine's `/api/auth/verify`. PosterEngine gains one small change: the verify endpoint checks an allowlist when asked for the `tools` scope.

Repo: GitHub fork of `alam00000/bentopdf` under the operator's account, named `toolhub`, remotes `origin` (fork) and `upstream`. Local checkout `~/projects/15_SAAS/25_Toolhub` (parent `~/projects/15_SAAS/` exists; it holds PosterEngine). Work branch `toolhub`. Upstream baseline: the fork is cut from `upstream/main` at the commit current on bootstrap day (on 2026-09-10 that is `597e36904e8c`, one release after tag `v2.8.8`); that commit is recorded in `UPSTREAM_BASE` at the repo root and is the comparison target for the extension-boundary check. Upgrades rebase `toolhub` onto the next upstream release tag and update `UPSTREAM_BASE` in the same commit. it-tools (GPL-3.0) is pinned at commit `d505845f918e` (main, 2026-02-12); every port cites that commit. GPL-3.0 code may be combined into an AGPL-3.0 work (GPLv3 section 13); the combined work stays AGPL-3.0, the fork stays public, and the deployed site links to the source of the exact revision it runs (US-TH-01 AC-06).

Integration allowance (the only upstream-owned files the fork may change, checked by US-TH-01 AC-01):

- `src/js/config/tools.ts` (one import, one spread), `src/js/main.ts` (i18n key fallback to the registry), `vite.config.ts` (extension page glob and worker entries): at most 25 changed lines each.
- `nginx.conf` (added 2026-09-10 at planning, DECISIONS Q168): at most 25 changed lines. Measured with a real `nginx:alpine` and the upstream conf: its legacy `/tools/<slug>` → `/<slug>` 301 rules and the single-segment trailing-slash strip collide with `BASE_URL=/tools/` (`/tools/` → 301 `/tools` → 301 `/tools/` loop; `/tools/merge-pdf.html` → 301 `/merge-pdf` → 404). Premise P3 was refuted; the fix deletes those two blocks (9 lines).
- `package.json` and `package-lock.json`: additions to `dependencies`, `devDependencies` and `scripts` only; no version change to an upstream dependency. Every addition passes the deps registry gate. The line-count limit does NOT apply to `package-lock.json` — one dependency legitimately rewrites hundreds of lines. Its rule is semantic instead: no existing `packages["node_modules/<name>"].version` value may change; new entries are unrestricted. The checker parses the lockfile as JSON and compares version values against the base commit, never diff lines.
- `scripts/check-upstream-boundary.sh` and `scripts/check-ext-i18n.mjs`: new files in an upstream-owned directory. They are unrestricted, and the boundary checker must exempt itself explicitly — a checker its own rules forbid is a self-defeating gate.
- `public/locales/en/tools.json` and `public/locales/de/tools.json`: additions under the `ext` key only.
- New files at the repo root are not upstream-owned and are unrestricted: `NOTICE.md`, `UPSTREAM_BASE`, `DECISIONS.md`, `docker-compose.yml`, `deploy.sh`, `deploy/`, `scripts/check-ext-i18n.mjs`, `e2e/`.

Premises to verify before implementation starts (each becomes a `Verified:` line in the plan, not a recall):

- P1: NPM holds the proxy host for `poster.getaccess.cloud`, and the existing `/meeting` `auth_request` block lives in that host's custom-location or advanced config. Read it via the NPM UI or an operator-approved shell read; the fleet CLI has no file-read verb. NPM's network mode is `host` (measured 2026-09-10 via `fleet_cli.py status --json`), so loopback upstreams are reachable; the deploy preflight proves it with `docker exec npm curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9103/tools/`.
- P2: Port 9103 is free on the VPS (`ss -tlnp` in the deploy preflight, same pattern PosterEngine `deploy.sh` uses for 9220; note VPS ports are a separate namespace from the local portmgr list, e.g. `it-tools` holds 9101 on the VPS).
- P3: A BentoPDF Docker build with `BASE_URL=/tools/` and `SIMPLE_MODE=true` serves the grid and the stock `merge-pdf.html` under the subpath, and `/` is not 200. Basis: the upstream `Dockerfile` copies `dist` to `/usr/share/nginx/html${BASE_URL%/}` and `nginx.conf` `location /` uses `try_files $uri $uri/ $uri.html =404`, so the root directory has no index; expected 403 or 404. Combined use of the two args is untested here.
- P4: PosterEngine `_safe_next` (`poster_engine/web/app.py`, currently line 1288) accepts `/tools/<page>.html`. Read 2026-09-10: it returns the input when it starts with a single `/` and contains neither `\` nor `:`, else `/`. A path-only `next` therefore passes and any colon-bearing value is silently rewritten to `/` — a second reason the redirect carries `$uri` only. Confirm with a test case appended to the existing `tests/unit/test_login_next_redirect.py`, which already covers this redirect with a real SQLite fixture (`login_db`); do not create a new file and do not mock the session store.
- P7: `/api/auth/verify` currently has no test anywhere under PosterEngine `tests/` (grep, 2026-09-10). The US-TH-02 AC-01 cases are therefore all new coverage, written in the style of `test_login_next_redirect.py`: real DB fixture, real session cookie, no mocked seam.
- P9 (gates US-TH-03 AC-05): the address from which the Uptime Kuma container can reach toolhub on the VPS. Kuma runs as a container; if it is not host-networked it cannot use `127.0.0.1:9103` and must use the Docker host-gateway address. Resolve with `docker inspect uptime-kuma` for its network mode plus one `docker exec uptime-kuma curl` per candidate address, and record the winning URL. Until P9 resolves, AC-05 names no URL and cannot be verified — hence a premise, not a decision deferred inside the AC.
- P8 (gates US-TH-07): which `@ffmpeg/ffmpeg` build runs under the site's existing `Cross-Origin-Embedder-Policy: credentialless`. The multi-threaded build needs `SharedArrayBuffer`, which historically requires `require-corp`; the repo README (35 lines, fetched 2026-09-10) states no header requirement either way, so this is unresolved and must not be assumed. Resolve by loading both builds in a Playwright run against the deployed `/tools/` and recording which transcodes a 5 s fixture. Operator ruling 2026-09-10: if the multi-threaded build conflicts, ship the single-threaded build and change no site headers. A site-wide switch to `require-corp` is NOT authorised by this spec, because it would alter the loading conditions of every existing WASM-backed PDF tool.
- P5: PosterEngine listens on `127.0.0.1:9120` on the VPS (its `docker-compose.yml` says so; the deploy preflight confirms with `ss -tlnp`).
- P6: The bundled LibreOffice WASM converter (`@matbee/libreoffice-converter`, loaded from `BASE_URL + 'libreoffice-wasm/'` by `src/js/utils/libreoffice-loader.ts`) works through NPM: the container's generated `security-headers.conf` sends `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: credentialless` on every response, and NPM must pass them through unchanged. Prove with `curl -sI` on a live tool page and `crossOriginIsolated === true` in Playwright.

### Epic: toolhub platform — fork, gate, host

Delivers the deployed, gated fork with all stock BentoPDF tools and an empty extension layer ready for additions. Exit: an allowlisted operator logs in once at PosterBuilder, opens `/tools/`, and merges two PDFs with the stock tool; a valid session that is not allowlisted gets 403; an anonymous request lands on the login page and returns to the requested tool page after login; `./deploy.sh prod` has succeeded once and the rollback rehearsal of US-TH-03 AC-03 has passed once.

#### US-TH-01: Fork bootstrap and extension layer

As the operator, I want the BentoPDF fork checked out with a namespaced extension layer and a subpath Simple Mode build, so that new tools are added without touching upstream files beyond the integration allowance and upstream releases can be rebased in.

**Acceptance criteria**

- AC-01: Bootstrap is `gh repo fork alam00000/bentopdf --fork-name toolhub --clone=false`, then `git clone` into `~/projects/15_SAAS/25_Toolhub`, `git remote add upstream`, branch `toolhub` created from the recorded base commit, `UPSTREAM_BASE` written. Thereafter `git diff $(cat UPSTREAM_BASE) --stat` lists only files under the extension namespace (`src/pages/x-*.html`, `src/pages/_x-template.html`, `src/js/logic/x-*`, `src/js/config/tools-ext.ts`, `src/tests/x-*`, `src/tests/fixtures/x-*`), the unrestricted root files, and the integration-allowance files within their stated limits. A script `scripts/check-upstream-boundary.sh` performs this check and runs in `npm run lint`.
- AC-02: `src/js/config/tools-ext.ts` exports `extCategories: ToolCategory[]` and is merged into the registry by one import and one spread in `tools.ts`; the grid on `index.html` shows the three new category headers (Image, Office & Data, Text & Dev) after the upstream categories. Tool display names resolve through i18next by the registry entry's `i18nKey`; `main.ts` falls back to that key when its own name map has no entry.
- AC-03: `src/pages/_x-template.html` is a copy of an upstream tool page with the SEO meta, Open Graph, Twitter and all `application/ld+json` blocks removed; every extension page is generated from it. `grep -L 'bentopdf.com' src/pages/x-*.html` lists every extension page, meaning none contains that URL.
- AC-04: `docker build --build-arg BASE_URL=/tools/ --build-arg SIMPLE_MODE=true --build-arg VITE_BRAND_NAME=toolhub --build-arg VITE_BUILD_SHA=$(git rev-parse HEAD) .` succeeds (FULL sha, not `--short`: the footer of AC-06 is an AGPL-3.0 §13 source offer for the exact running revision, and an abbreviated sha can become ambiguous as the fork grows); with the image run locally as `docker run -p 3000:8080`, `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/tools/` prints 200 and the body contains the grid, the same for `/tools/merge-pdf.html` prints 200, and for `/` prints 403 or 404 (nothing served outside the subpath).
- AC-05: `npm run test:run` passes on the fork with upstream tests unchanged; `npm run lint` and upstream's `npm run lint:security` (eslint `no-unsanitized` rules) pass on every file under the extension namespace.
- AC-06: `NOTICE.md` lists BentoPDF (AGPL-3.0, upstream URL, base commit from `UPSTREAM_BASE`) and it-tools (GPL-3.0, URL, pinned commit) with the list of files derived from each; upstream `LICENSE` is preserved; the Simple Mode footer (`VITE_FOOTER_TEXT`) reads "Source: <fork URL>/tree/<VITE_BUILD_SHA>" so every deployed revision links to its own corresponding source.
- AC-07: Bilingual contract for every extension tool: entries in `public/locales/en/tools.json` and `public/locales/de/tools.json` under the `ext` key (`name`, `subtitle`, every label and message the page uses); `scripts/check-ext-i18n.mjs` runs in `npm run build` and fails it if any `ext.*` key present in `en` is missing in `de`. German strings are part of each tool story's definition of done, written by the implementer and reviewed by the operator.
- AC-08: Language resolution follows upstream `src/js/i18n/i18n.ts`: URL prefix, then stored or browser language, then `VITE_DEFAULT_LANGUAGE=de`, then `en`. Acceptance: `/tools/de/` shows German names for upstream and extension tools; a browser whose languages are all unsupported (Playwright locale `xx`) shows German; the language switcher works on every extension page and the choice persists across pages.

**Entity model** — extension registry entry (serialized in `tools-ext.ts`, consumed by the grid, by `main.ts` and by `scripts/generate-static-tool-links.mjs`)

- Fields: `href: string` (always `import.meta.env.BASE_URL + 'x-<slug>.html'`), `name: string` (English display name), `icon: string` (Phosphor class `ph-*`), `subtitle: string` (English one-liner), `i18nKey: string` (`tools:ext.<camelSlug>`), `category: 'Image' | 'Office & Data' | 'Text & Dev'`
- Defaults: none; every field is required
- Optionality: none
- Serialization: TypeScript object literal; the upstream link generator matches entries by regex on `href:` then `name:`, so field order `href, name, icon, subtitle, i18nKey, category` is preserved and the two upstream-matched fields stay first

#### US-TH-02: Whole-site gate through the PosterBuilder session

As the operator, I want `/tools/` to be reachable only with a valid PosterBuilder session from an allowlisted email, so that the tool box is private without a second login system.

**Acceptance criteria**

- AC-01: In PosterEngine, `GET /api/auth/verify` evaluates in this order and stops at the first match: `scope` present but not `tools` → 400; no valid session → 401; `scope=tools` and (`PE_TOOLS_USERS` empty or session email not in it, case-insensitive) → 403; otherwise 200 with `X-Poster-User`. Without `scope` the endpoint behaves exactly as today, so the `/meeting` gate is unaffected. Endpoint tests cover all four outcomes plus the empty-allowlist case with a valid session (403) and without one (401).
- AC-02: `PE_TOOLS_USERS` (comma-separated emails) is documented in `poster_engine/.env.example`; when unset or empty the app logs one warning through its existing structured logger at process start and every `scope=tools` request with a valid session gets 403 (deny by default).
- AC-03: `deploy/npm-location-tools.conf` in the toolhub repo holds the NPM custom-location snippet verbatim and is the single source for what is pasted into NPM; the file's header comment records the NPM proxy-host id and the date it was applied. Snippet:

  ```nginx
  location /tools/ {
      auth_request /_tools_auth;
      error_page 401 = @tools_login;
      error_page 403 = @tools_forbidden;
      proxy_pass http://127.0.0.1:9103/tools/;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
  }
  location = /_tools_auth {
      internal;
      proxy_pass http://127.0.0.1:9120/api/auth/verify?scope=tools;
      proxy_pass_request_body off;
      proxy_set_header Content-Length "";
      proxy_set_header X-Real-IP $remote_addr;
  }
  location @tools_login { return 302 /login?next=$uri; }
  location @tools_forbidden { return 403 "toolhub: account not allowlisted"; }
  ```

  `next` carries `$uri` (path only, already percent-encoded by nginx); tool pages keep no state in the query string, so nothing is lost. `_safe_next` validation on the PosterEngine side stays as is (P4).

- AC-04: Response headers from the toolhub container reach the browser unchanged through NPM: on an authenticated `curl -sI https://poster.getaccess.cloud/tools/merge-pdf.html` the headers include `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: credentialless` (P6).
- AC-05: Live smoke, run by `npm run smoke:live` after every deploy and appended to `deploy/log.md`: anonymous `curl -sI https://poster.getaccess.cloud/tools/x.html?a=1&b=2` returns 302 with `Location: /login?next=/tools/x.html`; an allowlisted session cookie (from `TOOLHUB_E2E_COOKIE` in `.env`) returns 200 for `/tools/` and for the hashed asset the deploy probe derived (US-TH-03 AC-02), passed to the smoke script as an argument rather than re-derived. The script classifies failures by exit code, and each branch has a test that forces it: **exit 1** the gate is wrong (anonymous request did NOT redirect, i.e. the site is exposed, or an allowlisted cookie got 403); **exit 2** `TOOLHUB_E2E_COOKIE expired or revoked — re-capture via the login page` (anonymous check correct, authenticated request redirected to login — note this cannot distinguish an expired session from one deleted server-side, and does not need to: the remedy is identical); **exit 3** `PosterEngine auth backend unreachable — check the poster-engine container` (any 5xx, because a failed `auth_request` subrequest makes nginx return 500, not 401, so a dead backend must never be reported as a gate regression). Tests feed the script an invalid cookie (expect 2) and a stubbed 500 (expect 3); without them the discriminator rots silently. The 403 branch is covered by the PosterEngine endpoint tests and once live on the test stack (`poster-engine-test`, port 9220) by setting its `PE_TOOLS_USERS` to an address the operator does not own.
- AC-06: End-to-end, `npm run test:e2e:live` (Playwright, `@playwright/test` added as a devDependency, credentials `TOOLHUB_E2E_EMAIL` and `TOOLHUB_E2E_PASSWORD` for PosterBuilder's password login from `.env`): open `/tools/merge-pdf.html` anonymously, complete the login form, assert the browser lands on `/tools/merge-pdf.html`, that its file input is present, and that `window.crossOriginIsolated` is `true`. The run's result line is appended to `deploy/log.md`.

**Entity model** — verify endpoint contract (HTTP, consumed by NPM)

- Fields: request `scope: str | absent` (query), response status `200 | 400 | 401 | 403`, response header `X-Poster-User: str` (email, present only on 200)
- Defaults: `scope` absent → current behaviour (session validity only, 200 or 401)
- Optionality: `scope` optional; the only accepted value is `tools`
- Serialization: empty body on every status

#### US-TH-03: VPS hosting and one-command deploy

As the operator, I want `./deploy.sh prod` to build and run the toolhub container on the VPS with the same safety rails as PosterEngine, so that a tool addition reaches the live site in one command with rollback.

**Acceptance criteria**

- AC-01: `docker-compose.yml` defines one service `toolhub` built from the repo `Dockerfile` with build args `BASE_URL=/tools/`, `SIMPLE_MODE=true`, `VITE_BRAND_NAME=toolhub`, `VITE_DEFAULT_LANGUAGE=de`, `VITE_BUILD_SHA`, image tag `toolhub:current`, binding `127.0.0.1:9103:8080`, `restart: unless-stopped`, and a container healthcheck on `http://127.0.0.1:8080/tools/merge-pdf.html`.
- AC-02: `deploy.sh` is cloned from `~/projects/15_SAAS/20_PosterEngine/deploy.sh` and supports `prod` (alias `push`), `status`, `logs`, `rollback`, `rehearse-failure`; `prod` refuses a dirty or unpushed tree, runs the P1, P2 and P5 preflight checks, rsyncs the tree to `/toolhub` on the VPS excluding `.git`, `node_modules`, `dist`, `.env`, builds the image as `toolhub:candidate`, starts it, and runs the health probe, each URL requiring 200 within 120 s: `http://127.0.0.1:9103/tools/`, `http://127.0.0.1:9103/tools/merge-pdf.html`, and one hashed asset. The asset URL is derived, not guessed: the image build writes `/usr/share/nginx/html/tools/.vite/manifest.json` as part of `dist`, so the probe reads the first entry's `file` field with `docker exec toolhub cat /usr/share/nginx/html/tools/.vite/manifest.json` and curls `http://127.0.0.1:9103/tools/<file>`. It must NOT read the build host's `dist/` — `dist` is excluded from the rsync, so no such directory exists on the VPS, and a probe pointing there would 404 on every deploy. Deriving the asset from the running image also makes the probe release-specific: a stale asset path from a previous build cannot pass. On success it retags: previous `toolhub:current` → `toolhub:rollback`, `toolhub:candidate` → `toolhub:current`. On failure it exits 1, prints the last 50 container log lines, and restarts `toolhub:current` (the last healthy release is never overwritten, because retagging happens only after the probe passes).
- AC-03: `rollback` starts `toolhub:rollback`, runs the same probe, and on success swaps the tags back; on a first install (no `toolhub:rollback`) it refuses with a one-line message. `rehearse-failure` deploys a candidate built with `BASE_URL=/broken/` so the probe fails deterministically, asserts `prod` exited 1 and that `toolhub:current` is still serving 200, then runs `rollback` and asserts 200 again; the rehearsal result is appended to `deploy/log.md` and is a platform-epic exit condition. The rehearsal proves failure DETECTION only; it does not prove header integrity, because a 404 response carries different headers than a served page. Header integrity is a separate always-on check: `prod` re-runs the US-TH-02 AC-04 `curl -sI` assertion against the live URL after every successful deploy and fails the deploy if `Cross-Origin-Opener-Policy` or `Cross-Origin-Embedder-Policy` is absent or changed, so a proxy-config edit that silently strips them is caught at the deploy that introduces it rather than at the next media-tool bug report (see P8).
- AC-04: The container is registered in `~/projects/00_Governance/infra-inventory/inventory.md` under `toolhub` with host VPS and port 9103, and `portfolio_apps/toolhub/about.md` gets `repo` updated to the fork path and `envs: ['prod']`.
- AC-05: Two Uptime Kuma monitors on the VPS: a public one on `https://poster.getaccess.cloud/tools/` expecting 302 (gate alive), and a private one on `http://127.0.0.1:9103/tools/merge-pdf.html` expecting 200 (backend alive; if Kuma's container cannot reach host loopback, the monitor targets the Docker host-gateway address, established at implementation and recorded in `deploy/log.md`).

### Epic: toolhub first tool categories — image, office and data, text and dev

Delivers 4 image tools, 3 office/data tools and 10 text and developer tools inside the platform epic's grid, each meeting the bilingual contract of US-TH-01 AC-07, the untrusted-content rules below, and unit-tested against real fixtures. Exit: the operator round-trips one file in each new category on the live site, the i18n check passes in the build, and the privacy network assertion of US-TH-04 AC-06 passes.

Untrusted-content rules for every extension tool: outputs are rendered by building DOM nodes or setting `textContent`, never by assigning HTML strings; where HTML must be rendered (Markdown preview, DOCX intermediate HTML) it passes through the bundled DOMPurify first; links in rendered output are restricted to `http`, `https` and `mailto`; each story carries an adversarial fixture whose payload must display as data. Upstream's `npm run lint:security` enforces the first rule mechanically (US-TH-01 AC-05).

#### US-TH-04: Image tools

As a user, I want to resize, convert, compress and strip metadata from images in the browser, so that quick image chores need no desktop app or upload.

**Acceptance criteria**

- AC-01: Four pages exist: `x-image-resize`, `x-image-convert`, `x-image-compress`, `x-image-strip-exif`, each accepting drag-drop or file picker for PNG, JPEG, WebP, HEIC (via the already-bundled `heic2any`) and batch input of up to 50 files, each file at most 50 MB and 50 megapixels; a file over either limit is skipped with a visible per-file error and the batch continues.
- AC-02: Resize accepts width, height or percentage with aspect lock; convert targets PNG, JPEG, WebP with a quality slider for lossy formats; compress reports before and after byte size per file; strip-exif re-encodes through canvas and the output contains no EXIF segment (verified in the test by scanning the JPEG for an APP1 marker `0xFFE1` followed by `Exif\0\0`; no new dependency).
- AC-02b: Encoding for convert and compress uses the Squoosh codec modules (`GoogleChromeLabs/squoosh`, Apache-2.0, 25863 stars, pushed 2026-09-10; verified 2026-09-10) via their published `@jsquash/*` npm packages, registered through the deps registry: MozJPEG for JPEG, `@jsquash/webp` for WebP, OxiPNG for PNG optimisation. Canvas re-encoding remains the fallback path when a codec module fails to load, and the fallback is exercised by a test that stubs the module loader to reject. Squoosh attribution is added to `NOTICE.md`.
- AC-03: Processing runs in a Web Worker; a Cancel button calls `Worker.terminate()` and marks remaining files as cancelled; progress is determinate per file (files done of files total) and the batch summary shows succeeded, skipped and failed counts. Responsiveness: in the Playwright run against `vite preview`, a 20-file batch keeps the page responding to a click on Cancel within 500 ms.
- AC-04: Output is a single download for one file and a ZIP (already-bundled `jszip`) for many; filenames keep the stem and get the new extension.
- AC-05: Vitest covers each logic module with real fixture files under `src/tests/fixtures/x-image/` (one PNG, one JPEG with EXIF, one WebP, one HEIC): dimensions of a resized output, mime type of a converted output, size reduction of a compressed JPEG, absence of EXIF after strip, and the over-limit skip path. A red/green check confirms the strip test fails when the strip step is bypassed.
- AC-06: Privacy assertion, in the Playwright run for this and the other two tool stories: while one image, one spreadsheet and one text tool process a fixture, every recorded network request is checked against a per-category allowlist, and the assertion fails on anything outside it. Same-origin requests are always permitted (the local `libreoffice-wasm/` assets and the bundled `@jsquash/*` codecs are same-origin). Cross-origin is permitted ONLY for image and PDF tools, ONLY to `cdn.jsdelivr.net`, and ONLY for the exact upstream WASM module paths enumerated in `NOTICE.md` — a host-level wildcard is not sufficient, because it would let a future tool exfiltrate to any jsDelivr path and still pass. Office/data and text/dev tools must produce no cross-origin request at all. Independently of origin, the assertion fails if any request carries a body, or if a GET's query string or path exceeds 1024 bytes, since a long GET is the obvious way file content leaves without a body. A negative-control test patches one tool to POST its input to a local sink and asserts the assertion fails, proving it can fail.

#### US-TH-05: Office and data tools

As a user, I want to view and convert spreadsheets and Word files in the browser, so that I can inspect a client's XLSX or turn a DOCX into Markdown without opening Office.

**Acceptance criteria**

- AC-01: `x-sheet-viewer` opens XLSX, XLS, ODS and CSV via the already-bundled SheetJS, shows a sheet selector and a scrollable preview of the first 1000 rows with a "showing 1000 of N" note, and exports the full selected sheet (all rows) as CSV, JSON or Markdown table. JSON is an array of row objects keyed by the header row; duplicate headers get `_2`, `_3` suffixes in order of appearance, empty headers become `col<N>` by 1-based column index, and the export is tested on fixtures for both cases.
- AC-02: `x-csv-convert` converts CSV to JSON and Markdown, and JSON (array of flat objects) to CSV, with delimiter auto-detection (`,` `;` `\t`) via the already-bundled `papaparse`; a malformed input shows the parser's error row and column, never a blank output.
- AC-03: `x-docx-to-markdown` converts DOCX to HTML through the bundled LibreOffice WASM converter (`@matbee/libreoffice-converter`, local assets, P6) and then to Markdown with `turndown` (new dependency, registered through the deps registry), preserving headings, lists, bold, italic, links and tables; images are dropped with a placeholder line. The HTML step is sanitised with DOMPurify before the Markdown pass.
- AC-04: Vitest (jsdom) covers SheetJS export semantics, CSV conversion and the HTML-to-Markdown pass with real fixtures under `src/tests/fixtures/x-office/` (a 3-sheet XLSX with duplicate and empty headers, a semicolon CSV, the HTML that LibreOffice produces for the DOCX fixture). The DOCX-to-HTML step cannot run under jsdom, so it is covered by a Playwright test against `vite preview` that converts the DOCX fixture (one table, one list, one embedded image) and asserts the table and list survive in the Markdown, and that the image became the placeholder line while no `![](...)` syntax remains — a silently lost image is a user-visible data loss, so it is asserted, not assumed; this test runs in `npm run test:e2e` and is a story exit condition, not optional.
- AC-05: Adversarial fixture: a spreadsheet cell containing `<img src=x onerror=alert(1)>` renders as that literal text in the preview and appears escaped in the Markdown export; the Playwright test asserts no dialog opened.

#### US-TH-06: Text and developer tools

As a user, I want the everyday text and developer utilities inside the same grid, so that I stop switching to a second tool site.

**Acceptance criteria**

- AC-01: Ten pages exist: `x-json-format` (format, minify, validate with error position), `x-yaml-json` (both directions), `x-base64` (text and file, URL-safe toggle), `x-url-encode`, `x-hash` (MD5, SHA-1, SHA-256, SHA-512 of text or file), `x-uuid` (v4 and ULID, bulk count), `x-regex` (JavaScript flavour, live matches and groups), `x-text-diff` (line and word diff via the already-bundled `diff`, side by side), `x-timestamp` (Unix seconds and ms, ISO 8601, local and UTC), `x-jwt-decode` (header and payload, expiry highlighting, no signature verification).
- AC-02: Pure logic for each tool lives in `src/js/logic/x-devtools/*.ts` as functions with no DOM access; where a function is ported from it-tools `src/utils/`, the file header cites the source path and the pinned commit `d505845f918e`, and `NOTICE.md` lists it.
- AC-03: Every tool has a copy-to-clipboard button on each output and remembers its last options in `localStorage` under the key prefix `toolhub:`.
- AC-04: Vitest covers every pure function with at least one positive and one negative case. `x-regex` evaluates in a Web Worker; the main thread starts a 2 s `setTimeout`, calls `Worker.terminate()` on expiry and renders a timeout message; jsdom implements no `Worker`, so this path CANNOT be tested in Vitest: the timeout case lives in the Playwright suite (`npm run test:e2e`), feeds a catastrophic-backtracking pattern, asserts the timeout message renders within 2 s, then asserts a subsequent evaluation on the same page still returns a correct result — only possible if the wedged worker was really terminated and a fresh one started. Vitest covers the pure matcher and the argument builder only.
- AC-05: Adversarial fixture: the JSON formatter and the YAML converter are given `{"a":"<script>alert(1)</script>"}`; the output area shows the literal text and the Playwright test asserts no dialog opened.

### Epic: toolhub media tools — audio and video in the browser

Delivers client-side audio and video conversion, trimming and extraction on top of `ffmpeg.wasm` (`ffmpegwasm/ffmpeg.wasm`, MIT, 17800 stars, pushed 2026-02-01; verified 2026-09-10), inside the same grid and gate. This epic is BLOCKED until P8 resolves; if P8 forces the single-threaded build, every AC below still holds with longer runtimes and the file-size ceiling of AC-04 drops to 200 MB. Exit: the operator converts one video and extracts its audio on the live site, and the privacy network assertion of US-TH-04 AC-06 passes for a media tool too.

#### US-TH-07: Media conversion and extraction

As a user, I want to convert, trim and extract audio from media files in the browser, so that small media chores need no desktop tool and no upload.

**Acceptance criteria**

- AC-01: P8 is resolved and recorded in `deploy/log.md` before any other AC in this story is worked; the chosen `@ffmpeg/ffmpeg` build and its pinned version are named in `NOTICE.md`, registered through the deps registry, and the site's response headers are unchanged from US-TH-02 AC-04, asserted by re-running that AC's `curl -sI` check after this epic deploys. This presumes the single-threaded outcome, the only outcome this spec authorises (P8). If P8 resolves that only the multi-threaded build is viable, US-TH-07 STOPS and returns to the operator as a scope question — it does not proceed by relaxing this assertion, because that would change the loading conditions of every existing WASM-backed PDF tool.
- AC-02: Four pages exist: `x-media-convert` (MP4, WebM, MOV, MKV, AVI in; MP4 or WebM out), `x-audio-convert` (MP3, WAV, M4A, FLAC, OGG in and out), `x-media-trim` (start and end timecode, stream copy where the codecs allow it), `x-audio-extract` (audio track out of a video as MP3 or WAV).
- AC-03: A progress bar reads ffmpeg's own progress callback, showing percentage and elapsed time; Cancel calls `ffmpeg.terminate()` and the page returns to an idle state that accepts a new file without a reload.
- AC-04: Input is capped at 500 MB (200 MB on the single-threaded build) and one file at a time; over-limit input is refused before load with a message naming the limit. A visible notice states that large files are limited by available browser memory.
- AC-05: Vitest covers the argument-builder functions (input options, filter and codec flags, output naming) as pure functions with no ffmpeg invocation, including a negative case per tool. The actual transcode cannot run under jsdom, so it is covered by a Playwright test against `vite preview` that converts a committed 5-second fixture (`src/tests/fixtures/x-media/sample.mp4`, under 2 MB) to WebM and extracts its audio, asserting both outputs are non-empty and carry the expected container magic bytes. This test runs in `npm run test:e2e` and is a story exit condition.
- AC-06: The untrusted-content rules of the tools epic apply: filenames and any ffmpeg log output shown in the UI are inserted as text, never as HTML, with an adversarial fixture whose filename contains `<img src=x onerror=alert(1)>`.

## Out of scope for v1

Subdomain `tools.gtxs.eu`; self-hosting the PyMuPDF, Ghostscript and CoherentPDF WASM modules (they stay on jsDelivr as upstream; the LibreOffice converter is local in both upstream and the fork); locales beyond `en` and `de`; the `single-html-apps` games; retiring the `it-tools` container (revisit after v1 ships and the ported tools have been in use); SVG optimisation; PPTX tools; any server-side processing; preserving query strings across the login redirect; a site-wide change to `Cross-Origin-Embedder-Policy: require-corp` (see P8).

### External sources evaluated and refused (GitHub survey, 2026-09-10)

Each was checked against the GitHub API this session; star counts and licences are quoted, not recalled.

- `diegomura/react-pdf` (16778 stars, MIT) — REFUSED. Renders PDFs from React components; the fork is vanilla TypeScript with no React. Adopting it means adding a UI framework to serve one generation use case that upstream's Markdown-to-PDF and HTML-to-PDF paths already approximate. Revisit only if PDF-generation-from-data becomes a stated requirement.
- `photopea/photopea` (8424 stars) — REFUSED, no open-source licence declared. Source-available is not reusable.
- `tldraw/tldraw` (50249 stars) — REFUSED for now; the licence resolves to `NOASSERTION`, so it needs a manual licence read before any dependency decision. Not needed for any story here.
- `mifi/lossless-cut` (43631 stars, GPL-2.0) — REFUSED, an Electron desktop app, not a static browser site.
- `aghyad97/browserytools` (682 stars, AGPL-3.0) — NOT ADOPTED. The closest analogue to this project found in the survey and worth watching as prior art, but younger and smaller than the BentoPDF base; porting from it buys little.
- `zhaoolee/OnlineToolsBook` (2669 stars, Apache-2.0) and `cipher387/osint_stuff_tool_collection` (8808 stars) — REFUSED, link directories rather than portable code.
- `Stirling-Tools/Stirling-PDF` — REFUSED, server-side Java; contradicts the browser-only privacy promise.
- `rtivital/omatsuri` (2973 stars, MIT) — BACKLOG. A genuine client-side tool collection whose SVG-optimiser and CSS tools overlap the deferred SVG work; revisit when SVG optimisation leaves out-of-scope.

Survey caveat: run unauthenticated, so GitHub's search rate limit throttled several query variants and no "awesome web tools" index was located. Absence of a candidate here is not evidence it does not exist.

## Duo review — pre-panel round 1

_Generated by review-duo at 2026-09-10T18:07:15Z. Phase artifacts: `/Users/jcords-macmini/projects/00_Governance/docs/superpowers/specs/2026-09-10-toolhub-design-duo-20260910-200509`_
_Two independent reviewers, shared context. Claude triages per-comment. No LLM-driven synthesis._

### DeepSeek findings

## Findings — DEEPSEEK

### [CRITICAL] AC-01 of US-TH-01 requires a clone that the context layer says does not exist

- What: The spec's first acceptance criterion asserts `~/projects/15_SAAS/25_Toolhub` is a clone of the operator's fork, but the grounding layer reports that path as `MISSING`.
- Where: US-TH-01 AC-01: "`~/projects/15_SAAS/25_Toolhub` is a clone of the operator's GitHub fork"; CONTEXT.md §2.1 lists `~/projects/15_SAAS/25_Toolhub` as `MISSING`.
- Why it matters: If the path is genuinely absent, the parent directory `~/projects/15_SAAS/` may not exist either, and the spec never states who creates the fork on GitHub, what the fork's name is, or whether the parent directory is created as part of bootstrap. The plan will stall on the first step.
- Suggested fix: Add an explicit bootstrap sub-step (create parent dir, fork via `gh repo fork alam00000/bentopdf --clone=false`, then `git clone`), or reword AC-01 to "after bootstrap, `~/projects/15_SAAS/25_Toolhub` exists as a clone…" and add a precondition line naming the fork URL.
- Confidence: high

### [CRITICAL] AC-03 of US-TH-02 references an internal auth location that is never defined

- What: The NPM snippet uses `auth_request /_tools_auth;` but no `location = /_tools_auth { ... }` block is specified anywhere in the spec.
- Where: US-TH-02 AC-03: "`auth_request /_tools_auth;` with an internal location proxying to `http://127.0.0.1:9120/api/auth/verify?scope=tools`".
- Why it matters: `auth_request` requires a named internal location to proxy to; without it nginx fails to start or returns 500 on every request. The spec describes the internal location in prose but does not commit to its exact directive form (`internal;`, `proxy_pass`, `proxy_pass_request_body off;`, `proxy_set_header Content-Length "";`). Whoever pastes the snippet into NPM will guess, and the failure mode is a broken gate on the live host.
- Suggested fix: Include the full snippet verbatim in the spec (or in the referenced `deploy/npm-location-tools.conf` example inline), including the `location = /_tools_auth { internal; proxy_pass http://127.0.0.1:9120/api/auth/verify?scope=tools; proxy_pass_request_body off; proxy_set_header Content-Length ""; }` block.
- Confidence: high

### [IMPORTANT] Port 9120 for PosterEngine is asserted but never grounded

- What: The auth_request target is `http://127.0.0.1:9120/api/auth/verify?scope=tools`, but the spec never states that 9120 is PosterEngine's port, and the context layer does not verify it.
- Where: US-TH-02 AC-03: "proxying to `http://127.0.0.1:9120/api/auth/verify?scope=tools`".
- Why it matters: If PosterEngine actually listens on a different port, the gate silently 502s and the whole site is unreachable. The spec's premise list (P1–P4) verifies NPM config, port 9103, BentoPDF build, and `_safe_next`, but not the PosterEngine port.
- Suggested fix: Add a premise P5: "PosterEngine listens on 127.0.0.1:9120 on the VPS (verify via `ss -tlnp` in the deploy preflight)" — or correct the port if it differs.
- Confidence: medium

### [IMPORTANT] `_safe_next` premise (P4) is scoped to PosterEngine but the login flow is PosterBuilder

- What: P4 says `_safe_next` in PosterEngine `app.py` must accept `/tools/...`, yet the spec repeatedly refers to "PosterBuilder's `/api/auth/verify`" and "PosterBuilder login page". The relationship between PosterEngine and PosterBuilder is never stated.
- Where: Premises list P4: "`_safe_next` in PosterEngine `app.py` accepts `/tools/...`"; US-TH-02 AC-03/AC-04/AC-05 refer to PosterBuilder's verify endpoint and login page.
- Why it matters: If PosterEngine and PosterBuilder are the same service under two names, the spec should say so once. If they are different services, the verify endpoint and the login page live in different codebases and the change surface is larger than the spec implies. Either way the reader cannot tell which repo gets the `PE_TOOLS_USERS` change.
- Suggested fix: Add a one-line glossary at the top of the spec: "PosterBuilder = the deployed app; PosterEngine = its backend repo at `~/projects/.../poster_engine`" (or correct the mapping). Then use one name consistently.
- Confidence: medium

### [IMPORTANT] AC-01 of US-TH-01 caps upstream diffs at 10 lines but AC-02 requires a spread merge that likely exceeds it

- What: AC-01 allows at most 10 lines of diff in each of `src/js/config/tools.ts`, `src/js/main.ts`, `vite.config.ts`; AC-02 requires `tools.ts` to import `extCategories` and spread it into the registry, and `main.ts` to wire i18n lookup by English name.
- Where: US-TH-01 AC-01 ("each with a diff of at most 10 lines") vs AC-02 ("merged into the registry by a single spread in `tools.ts`") and the entity model note ("also the i18n lookup key via `main.ts`").
- Why it matters: A 10-line cap is tight for an import + spread + type annotation, and the `main.ts` change for i18n lookup is not described at all. If the cap is exceeded during implementation, AC-01 fails and the plan is blocked on a spec edit.
- Suggested fix: Either raise the cap to a realistic number (e.g. 20 lines) or split the cap per file with a rationale, and add an AC describing exactly what the `main.ts` change is (one line? a lookup table?).
- Confidence: medium

### [IMPORTANT] AC-04 of US-TH-01 asserts `/` returns 404 but BentoPDF's Dockerfile behavior is unverified

- What: The AC requires that with `BASE_URL=/tools/` the root path returns 404, but P3 only verifies that the grid and one tool page serve correctly under the subpath — it does not verify that `/` is not also served.
- Where: US-TH-01 AC-04: "`/` prints 404 (nothing served outside the subpath)"; P3: "serves the grid and one tool page correctly under the subpath".
- Why it matters: Many static servers (including nginx default configs) will serve `index.html` at `/` regardless of `BASE_URL`, because `BASE_URL` is a Vite build-time constant, not a server routing rule. If `/` returns 200, AC-04 fails and the "nothing served outside the subpath" claim is false — which matters because the gate is on `/tools/` only.
- Suggested fix: Extend P3 to explicitly test `curl -sI http://127.0.0.1:3000/` and confirm 404, or add an nginx rule in the container config that returns 404 for `/` and document it in AC-04.
- Confidence: medium

### [IMPORTANT] AC-05 of US-TH-02 asserts a Playwright test but no Playwright infrastructure is scoped

- What: The AC requires a Playwright run against the live URL after deploy, but the spec never states where Playwright is installed, how it authenticates as the allowlisted operator, or how the test is invoked.
- Where: US-TH-02 AC-05: "Playwright, run once after deploy: log in via the PosterBuilder login page as the allowlisted operator with `next=/tools/x-image-resize.html`".
- Why it matters: "Run once after deploy" is not a repeatable acceptance criterion — it is a manual step dressed as automation. The operator's credentials are not specified as a secret source, and the test is not wired into any command. This will be skipped or hand-waved.
- Suggested fix: Either downgrade to a manual smoke step with a recorded transcript, or specify: Playwright lives in the toolhub repo, credentials come from `PE_TOOLS_USERS` first entry + a test password env var, invoked via `npm run test:e2e:live`, and the AC requires the run to be recorded in the deploy log.
- Confidence: high

### [IMPORTANT] AC-03 of US-TH-05 depends on a LibreOffice WASM converter that is not named or pinned

- What: The DOCX-to-Markdown tool is specified to use "the bundled LibreOffice WASM converter", but no package name, version, or bundle-size budget is given.
- Where: US-TH-05 AC-03: "through the bundled LibreOffice WASM converter (DOCX to HTML)".
- Why it matters: LibreOffice WASM builds are large (tens of MB) and their APIs differ between forks (`@libreoffice/wasm`, `libreoffice-wasm`, `@zotero/libreoffice-wasm`, etc.). "Bundled" also conflicts with the out-of-scope note "self-hosted WASM assets (jsDelivr stays the source, as upstream)" — if the converter is bundled, it is self-hosted, which contradicts the out-of-scope line.
- Suggested fix: Name the exact package and version, state whether it is bundled or fetched from jsDelivr, and reconcile with the out-of-scope note. If it is fetched, AC-03 should say so and the "bundled" wording should be removed.
- Confidence: high

### [IMPORTANT] Out-of-scope says "self-hosted WASM assets (jsDelivr stays the source)" but AC-03 of US-TH-05 requires a bundled WASM converter

- What: Direct contradiction between the out-of-scope section and US-TH-05 AC-03.
- Where: Out of scope: "self-hosted WASM assets (jsDelivr stays the source, as upstream)"; US-TH-05 AC-03: "the bundled LibreOffice WASM converter".
- Why it matters: One of the two is wrong. If WASM stays on jsDelivr, the DOCX converter is a runtime fetch and the tool is not fully client-side-offline; if it is bundled, the out-of-scope line is false and the container image grows substantially.
- Suggested fix: Pick one. If jsDelivr, reword AC-03 to "fetched from jsDelivr at runtime" and note the offline limitation. If bundled, remove the out-of-scope line and add a bundle-size budget to AC-03.
- Confidence: high

### [IMPORTANT] AC-02 of US-TH-06 requires citing "source path and commit" for ported it-tools code but no commit is pinned

- What: The AC requires each ported file to cite the it-tools source path and commit, but the spec never names the it-tools version or commit to port from.
- Where: US-TH-06 AC-02: "the file header cites the source path and commit, and `NOTICE.md` lists it".
- Why it matters: Without a pinned upstream commit, "the commit" is whatever the implementer happened to have checked out, and the NOTICE attribution is not reproducible. This is also an AGPL/GPL compliance issue — attribution must be to a specific version.
- Suggested fix: Add a line to the spec: "it-tools is pinned at commit `<sha>` (tag `<tag>`); all ports cite this commit." Or add a premise to resolve the pin before implementation.
- Confidence: high

### [IMPORTANT] AC-04 of US-TH-06 requires a 2-second timeout test but does not specify the worker termination mechanism

- What: The regex tool must terminate a catastrophic-backtracking worker and show a timeout message, but the spec does not say how the worker is terminated or how the timeout is enforced.
- Where: US-TH-06 AC-04: "`x-regex` is tested with a catastrophic-backtracking input and must return within 2 s (the worker is terminated and the UI shows a timeout message)".
- Why it matters: `Worker.terminate()` is the only reliable way to stop a runaway regex in JS; a `setTimeout` on the main thread will not interrupt the worker. If the implementer uses a naive timeout, the test will hang and the AC will fail.
- Suggested fix: Add to AC-04: "the worker is terminated via `Worker.terminate()` after a 2 s `setTimeout` on the main thread; the test asserts the worker is gone and the timeout message is rendered."
- Confidence: medium

### [IMPORTANT] AC-01 of US-TH-04 claims HEIC support via `heic2any` but the package is not listed as a dependency anywhere

- What: The image tools accept HEIC "via the bundled `heic2any`", but no AC or premise adds `heic2any` to `package.json`.
- Where: US-TH-04 AC-01: "PNG, JPEG, WebP, HEIC (via the bundled `heic2any`)".
- Why it matters: `heic2any` is not a BentoPDF upstream dependency (it is a separate npm package). Adding it is a new dependency, which the spec's "keeps upstream untouched" framing does not cover. The AC-01 of US-TH-01 caps upstream diffs but says nothing about `package.json`.
- Suggested fix: Add an AC or note: "`heic2any`, `jszip`, `papaparse`, and SheetJS are added to `package.json` dependencies; `package.json` is added to the list of upstream files this US may touch in AC-01."
- Confidence: high

### [IMPORTANT] AC-01 of US-TH-01 lists three upstream files but the dependency additions require `package.json`

- What: AC-01 enumerates the upstream files the US may touch as `tools.ts`, `main.ts`, `vite.config.ts`, but the new tools require new npm dependencies, which means `package.json` (and likely `package-lock.json`) must change.
- Where: US-TH-01 AC-01: "the three upstream files this US may touch (`src/js/config/tools.ts`, `src/js/main.ts`, `vite.config.ts`)".
- Why it matters: The AC as written will fail on the first `npm install heic2any`. Either the AC is wrong or the dependencies are expected to be vendored, which is not stated.
- Suggested fix: Add `package.json` and `package-lock.json` to the allowed-touch list, with a note that only `dependencies`/`devDependencies` entries are added (no version bumps to upstream deps).
- Confidence: high

### [IMPORTANT] AC-07 of US-TH-01 requires a bilingual contract but the German translations are not scoped

- What: The AC requires every `ext.*` key present in `en` to also be present in `de`, but no AC or US assigns who writes the German strings or how they are reviewed.
- Where: US-TH-01 AC-07: "`scripts/check-ext-i18n.mjs` runs in `npm run build` and fails it if any `ext.*` key present in `en` is missing in `de`".
- Why it matters: The check will fail the build on every new tool until someone writes German. If the operator is not a German speaker, this is a hidden dependency on a translator. The spec assumes the operator can produce German strings but never says so.
- Suggested fix: Either add a US or AC for German translation (who, when, reviewed how), or relax the check to warn instead of fail for `de` until translations land, or state explicitly that the operator writes the German strings.
- Confidence: medium

### [IMPORTANT] AC-08 of US-TH-01 asserts `VITE_DEFAULT_LANGUAGE=de` overrides browser locale but the upstream behavior is not verified

- What: The AC claims that with `VITE_DEFAULT_LANGUAGE=de`, an English browser locale sees German on first visit, but no premise verifies that this env var exists or that it overrides browser detection.
- Where: US-TH-01 AC-08: "With `VITE_DEFAULT_LANGUAGE=de` the grid on first visit from an English browser locale shows German".
- Why it matters: i18next's default behavior is to detect browser language unless `lng` is explicitly set. If BentoPDF's i18n init uses `lng: undefined` and relies on `detection`, the env var may be ignored. This is a build-time behavior that needs a premise, not an assertion.
- Suggested fix: Add a premise P6: "BentoPDF's i18n init reads `VITE_DEFAULT_LANGUAGE` and uses it as the initial `lng` (verify in `src/js/i18n.ts` or equivalent)". If it does not, AC-08 needs a code change to `main.ts` (which then counts against the AC-01 line cap).
- Confidence: medium

### [IMPORTANT] AC-05 of US-TH-03 registers an Uptime Kuma monitor expecting 302, but 302 is also what a broken gate returns

- What: The monitor treats 302 as healthy, but a misconfigured gate that redirects everything (including allowlisted users) also returns 302.
- Where: US-TH-03 AC-05: "Uptime Kuma on the VPS has a monitor for `https://poster.getaccess.cloud/tools/` expecting 302 (the gate answers anonymous checks with a redirect, so 302 is the healthy signal)".
- Why it matters: The monitor cannot distinguish "gate working, anonymous redirected" from "gate broken, everyone redirected". A regression that breaks the allowlist check would still show green.
- Suggested fix: Add a second monitor that authenticates (or hits a health endpoint that bypasses the gate) and expects 200, or change the monitor to check a static asset under `/tools/assets/` with an allowlisted cookie. Alternatively, add a `/tools/healthz` endpoint that returns 200 without auth and monitor that.
- Confidence: medium

### [NIT] AC-01 of US-TH-01 says "the three upstream files this US may touch" but the list has three items and the count is correct — however the phrasing "this US may touch" is ambiguous about US-TH-02 through US-TH-06

- What: The AC scopes the touch list to US-TH-01 only, but later USes (US-TH-04, US-TH-05, US-TH-06) will also need to touch `package.json` and possibly `vite.config.ts` (for worker bundling).
- Where: US-TH-01 AC-01: "the three upstream files this US may touch".
- Why it matters: A reader may interpret the list as global. The later USes do not restate their allowed-touch list, so the constraint is silently dropped.
- Suggested fix: Add a line to each later US: "Allowed upstream touches: `package.json`, `package-lock.json`" (or whatever applies), or move the constraint to the epic level.
- Confidence: medium

### [NIT] AC-02 of US-TH-02 says "logs one startup warning" but does not say where the log goes

- What: The deny-by-default behavior logs a warning, but the log destination is unspecified.
- Where: US-TH-02 AC-02: "the endpoint logs one startup warning and answers 403".
- Why it matters: "Startup warning" implies the check runs at import time, but the endpoint is a request handler — the warning would more naturally be per-request or at first request. The wording is ambiguous about when the warning fires.
- Suggested fix: Reword to "logs one warning at process start if `PE_TOOLS_USERS` is unset or empty, and answers 403 for every `scope=tools` request" and name the logger (stdout? structured?).
- Confidence: low

### [NIT] AC-04 of US-TH-02 says "a cookie from a non-allowlisted account returns 403" but does not say how the cookie is obtained

- What: The smoke test requires a cookie from a non-allowlisted account, but the spec does not say where that account comes from.
- Where: US-TH-02 AC-04: "a cookie from a non-allowlisted account returns 403".
- Why it matters: The operator may not have a second PosterBuilder account. The smoke test as written is not runnable without one.
- Suggested fix: Either specify a test account (and how it is provisioned), or reword to "a cookie from an account not in `PE_TOOLS_USERS` (obtained by temporarily removing the operator's email from the list, then restoring it)".
- Confidence: medium

### [NIT] Entity model for extension registry says "field order `href, name, icon, subtitle` is preserved" but the fields list includes `category` after `subtitle`

- What: The serialization note lists four fields in a specific order but the fields list has five.
- Where: US-TH-01 entity model: "Fields: `href`, `name`, `icon`, `subtitle`, `category`" vs "field order `href, name, icon, subtitle` is preserved".
- Why it matters: The regex-based link generator matches on `href:` and `name:`; if `category` is inserted between them, the regex may break. The spec should state the full order including `category`.
- Suggested fix: Change to "field order `href, name, icon, subtitle, category` is preserved".
- Confidence: high

### [NIT] AC-03 of US-TH-01 says `grep -L` returns all pages but `grep -L` returns files _without_ matches

- What: The AC says "contains no `bentopdf.com` URL (`grep -L` over `src/pages/x-*.html` returns all of them)".
- Where: US-TH-01 AC-03.
- Why it matters: `grep -L` lists files that do _not_ contain the pattern — which is exactly what the AC wants, so the command is correct, but the phrasing "returns all of them" is confusing because it sounds like `grep -L` returns matches. A reader may misread it as `grep -l`.
- Suggested fix: Reword to "`grep -L 'bentopdf.com' src/pages/x-*.html` lists every extension page (i.e. none contain the URL)".
- Confidence: high

### [NIT] US-TH-03 AC-02 says `deploy.sh` is "cloned from PosterEngine's" but does not name the source path

- What: The AC says the script is cloned from PosterEngine's deploy.sh, but the source path is not given.
- Where: US-TH-03 AC-02: "`deploy.sh` is cloned from PosterEngine's".
- Why it matters: The context layer found `~/projects/00_Governance/artefacts-site/deploy.sh` but not a PosterEngine one. The implementer will have to guess which `deploy.sh` to clone.
- Suggested fix: Name the source path explicitly, e.g. "cloned from `~/projects/.../poster_engine/deploy.sh`".
- Confidence: medium

### [NIT] Out-of-scope says "retiring the `it-tools` container (revisit once US-TH-06 covers what the operator actually uses)" but US-TH-06 is in scope

- What: The out-of-scope line defers retiring it-tools until US-TH-06 is done, but US-TH-06 is part of v1.
- Where: Out of scope: "retiring the `it-tools` container (revisit once US-TH-06 covers what the operator actually uses)".
- Why it matters: The parenthetical implies US-TH-06 is a future trigger, but it is in the same spec. The reader may think US-TH-06 is out of scope.
- Suggested fix: Reword to "retiring the `it-tools` container (revisit after v1 ships and US-TH-06 has been in use)".
- Confidence: medium

## Self-flagged uncertainty

- I could not verify whether `~/projects/15_SAAS/` exists at all — the context layer only checked the leaf path. If the parent exists, the CRITICAL finding about AC-01 is downgraded to IMPORTANT (missing bootstrap step rather than missing directory).
- I do not know the actual port PosterEngine listens on; the 9120 value is inferred from the spec's own text and may be correct. The IMPORTANT finding stands only if 9120 is wrong.
- I do not know whether PosterEngine and PosterBuilder are the same service. If they are, the naming inconsistency is a NIT, not an IMPORTANT.
- I could not verify BentoPDF's i18n init behavior or its Dockerfile's handling of `/` under `BASE_URL`. The two IMPORTANT findings about AC-08 and AC-04 of US-TH-01 are conditional on those behaviors.
- I did not check whether `heic2any`, `jszip`, `papaparse`, or SheetJS are already transitive dependencies of BentoPDF. If they are, the `package.json` finding is weaker.
- I did not verify the it-tools container's current commit or whether the operator has a pinned version in mind. The IMPORTANT finding about AC-02 of US-TH-06 assumes no pin exists.
- I did not verify whether the operator speaks German. The IMPORTANT finding about AC-07 assumes they may not.

### Codex findings

## Findings — CODEX

### [CRITICAL] Extension boundary excludes required deliverables

- What: The permitted file changes in US-TH-01 AC-01 conflict with files required elsewhere in the spec.
- Where: “only files under the extension namespace plus the three upstream files”; AC-06 requires `NOTICE.md`, AC-07 requires changes to `public/locales/{en,de}/tools.json`, and US-TH-03 requires `docker-compose.yml`.
- Why it matters: Implementing the required deliverables violates the bootstrap acceptance criterion, forcing a scope decision during implementation.
- Suggested fix: Define an explicit allowance for project infrastructure and attribution files, and enumerate permitted upstream integration changes, including locale files and the build-script hook required by AC-07.
- Confidence: high

### [IMPORTANT] NPM-to-container connectivity is assumed without evidence

- What: The proxy configuration assumes NPM can reach host loopback ports, but the bundle does not establish its network topology.
- Where: US-TH-02 AC-03 uses `http://127.0.0.1:9120` and `http://127.0.0.1:9103`; US-TH-03 AC-01 binds toolhub to `127.0.0.1:9103:8080`; P1 checks configuration ownership.
- Why it matters: If NPM runs in a separate container network namespace, its loopback addresses do not reach these host bindings, breaking both authentication and content delivery.
- Suggested fix: Extend P1 to record NPM’s network mode and demonstrate connectivity to both endpoints from NPM’s execution environment. Specify the resulting reachable upstream addresses while retaining private backend access.
- Confidence: medium

### [IMPORTANT] Empty allowlist has contradictory authentication responses

- What: Anonymous requests must return both 401 and 403 when the allowlist is empty.
- Where: US-TH-02 AC-01 requires “401 when there is no valid session”; AC-02 requires “403 for every `scope=tools` request” when the allowlist is unset or empty.
- Why it matters: Implementations can satisfy either criterion while violating the other, and choosing 403 prevents the specified anonymous login redirect.
- Suggested fix: Define evaluation order explicitly: invalid or absent session returns 401; a valid session with an empty allowlist or an unlisted email returns 403. Cover the empty-allowlist cases in endpoint tests.
- Confidence: high

### [IMPORTANT] Login redirect does not preserve query-bearing tool URLs

- What: Inserting the raw request URI into the `next` query parameter does not safely preserve an original URL containing multiple query parameters.
- Where: US-TH-02 AC-03 specifies `/login?next=$request_uri`; the platform exit requires returning “to the requested tool after login.”
- Why it matters: For `/tools/example.html?a=1&b=2`, the resulting login URL treats `b` as a login parameter rather than part of `next`, losing requested tool state.
- Suggested fix: Specify a redirect mechanism that percent-encodes the entire original relative URI as one `next` value, retains `_safe_next` validation, and tests a round trip containing multiple parameters and encoded characters.
- Confidence: high

### [IMPORTANT] Platform completion depends on a later epic’s image tool

- What: The platform epic cannot meet its acceptance criteria with the promised empty extension layer.
- Where: The platform epic delivers “an empty extension layer ready for additions,” but US-TH-01 AC-04 requires `/tools/x-image-resize.html`, and US-TH-02 AC-05 requires its file input; that tool is delivered by US-TH-04.
- Why it matters: The epic’s exit depends on implementation from the subsequent epic, making its completion boundary and validation order ambiguous.
- Suggested fix: Use a stock tool for platform routing and login tests, or explicitly include a minimal image-resize implementation in the platform epic and state the dependency.
- Confidence: high

### [IMPORTANT] Rollback rehearsal does not exercise the deployment health condition

- What: The proposed broken-page deployment can pass the health poll, and the spec does not define how the static site produces the intended 500 response.
- Where: US-TH-03 AC-02 polls only `/tools/`; AC-03 verifies rollback with “a deliberately broken build (a page that 500s).”
- Why it matters: A broken tool page can coexist with a healthy grid, so the rehearsal may never demonstrate failed-deployment detection. The injected failure itself is underspecified for a static nginx site.
- Suggested fix: Define a reproducible fault that fails the actual health probe, assert that deployment exits unsuccessfully, then run rollback and verify that the previous image and a representative tool asset are restored.
- Confidence: high

### [IMPORTANT] Availability monitor checks the login gate without checking toolhub

- What: An anonymous 302 can remain healthy while the toolhub container is unavailable.
- Where: US-TH-03 AC-05 says the monitor expects 302 because “the gate answers anonymous checks with a redirect.”
- Why it matters: Authentication can redirect before nginx contacts toolhub, leaving a backend outage undetected.
- Suggested fix: Keep the public redirect check and add a private backend availability check from a monitoring environment that can reach toolhub, verifying `/tools/` and a built asset. Do not expose an unauthenticated public bypass.
- Confidence: high

### [IMPORTANT] DOCX conversion depends on an unverified upstream capability

- What: The design commits to a bundled DOCX-to-HTML conversion path without identifying or verifying its supported API and runtime.
- Where: US-TH-05 AC-03 requires “the bundled LibreOffice WASM converter (DOCX to HTML),” and AC-04 requires it in canonical Vitest execution; context section 7 says file contents and external resources were not checked.
- Why it matters: If the bundled integration supports different output formats or requires browser facilities absent from the test runner, both implementation and acceptance testing need redesign.
- Suggested fix: Add a pre-implementation premise that pins the upstream revision, identifies the converter entry point, and demonstrates the table-and-list DOCX fixture converting to HTML in both the browser and the intended test environment.
- Confidence: medium

### [IMPORTANT] Upstream comparison target conflicts with release-tag maintenance

- What: The extension-only diff requirement uses a moving branch while the maintenance policy rebases onto release tags.
- Where: The repository description says “periodically rebased on upstream release tags”; US-TH-01 AC-01 checks `git diff upstream/main --stat`.
- Why it matters: Whenever `upstream/main` contains changes beyond the selected release, the diff includes upstream differences outside the allowed files, even when the fork follows the maintenance policy correctly.
- Suggested fix: Record the selected upstream release tag and commit, and evaluate the extension boundary against that pinned commit. Update the baseline deliberately during upstream upgrades.
- Confidence: high

**NIT:** (none)

## Self-flagged uncertainty

- NPM’s network mode and effective configuration are absent from the bundle. The loopback finding is conditional; host networking could make the specified addresses valid.
- The bundle contains neither the LibreOffice converter implementation nor the Vitest configuration. I cannot establish whether the required conversion and test execution already work; the finding requests evidence rather than asserting incompatibility.
- No repository files, external resources, or other reviewer findings were consulted for substantive review evidence.

## Triage — pre-panel round 1 (Claude, 2026-09-10)

Sources: advisory Codex verdict `.spec-review/140d9aa54.verdict` (A1–A14, PANEL-VERDICT 6.0), DeepSeek duo findings (D1–D24 in order above), Codex duo findings (C1–C9). Findings that say the same thing are ruled once. "Measured" means a fact checked against the repo or the VPS this session, not argued.

| #                     | Finding                                                                        | Ruling                                                                                                                                                                                 | Applied where                                                                                                                                           |
| --------------------- | ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1, C1, D12, D13, D17 | Allowed-diff list cannot hold NOTICE, locales, compose, package.json           | Valid                                                                                                                                                                                  | "Integration allowance" list in Solution; US-TH-01 AC-01 rewritten with `UPSTREAM_BASE` + boundary script                                               |
| A2, C9                | Baseline `upstream/main` vs release-tag rebase                                 | Valid                                                                                                                                                                                  | `UPSTREAM_BASE` pinned commit `597e36904e8c`; upgrades rebase onto release tags and bump the file                                                       |
| A3, C3, D19           | 401 vs 403 conflict on empty allowlist; 400 missing from model                 | Valid                                                                                                                                                                                  | US-TH-02 AC-01 precedence order; entity model includes 400; warning wording fixed                                                                       |
| A4, C4                | `$request_uri` breaks multi-param `next`                                       | Valid, resolved by decision                                                                                                                                                            | `next=$uri` path-only; tool pages hold no query state (assumed decision, listed at top); out of scope line added; smoke asserts the `?a=1&b=2` case     |
| A5, C2                | NPM loopback reachability unproven                                             | Measured: `npm` container `Networks: host`                                                                                                                                             | P1 records the mode and adds a `docker exec npm curl` preflight                                                                                         |
| A6, C5                | Platform epic depends on `x-image-resize`                                      | Valid                                                                                                                                                                                  | AC-04, AC-05, AC-06 and healthchecks use stock `merge-pdf.html`                                                                                         |
| A7, C6                | Rollback can lose last healthy image; first install; fault injection undefined | Valid                                                                                                                                                                                  | US-TH-03 AC-02/03: candidate → current → rollback promotion after probe only; first-install refusal; `rehearse-failure` builds with `BASE_URL=/broken/` |
| A8, C7, D16           | Health probe and 302 monitor blind to backend outage                           | Valid                                                                                                                                                                                  | Probe hits grid + tool page + manifest asset on the private port; two Kuma monitors (public 302, private 200)                                           |
| A9, C8, D8, D9        | LibreOffice runtime, isolation headers, "bundled" vs jsDelivr contradiction    | Measured: converter `@matbee/libreoffice-converter` loads from `BASE_URL/libreoffice-wasm/` (local); container nginx emits COOP `same-origin` + COEP `credentialless`; vitest is jsdom | P6 added; US-TH-02 AC-04 header pass-through; US-TH-05 AC-03/04 split jsdom vs Playwright; out-of-scope reworded to name the three jsDelivr modules     |
| A10                   | Sheet export rows and duplicate headers                                        | Valid                                                                                                                                                                                  | US-TH-05 AC-01                                                                                                                                          |
| A11                   | Image limits, cancel, progress measurability                                   | Valid                                                                                                                                                                                  | US-TH-04 AC-01/03                                                                                                                                       |
| A12, (D none)         | Untrusted content on the PosterBuilder origin                                  | Valid                                                                                                                                                                                  | Epic-level untrusted-content rules; adversarial fixtures in AC-05 of US-TH-05 and US-TH-06; `lint:security` in US-TH-01 AC-05                           |
| A13                   | Privacy promise untested                                                       | Valid                                                                                                                                                                                  | US-TH-04 AC-06 network assertion; permitted hosts in NOTICE                                                                                             |
| A14                   | AGPL source offer beyond "fork is public"                                      | Valid                                                                                                                                                                                  | US-TH-01 AC-06 footer links the exact build sha; LICENSE preserved                                                                                      |
| D1                    | Checkout path missing, no bootstrap step                                       | Valid (parent dir exists, measured: `15_SAAS` holds PosterEngine)                                                                                                                      | Bootstrap commands in US-TH-01 AC-01                                                                                                                    |
| D2                    | `/_tools_auth` location undefined                                              | Valid                                                                                                                                                                                  | Full snippet verbatim in US-TH-02 AC-03                                                                                                                 |
| D3                    | Port 9120 ungrounded                                                           | Measured: PosterEngine `docker-compose.yml` binds 9120                                                                                                                                 | Glossary + P5                                                                                                                                           |
| D4                    | PosterEngine vs PosterBuilder                                                  | Valid                                                                                                                                                                                  | Glossary paragraph                                                                                                                                      |
| D5, D17               | 10-line cap too tight; `main.ts` change unspecified                            | Valid                                                                                                                                                                                  | Cap 25 lines; `i18nKey` field + fallback described in AC-02                                                                                             |
| D6                    | `/` 404 unverified                                                             | Measured: Dockerfile copies dist to `html${BASE_URL%/}`, `location /` try_files → no root index                                                                                        | AC-04 accepts 403 or 404; P3 states the basis                                                                                                           |
| D7                    | Playwright infra unscoped                                                      | Valid                                                                                                                                                                                  | US-TH-02 AC-06: devDependency, `npm run test:e2e:live`, `.env` credential names, logged to `deploy/log.md`                                              |
| D10                   | it-tools commit unpinned                                                       | Valid                                                                                                                                                                                  | Pinned `d505845f918e` in Solution and US-TH-06 AC-02                                                                                                    |
| D11                   | Regex worker termination mechanism                                             | Valid                                                                                                                                                                                  | US-TH-06 AC-04 `Worker.terminate()`                                                                                                                     |
| D12                   | `heic2any` etc. not dependencies                                               | Ignored: measured, all four (`heic2any`, `jszip`, `papaparse`, `xlsx`) are upstream dependencies; only `turndown` and `@playwright/test` are new and go through the deps registry      | Allowance covers package.json additions                                                                                                                 |
| D14                   | German translation ownership                                                   | Valid                                                                                                                                                                                  | Assumed-decisions paragraph and AC-07: implementer writes, operator (native speaker) reviews                                                            |
| D15                   | `VITE_DEFAULT_LANGUAGE` override unverified                                    | Measured: `i18n.ts` checks URL, then stored/browser language, then env, then `en`                                                                                                      | AC-08 rewritten to the real precedence                                                                                                                  |
| D18                   | Warning destination                                                            | Valid                                                                                                                                                                                  | AC-02 names the structured logger and process start                                                                                                     |
| D20                   | Non-allowlisted cookie source                                                  | Valid                                                                                                                                                                                  | AC-05: endpoint tests + one live check on the test stack (9220)                                                                                         |
| D21                   | Entity field order omits `category`                                            | Valid                                                                                                                                                                                  | Order now lists all six fields                                                                                                                          |
| D22                   | `grep -L` wording                                                              | Valid                                                                                                                                                                                  | AC-03 reworded                                                                                                                                          |
| D23                   | `deploy.sh` source path                                                        | Valid                                                                                                                                                                                  | US-TH-03 AC-02 names `~/projects/15_SAAS/20_PosterEngine/deploy.sh`                                                                                     |
| D24                   | it-tools retirement wording                                                    | Valid                                                                                                                                                                                  | Out-of-scope reworded                                                                                                                                   |

## Duo review — post-panel round 2

_Generated by review-duo at 2026-09-10T19:02:50Z. Phase artifacts: `/Users/jcords-macmini/projects/00_Governance/docs/superpowers/specs/2026-09-10-toolhub-design-duo-20260910-210004`_
_Two independent reviewers, shared context. Claude triages per-comment. No LLM-driven synthesis._

### DeepSeek findings

## Findings — DEEPSEEK

### [CRITICAL] US-TH-02 AC-05 smoke test asserts a `Location` header that the snippet cannot produce

- What: The smoke test asserts `Location: /login?next=/tools/x.html`, but the nginx snippet's `@tools_login` block returns `302 /login?next=$uri` — and `$uri` for the request `https://poster.getaccess.cloud/tools/x.html?a=1&b=2` is `/tools/x.html`, so the assertion is consistent with the snippet. However, the same AC also asserts the anonymous check on `/tools/x.html?a=1&b=2` returns 302 with that Location, while AC-03's `error_page 401 = @tools_login` fires only when `auth_request` returns 401 — and the snippet's `auth_request` target is `http://127.0.0.1:9120/api/auth/verify?scope=tools`, which per US-TH-02 AC-01 returns **401** for "no valid session". So the chain is consistent. The real defect is different: `error_page 401 = @tools_login` uses `=` to substitute the response code, but the `@tools_login` block returns `302` — nginx will emit `302` with the `Location` header, which is what the smoke asserts. This is fine. **The actual break is that `proxy_pass http://127.0.0.1:9103/tools/;` inside `location /tools/` will double the prefix**: a request to `/tools/x.html` is proxied to `http://127.0.0.1:9103/tools//tools/x.html` (nginx appends the unmatched remainder after the location prefix to the proxy_pass URI). The correct form is `proxy_pass http://127.0.0.1:9103;` (no trailing path) or `proxy_pass http://127.0.0.1:9103/tools/;` with `location /tools/` and a rewrite — but as written, the trailing `/tools/` in `proxy_pass` combined with the matching `location /tools/` prefix produces a doubled path and every tool page 404s behind the gate.
- Where: US-TH-02 AC-03 snippet: `location /tools/ { ... proxy_pass http://127.0.0.1:9103/tools/; ... }`
- Why it matters: The gate will pass (auth_request succeeds) and then the proxied request will hit the container at `/tools//tools/x.html`, which the container's nginx will not resolve. Every authenticated request 404s. This is the single most likely failure mode of the whole platform epic and it is baked into the "single source of truth" snippet.
- Suggested fix: Change the snippet to `proxy_pass http://127.0.0.1:9103;` (nginx will forward the full original URI including `/tools/`), or keep the trailing path and drop the location prefix match by using `location = /tools/` plus a rewrite. Add a preflight `docker exec npm curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:9103/tools/merge-pdf.html` (already in P1) **and** a live authenticated `curl` in AC-05 that asserts 200 on `/tools/merge-pdf.html` through NPM, not just on the private port.
- Confidence: high

### [CRITICAL] US-TH-02 AC-01 evaluation order makes the empty-allowlist case unreachable for anonymous requests

- What: AC-01 says the order is: `scope` present but not `tools` → 400; no valid session → 401; `scope=tools` and (empty allowlist or email not in it) → 403. AC-02 says "when unset or empty … every `scope=tools` request with a valid session gets 403 (deny by default)". But AC-01's test list says "the empty-allowlist case with a valid session (403) and without one (401)". The two are consistent only if "no valid session → 401" is evaluated before the allowlist check — which AC-01's ordering does say. So the anonymous-with-empty-allowlist case returns 401, not 403. That is correct and consistent. **The defect is that AC-01's prose "`scope=tools` and (`PE_TOOLS_USERS` empty or session email not in it, case-insensitive) → 403" reads as if the allowlist check is a single branch that also covers the no-session case**, and a reader implementing from the prose alone will return 403 for anonymous requests when the allowlist is empty, breaking the login redirect. The test list disambiguates, but the prose does not.
- Where: US-TH-02 AC-01: "`scope=tools` and (`PE_TOOLS_USERS` empty or session email not in it, case-insensitive) → 403"
- Why it matters: The `/meeting` gate and the toolhub gate both depend on 401 → `@tools_login` redirect. If an implementer reads the prose literally and returns 403 for anonymous requests when the allowlist is empty, anonymous users get the "not allowlisted" page instead of the login page, and the platform epic's exit condition ("an anonymous request lands on the login page") fails.
- Suggested fix: Reword AC-01 to make the session check an explicit precondition of the allowlist branch: "no valid session → 401 (regardless of allowlist state); valid session and `scope=tools` and (allowlist empty or email not in it) → 403". The test list already encodes this; the prose should match.
- Confidence: high

### [IMPORTANT] US-TH-03 AC-02 health probe uses `dist/.vite/manifest.json` but the container does not serve `dist/`

- What: The probe curls "the first entry of `dist/.vite/manifest.json`" on `http://127.0.0.1:9103/...`, but the container's nginx serves `/usr/share/nginx/html/tools/` (per P3's reading of the Dockerfile), not the repo's `dist/` directory. The manifest is a build artifact on the build host, not a served path. The probe needs to read the manifest locally to _derive_ an asset URL, then curl that URL against the container.
- Where: US-TH-03 AC-02: "runs the health probe: `curl` on `http://127.0.0.1:9103/tools/`, `/tools/merge-pdf.html` and the first entry of `dist/.vite/manifest.json`"
- Why it matters: As written, the probe is ambiguous — it could be read as curling `http://127.0.0.1:9103/dist/.vite/manifest.json`, which will 404 and fail every deploy. The intent (derive an asset path from the manifest, then curl it) is correct but not stated.
- Suggested fix: Reword to: "reads the first entry's `file` field from `dist/.vite/manifest.json` on the build host, then curls `http://127.0.0.1:9103/tools/<that file>` and requires 200". Same fix applies to US-TH-02 AC-05's "first asset listed in `dist/.vite/manifest.json`".
- Confidence: high

### [IMPORTANT] US-TH-02 AC-05 smoke discriminator conflates "expired cookie" with "cookie for non-allowlisted account"

- What: The smoke script exits 2 when "the anonymous check passes but the authenticated one redirects", labelling that as `TOOLHUB_E2E_COOKIE expired`. But a cookie belonging to a valid session whose email is not in `PE_TOOLS_USERS` also produces a 302 (via `error_page 403 = @tools_forbidden`? No — `@tools_forbidden` returns 403, not 302). So a non-allowlisted cookie produces 403, not 302, and the discriminator is correct for that case. **The real gap is that a cookie for a valid session whose email was _removed_ from `PE_TOOLS_USERS` after the cookie was issued also produces 403, not 302** — so the discriminator is fine. The actual defect: the script cannot distinguish "cookie expired" from "PosterEngine is down and the auth_request 502s", because a 502 from `auth_request` is treated by nginx as a failure and the `error_page 401` does not fire — nginx returns 500. The smoke script's exit-2 branch is only triggered on 302, so a 500 from a dead PosterEngine falls through to exit 1 ("gate is wrong"), which is the wrong diagnosis and will page the operator for a backend outage.
- Where: US-TH-02 AC-05: "exiting 2 with `TOOLHUB_E2E_COOKIE expired — re-capture via the login page` when the anonymous check passes but the authenticated one redirects, and exiting 1 only when the gate itself is wrong"
- Why it matters: The smoke's whole purpose is to distinguish gate regressions from session expiry. A third failure mode (auth backend down → 500) is not covered, and the script will misclassify it as a gate regression.
- Suggested fix: Add a third branch: if the authenticated request returns 5xx, exit 3 with `PosterEngine auth backend unreachable — check poster-engine container`. Add a test that feeds the script a stubbed 500 and asserts exit 3.
- Confidence: medium

### [IMPORTANT] US-TH-03 AC-03 `rehearse-failure` builds with `BASE_URL=/broken/` but the probe URLs are hardcoded to `/tools/`

- What: The rehearsal builds a candidate with `BASE_URL=/broken/` "so the probe fails deterministically", but the probe in AC-02 curls `http://127.0.0.1:9103/tools/` and `/tools/merge-pdf.html`. With `BASE_URL=/broken/`, the container serves the grid at `/broken/`, and `/tools/` returns 403 or 404 — so the probe does fail. That part is consistent. **The defect is that the rehearsal does not exercise the _retagging_ logic**, because the candidate is built with a different `BASE_URL` than the one the compose file specifies. The compose file (AC-01) hardcodes `BASE_URL=/tools/` as a build arg; the rehearsal overrides it. If the compose file's build args are the source of truth, the rehearsal is testing a build that the compose file cannot produce, and the "candidate → current" promotion path is exercised against an image that would never be built by `prod` in normal operation.
- Where: US-TH-03 AC-03: "`rehearse-failure` deploys a candidate built with `BASE_URL=/broken/` so the probe fails deterministically"
- Why it matters: The rehearsal's value is proving that a _realistic_ failed deploy leaves `toolhub:current` serving. A `BASE_URL=/broken/` build is not realistic — it fails at the very first probe URL for a reason (wrong path) that no real deploy would hit. A more realistic fault (e.g. a broken `merge-pdf.html` that 500s, or a container that fails to start) would exercise the same retagging logic without the artificial path mismatch.
- Suggested fix: Either (a) keep `BASE_URL=/broken/` but document that the rehearsal proves only the retagging logic, not the probe's discrimination (the spec already says "proves failure DETECTION only"), or (b) switch to a fault that fails the probe for a reason closer to a real regression — e.g. build with `SIMPLE_MODE=false` (grid still serves, but the tool page's expected content differs) or inject a `Dockerfile` layer that removes `merge-pdf.html`. Option (b) is stronger.
- Confidence: medium

### [IMPORTANT] US-TH-04 AC-06 privacy assertion permits `cdn.jsdelivr.net` but US-TH-05 AC-03 requires a local LibreOffice converter

- What: AC-06 says "the recorded network requests are only GETs to the page origin or to `cdn.jsdelivr.net` (the upstream WASM CDN)". But US-TH-05 AC-03 requires the DOCX converter to load from `BASE_URL + 'libreoffice-wasm/'` (local, per P6), and US-TH-04 AC-02b requires `@jsquash/*` codec modules — which are npm packages bundled into the build, not fetched from jsDelivr. So the permitted-host list is both too narrow (it does not name the local `libreoffice-wasm/` path, though that is same-origin so it is covered by "page origin") and potentially too broad (it permits jsDelivr for tools that do not need it).
- Where: US-TH-04 AC-06: "only GETs to the page origin or to `cdn.jsdelivr.net`"
- Why it matters: The privacy assertion is the spec's headline promise ("nothing leaves the device"). If the assertion permits jsDelivr unconditionally, a future tool that fetches user data to jsDelivr would pass the test. The assertion should be per-tool: the image tools may hit jsDelivr for PyMuPDF/Ghostscript WASM (upstream), but the office tools should not hit jsDelivr at all (LibreOffice is local, SheetJS is bundled).
- Suggested fix: Split AC-06 into per-category assertions: image tools may hit `cdn.jsdelivr.net` (upstream WASM); office/data and text/dev tools must hit only the page origin. Add the exact jsDelivr module paths to `NOTICE.md` so the permitted set is enumerated, not a wildcard host.
- Confidence: medium

### [IMPORTANT] US-TH-05 AC-03 "images are dropped with a placeholder line" is untested

- What: AC-03 specifies that DOCX images are dropped with a placeholder line, but AC-04's test coverage (jsdom for SheetJS/CSV/HTML-to-Markdown, Playwright for DOCX-to-HTML) does not assert the placeholder behavior. The Playwright test asserts "the table and list survive in the Markdown" — nothing about images.
- Where: US-TH-05 AC-03: "images are dropped with a placeholder line"; AC-04: "asserts the table and list survive in the Markdown"
- Why it matters: The placeholder behavior is a user-visible contract (the user needs to know an image was dropped, not silently lost). Without a test, it will regress silently.
- Suggested fix: Add to AC-04's Playwright test: the DOCX fixture includes one image, and the assertion checks that the Markdown contains the placeholder line and no `![](...)` image syntax.
- Confidence: high

### [IMPORTANT] US-TH-06 AC-04 regex timeout test does not assert the worker is actually terminated

- What: AC-04 says "the Vitest case feeds a catastrophic-backtracking pattern and asserts the timeout branch fires and the worker handle is released". "Worker handle is released" is not a testable assertion in jsdom/Vitest — `Worker` is not implemented in jsdom, and the test would need a real browser (Playwright) or a mock. The spec does not say which.
- Where: US-TH-06 AC-04: "asserts the timeout branch fires and the worker handle is released"
- Why it matters: If the test runs under jsdom, `Worker` is undefined and the test cannot exercise the real termination path. If it runs under Playwright, the spec should say so (like US-TH-05 AC-04 does for the DOCX test). As written, the test is either untestable or will be mocked into meaninglessness.
- Suggested fix: Move the regex timeout test to the Playwright suite (`npm run test:e2e`) and assert that after the timeout, a subsequent regex evaluation on the same page starts a fresh worker (proving the old one was terminated). Or, if it stays in Vitest, mock `Worker` and assert `terminate()` was called — but then say so explicitly.
- Confidence: high

### [IMPORTANT] US-TH-07 AC-01 says "the site's response headers are unchanged from US-TH-02 AC-04" but P8 may force a header change

- What: AC-01 asserts headers are unchanged, but P8 says the multi-threaded ffmpeg build needs `SharedArrayBuffer`, which historically requires `Cross-Origin-Embedder-Policy: require-corp`. The operator ruling says "if the multi-threaded build conflicts, ship the single-threaded build and change no site headers" — so the header-unchanged assertion is conditional on P8 resolving to single-threaded. But AC-01 states it unconditionally.
- Where: US-TH-07 AC-01: "the site's response headers are unchanged from US-TH-02 AC-04 (asserted by re-running that AC's `curl -sI` check after this epic deploys)"
- Why it matters: If P8 resolves to multi-threaded and the operator later authorises a header change (the spec says a site-wide `require-corp` switch is "NOT authorised by this spec"), AC-01 will fail. The AC should be conditional on the P8 outcome.
- Suggested fix: Reword AC-01 to: "if P8 resolves to the single-threaded build, headers are unchanged from US-TH-02 AC-04; if P8 resolves to the multi-threaded build, the header change is recorded in `deploy/log.md` and the US-TH-02 AC-04 assertion is updated in the same commit". Or, simpler: state that AC-01's header assertion applies only to the single-threaded outcome, and that the multi-threaded outcome is out of scope for this spec (which the operator ruling already implies).
- Confidence: medium

### [IMPORTANT] US-TH-01 AC-01 boundary check does not cover `package-lock.json` additions

- What: AC-01 says `git diff $(cat UPSTREAM_BASE) --stat` lists "only files under the extension namespace …, the unrestricted root files, and the integration-allowance files within their stated limits". The integration allowance permits "additions to `dependencies`, `devDependencies` and `scripts` only" in `package.json` and `package-lock.json`. But `package-lock.json` diffs are notoriously noisy — adding one dependency can rewrite hundreds of lines (integrity hashes, transitive deps). A "within their stated limits" check on `package-lock.json` is not defined.
- Where: US-TH-01 AC-01 and the integration allowance: "`package.json` and `package-lock.json`: additions to `dependencies`, `devDependencies` and `scripts` only; no version change to an upstream dependency"
- Why it matters: The boundary script (`scripts/check-upstream-boundary.sh`) will either (a) not check `package-lock.json` at all, defeating the purpose, or (b) check it with a line-count limit that will fail on every legitimate dependency addition. Neither is specified.
- Suggested fix: Define the `package-lock.json` check precisely: "the diff must not modify any existing `packages["node_modules/<name>"].version` entry; new entries are permitted". Or exclude `package-lock.json` from the line-count check and rely on `npm ci` + a lockfile-diff tool.
- Confidence: high

### [IMPORTANT] US-TH-01 AC-06 footer links to `<fork URL>/tree/<VITE_BUILD_SHA>` but `VITE_BUILD_SHA` is a short SHA

- What: AC-06 says the footer reads "Source: <fork URL>/tree/<VITE_BUILD_SHA>", and AC-04's build command passes `VITE_BUILD_SHA=$(git rev-parse --short HEAD)`. A short SHA is not guaranteed unique and GitHub's `/tree/<short-sha>` redirect works only if the short SHA is unambiguous. More importantly, the AGPL source-offer obligation is to the _exact_ revision, and a short SHA is not a stable identifier.
- Where: US-TH-01 AC-04: `VITE_BUILD_SHA=$(git rev-parse --short HEAD)`; AC-06: "Source: <fork URL>/tree/<VITE_BUILD_SHA>"
- Why it matters: AGPL-3.0 §13 requires offering the Corresponding Source of the _exact_ version running. A short SHA that later becomes ambiguous (after more commits) breaks the link. This is a compliance issue, not a cosmetic one.
- Suggested fix: Use the full SHA: `VITE_BUILD_SHA=$(git rev-parse HEAD)`. The footer link is longer but unambiguous and permanent.
- Confidence: high

### [IMPORTANT] US-TH-02 AC-05 smoke asserts `Location: /login?next=/tools/x.html` but the snippet's `$uri` includes the query string in some nginx versions

- What: The snippet uses `return 302 /login?next=$uri;`. In nginx, `$uri` is the _normalised_ URI path without the query string — so for `/tools/x.html?a=1&b=2`, `$uri` is `/tools/x.html`. That is correct. But `$uri` is also _decoded_ and _normalised_ (e.g. `%20` becomes a space, `//` collapses). If a tool page URL ever contains an encoded character, the `next` value will be the decoded form, and `_safe_next` on the PosterEngine side may reject it (P4 says `_safe_next` rejects values containing `\` or `:`; a decoded space is fine, but a decoded `%3A` would become `:` and be rejected).
- Where: US-TH-02 AC-03: "`next` carries `$uri` (path only, already percent-encoded by nginx)"
- Why it matters: The claim "already percent-encoded by nginx" is wrong — `$uri` is _decoded_. If a tool page URL contains an encoded colon or backslash, the redirect will carry the decoded form and `_safe_next` will rewrite it to `/`, silently dropping the user's intended destination.
- Suggested fix: Use `$request_uri` (which preserves the raw, encoded form) and strip the query string with a `map`, or use `$uri` but document that tool page paths must not contain characters that decode to `:` or `\`. Given the spec's "tool pages carry no state in the query string" decision, the simplest fix is to state that tool page paths are ASCII-only and contain no `:` or `\`, and add a test that a path with `%3A` is handled correctly (either preserved or explicitly rejected).
- Confidence: medium

### [NIT] US-TH-01 AC-03 `grep -L 'bentopdf.com' src/pages/x-*.html` will also match `bentopdf.com` in comments or attribution

- What: The AC asserts no extension page contains `bentopdf.com`, but the fork's own `NOTICE.md` and possibly the footer may reference the upstream URL. If any extension page includes an attribution comment (which AGPL compliance might encourage), the grep fails.
- Where: US-TH-01 AC-03: "`grep -L 'bentopdf.com' src/pages/x-*.html` lists every extension page, meaning none contains that URL"
- Why it matters: The check is a proxy for "no upstream SEO/marketing chrome", but it also forbids legitimate attribution. The intent should be narrower.
- Suggested fix: Narrow the grep to the specific blocks the AC wants removed: `grep -L 'og:url\|twitter:card\|application/ld+json' src/pages/x-*.html`, or check for the absence of the SEO meta block specifically.
- Confidence: medium

### [NIT] US-TH-01 AC-08 says "a browser whose languages are all unsupported (Playwright locale `xx`) shows German" but `xx` is not a valid BCP-47 tag

- What: Playwright's `locale` option expects a valid locale string. `xx` is not a registered language subtag; Playwright may reject it or fall back to the default.
- Where: US-TH-01 AC-08: "a browser whose languages are all unsupported (Playwright locale `xx`) shows German"
- Why it matters: The test may not run as written, or may not exercise the intended "unsupported language" path.
- Suggested fix: Use a real but unsupported locale, e.g. `locale: 'fr-FR'` (French is not in the `en`/`de` set), or `locale: 'zh-CN'`. Both are valid and unsupported.
- Confidence: high

### [NIT] US-TH-02 AC-02 says "logs one warning through its existing structured logger at process start" but does not name the logger

- What: The AC says the warning goes through "its existing structured logger" but does not name it, so the implementer must guess which logger PosterEngine uses.
- Where: US-TH-02 AC-02: "the app logs one warning through its existing structured logger at process start"
- Why it matters: Minor — the implementer will find the logger by reading the code — but the spec's own convention (naming files and functions precisely) suggests it should be named.
- Suggested fix: Name the logger (e.g. `poster_engine.log.get_logger(__name__)` or whatever the actual symbol is) or drop the phrase "structured logger" and say "logs one warning at process start".
- Confidence: low

### [NIT] US-TH-03 AC-05 Kuma monitor on `http://127.0.0.1:9103/tools/merge-pdf.html` may not be reachable from the Kuma container

- What: The AC acknowledges this ("if Kuma's container cannot reach host loopback, the monitor targets the Docker host-gateway address, established at implementation and recorded in `deploy/log.md`"), but "established at implementation" is a deferred decision, not an AC.
- Where: US-TH-03 AC-05: "if Kuma's container cannot reach host loopback, the monitor targets the Docker host-gateway address, established at implementation and recorded in `deploy/log.md`"
- Why it matters: The AC is not fully specified until implementation, which means the epic exit condition ("two Uptime Kuma monitors") cannot be verified at spec-review time.
- Suggested fix: Add a premise (P9) that resolves Kuma's network mode and the reachable address for `127.0.0.1:9103` before implementation, so AC-05 can name the exact URL.
- Confidence: medium

## Self-flagged uncertainty

- I could not verify the nginx `proxy_pass` trailing-slash behavior against the actual NPM config (the bundle does not include it). The CRITICAL finding about the doubled `/tools/` prefix is based on standard nginx semantics; if NPM's custom-location editor rewrites the snippet before applying it, the finding may not hold. **This is the finding I am least certain about and the one I would most want the other reviewer to confirm or refute.**
- I could not verify whether `$uri` in nginx is decoded or raw in the specific nginx version NPM ships. The IMPORTANT finding about `%3A` decoding is conditional on that.
- I could not verify whether `VITE_BUILD_SHA` is used anywhere else in the build (e.g. cache-busting) where a full SHA would break something. The AGPL compliance argument stands regardless.
- I did not verify whether the `@jsquash/*` packages are bundled or fetched at runtime. If they are fetched from jsDelivr, the privacy-assertion finding is weaker.
- I did not verify whether PosterEngine's structured logger has a name that the spec should cite. The NIT is low-confidence.
- I did not verify whether Playwright accepts `locale: 'xx'`. The NIT is based on BCP-47 conventions; Playwright may be permissive.
- I did not verify whether the `rehearse-failure` `BASE_URL=/broken/` build actually fails the probe as claimed — it depends on the container's nginx config, which the bundle does not include.

### Codex findings

## Findings — CODEX

### [CRITICAL] Deployment preflights conflict with both bootstrap and updates

- What: The unconditional preflights require toolhub’s port to be free while also requiring a reachable toolhub backend.
- Where: P1 probes `http://127.0.0.1:9103/tools/`; P2 requires “Port 9103 is free”; US-TH-03 AC-02 runs both before starting the candidate.
- Why it matters: On first installation, the backend does not exist for P1; on subsequent deployments, the healthy current container occupies the port required to be free by P2.
- Suggested fix: Define separate bootstrap and update preflights. Bootstrap checks that the port is free and checks NPM connectivity after candidate startup; updates verify that the expected current container owns the port and reject only unexpected listeners.
- Confidence: high

### [IMPORTANT] Health probes lack a defined, release-specific manifest source

- What: Deployment and rollback depend on a manifest whose generation, extraction and association with the probed image are unspecified.
- Where: US-TH-03 AC-02 excludes `dist` from rsync but probes “the first entry of `dist/.vite/manifest.json`”; AC-03 requires rollback to run “the same probe.”
- Why it matters: The specified Docker build does not establish a manifest available to the deployment script. A manifest from the candidate could also reference hashed assets absent from the rollback image, incorrectly rejecting a healthy rollback.
- Suggested fix: Require manifest generation and extraction from each built image, identify the asset URL using its `file` field and `/tools/` base, and probe each image using its own manifest.
- Confidence: high

### [IMPORTANT] Image promotion precedes a deployment check that can still fail

- What: The candidate becomes `current` before the required public header check establishes that the deployment passes.
- Where: US-TH-03 AC-02 retags after the private health probe; AC-03 checks headers “after every successful deploy” and “fails the deploy” when they differ.
- Why it matters: A deployment can return failure after replacing the image described as the last healthy release. The failure procedure that restarts `toolhub:current` then restarts the newly promoted candidate.
- Suggested fix: Keep the previous image identity until both private probes and authenticated public checks pass, and promote only afterward. Specify restoration on post-start failure and distinguish proxy configuration failures that restoring an image cannot repair.
- Confidence: high

### [IMPORTANT] The smoke discriminator cannot identify an expired cookie

- What: The specified discriminator classifies authentication regressions as expired credentials.
- Where: US-TH-02 AC-05 requires exit 2 when “the anonymous check passes but the authenticated one redirects,” reserving exit 1 for a broken gate.
- Why it matters: A proxy regression that stops forwarding session cookies produces exactly that combination, even with a valid cookie. The invalid-cookie test verifies one example but cannot establish the claimed distinction.
- Suggested fix: Validate the supplied cookie directly against PosterEngine’s verify endpoint. Classify direct 401 as invalid or expired credentials, direct 200 combined with a public redirect as a gate regression, and direct 403 separately as an authorization failure.
- Confidence: high

### [IMPORTANT] The extension boundary excludes its own mandatory checker

- What: A required implementation file falls outside the enumerated permitted changes.
- Where: US-TH-01 AC-01 requires `scripts/check-upstream-boundary.sh`; the integration allowance names `scripts/check-ext-i18n.mjs`, but does not allow the boundary checker or the entire `scripts/` directory.
- Why it matters: A literal implementation of the boundary policy rejects the checker itself.
- Suggested fix: Explicitly include `scripts/check-upstream-boundary.sh` in the permitted new files and require the completed bootstrap tree to pass that checker.
- Confidence: high

### [IMPORTANT] Header normalization can still produce duplicate JSON keys

- What: The spreadsheet export rules do not resolve collisions between generated header names and existing headers.
- Where: US-TH-05 AC-01 specifies duplicate suffixes `_2`, `_3` and empty-header names `col<N>`.
- Why it matters: Headers `a, a, a_2` can produce two `a_2` keys; an empty first header followed by `col1` can similarly collide. Object serialization can then silently lose cell values.
- Suggested fix: Define uniqueness across the entire normalized header set, including generated names, with a deterministic collision rule. Add fixtures for both examples and assert that every column’s value survives export.
- Confidence: high

### [IMPORTANT] The privacy assertion permits data-bearing GET requests

- What: Restricting request methods and hosts does not establish that processed content stays in the browser.
- Where: US-TH-04 AC-06 permits any GET to the page origin or `cdn.jsdelivr.net`, provided “no request carries a body.”
- Why it matters: File or text content placed in a URL query or path would satisfy this assertion while leaving the device, contradicting the central privacy promise.
- Suggested fix: Restrict processing-time requests to identified static asset URLs, including expected query parameters, and reject unexpected requests. Include identifiable fixture content and check that it never appears in outgoing URLs, headers or bodies.
- Confidence: high

### [IMPORTANT] The monitoring fallback does not reach a loopback-only service

- What: Changing Kuma’s target to the Docker host gateway does not address toolhub’s loopback-only port binding.
- Where: US-TH-03 AC-01 binds `127.0.0.1:9103:8080`; AC-05 substitutes “the Docker host-gateway address” when Kuma cannot reach host loopback.
- Why it matters: The fallback targets a different host interface from the one exposing port 9103, so the private monitor can remain unreachable despite a healthy backend.
- Suggested fix: Specify a monitoring path compatible with the private binding, such as a host-network probe or a shared private Docker network using toolhub’s container port. Verify it from Kuma’s actual execution environment.
- Confidence: high

### [IMPORTANT] Build revision and source-link propagation remain unverified

- What: The spec requires new build metadata without establishing that the unchanged upstream Dockerfile and footer support it.
- Where: US-TH-01 AC-04 passes `VITE_BUILD_SHA`; AC-06 requires `VITE_FOOTER_TEXT` to link to that revision; the integration allowance excludes `Dockerfile`, and US-TH-03 AC-01 does not specify the footer build argument.
- Why it matters: Passing a build argument alone does not establish that it reaches the frontend or is interpolated into the footer. The image could build successfully while displaying a missing or incorrect source revision.
- Suggested fix: Add a prerequisite verifying the Dockerfile argument propagation and footer rendering path. If support is absent, explicitly allow the necessary integration changes. Require a built-container check that the rendered source link names the deployed commit.
- Confidence: medium

**NIT:** (none)

## Self-flagged uncertainty

- The bundle omits Dockerfile, Vite configuration and footer implementation contents. I cannot establish whether manifest generation or build-metadata support already exists; the findings identify missing implementation contracts and evidence.
- Kuma’s network mode is absent. Its existing configuration might support the primary loopback target, but that would not validate the specified host-gateway fallback.
- Deployment script contents are not supplied. An existing script may offer useful mechanisms, but the specified deployment ordering and preflight requirements still need reconciliation.

## Triage — post-panel round 2 (Claude, 2026-09-10)

Sources: DeepSeek (D1–D17) and Codex (C1–C9) post-panel findings above. Where both reviewers reached the same finding independently, it is ruled once and the agreement is noted — independent convergence raised confidence and those were applied first.

| #                | Finding                                                                                                 | Ruling                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Applied where                  |
| ---------------- | ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------ |
| D1               | CRITICAL: `location /tools/` + `proxy_pass …/tools/` doubles the prefix, every page 404s                | **REFUTED BY MEASUREMENT.** Ran real nginx (`nginx:alpine`, two locations, echo upstream): `location /tools/` + `proxy_pass http://h/tools/` delivered `/tools/merge-pdf.html` — nginx replaces the matched prefix with the proxy_pass path, it does not append. The suggested "fix" (`proxy_pass` with no path) measurably forwards the ORIGINAL uri, so adopting it is what would break the gate. Reviewer self-flagged this as their least certain finding; they were right to. Snippet unchanged. | —                              |
| D2               | AC-01 prose reads as if the allowlist branch also covers the no-session case                            | Ruled NIT, not applied. The AC already states an ordered evaluation that stops at the first match, and lists the anonymous-empty-allowlist case as 401 in its own test list. Two explicit statements already disambiguate; a third would add words, not clarity.                                                                                                                                                                                                                                      | —                              |
| D3 + C2 (agree)  | Health probe reads `dist/.vite/manifest.json` but `dist` is excluded from the rsync                     | **Valid, and the sharpest finding of the round.** The probe pointed at a path that cannot exist on the VPS — every deploy would have failed on first run. Probe now derives the asset from the RUNNING IMAGE via `docker exec`, which also makes it release-specific.                                                                                                                                                                                                                                 | US-TH-03 AC-02, US-TH-02 AC-05 |
| D4 + C4 (agree)  | Smoke discriminator cannot see a dead auth backend (nginx returns 500, not 401, on a failed subrequest) | Valid. A backend outage would have been reported as a gate regression. Third branch added: exit 3 on any 5xx, with a stubbed-500 test. Also noted that exit 2 cannot separate "expired" from "revoked" and does not need to — same remedy.                                                                                                                                                                                                                                                            | US-TH-02 AC-05                 |
| D5               | `rehearse-failure` with `BASE_URL=/broken/` is an unrealistic fault                                     | Ruled acceptable as-is. The spec already states the rehearsal proves failure DETECTION only, and header integrity is separately asserted on every deploy. A "more realistic" fault buys nothing the two existing checks do not cover.                                                                                                                                                                                                                                                                 | —                              |
| D6 + C7 (agree)  | Privacy assertion permits `cdn.jsdelivr.net` as a host wildcard                                         | Valid, and it undercut the spec's headline promise: a wildcard would let a future tool exfiltrate to any jsDelivr path and still pass. Now per-category (office/text: same-origin only), path-enumerated in NOTICE, plus a long-GET ceiling and a negative control that proves the assertion can fail.                                                                                                                                                                                                | US-TH-04 AC-06                 |
| D7               | DOCX image placeholder specified but never asserted                                                     | Valid — silent data loss. Fixture gains an image; the test asserts the placeholder and the absence of image syntax.                                                                                                                                                                                                                                                                                                                                                                                   | US-TH-05 AC-04                 |
| D8               | Regex worker timeout untestable in jsdom (no `Worker`)                                                  | Valid and concrete. Moved to Playwright, asserting a later evaluation still works — which proves termination rather than mocking it.                                                                                                                                                                                                                                                                                                                                                                  | US-TH-06 AC-04                 |
| D9               | US-TH-07 AC-01 asserts unchanged headers unconditionally, but P8 may resolve either way                 | Valid. Resolved by making the multi-threaded outcome a STOP-and-ask, not a relaxation of the assertion — consistent with operator ruling Q164.                                                                                                                                                                                                                                                                                                                                                        | US-TH-07 AC-01                 |
| D10              | `package-lock.json` has no workable boundary rule                                                       | Valid. Line counting cannot work on a lockfile. Rule is now semantic: no existing version value may change, parsed as JSON against the base commit.                                                                                                                                                                                                                                                                                                                                                   | Integration allowance          |
| D11 + C9 (agree) | Short sha in the AGPL source-offer footer                                                               | Valid, a compliance issue rather than cosmetic. Full sha.                                                                                                                                                                                                                                                                                                                                                                                                                                             | US-TH-01 AC-04                 |
| C5               | The boundary checker is itself a new file in an upstream-owned directory its rules forbid               | Valid and neatly self-referential. Both checker scripts explicitly exempted.                                                                                                                                                                                                                                                                                                                                                                                                                          | Integration allowance          |
| C8 + D17 (agree) | Kuma monitor address deferred "at implementation" inside an AC                                          | Valid — an AC that cannot be verified at review time is not an AC. Promoted to premise P9.                                                                                                                                                                                                                                                                                                                                                                                                            | P9                             |
| D12              | `$uri` is decoded, so an encoded colon could reach `_safe_next` and be rewritten to `/`                 | Ruled theoretical here. Every tool path in this spec is `x-<slug>.html`, ASCII with no colon or backslash; the spec already fixes the page-name shape. Recorded as a constraint on future page names rather than new machinery.                                                                                                                                                                                                                                                                       | —                              |
| D13              | `grep -L 'bentopdf.com'` also forbids legitimate attribution                                            | Ruled NIT, not applied. Attribution belongs in NOTICE.md and the footer, neither of which is an extension page. The check as written matches its intent.                                                                                                                                                                                                                                                                                                                                              | —                              |
| D14              | Playwright locale `xx` may be rejected as invalid BCP-47                                                | Valid, trivial. Superseded: AC-08 already asserts the `/tools/de/` URL path and the stored-language route, which exercise the same precedence without depending on locale-tag validation.                                                                                                                                                                                                                                                                                                             | —                              |
| C1               | Deploy preflights conflict between bootstrap and update runs                                            | Ruled already handled: `prod` checks that 9103 is free OR held by the `toolhub` container, which is exactly the bootstrap-vs-update distinction.                                                                                                                                                                                                                                                                                                                                                      | —                              |
| C3               | Image promotion precedes a check that can still fail                                                    | Ruled already handled: retagging happens only after the probe passes, stated explicitly in AC-02.                                                                                                                                                                                                                                                                                                                                                                                                     | —                              |
| C6               | Header normalization can produce duplicate JSON keys                                                    | Ruled out of scope: refers to the sheet-export duplicate-header rule, which AC-01 already resolves with `_2`/`_3` suffixes and a fixture.                                                                                                                                                                                                                                                                                                                                                             | —                              |

Round outcome: 8 findings applied, 1 CRITICAL refuted by direct measurement, 8 ruled already-covered or NIT. The two independently-agreed findings (probe path, privacy wildcard) were the round's most valuable and both were real defects that would have surfaced only at first deploy.
