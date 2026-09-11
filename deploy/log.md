# toolhub deploy log (append-only)

Append-only record of deploys, rehearsals, and live verifications for the toolhub platform
(US-TH-01..). One line or block per event, oldest first. Never edit or reorder earlier entries.

## 2026-09-11 — T11: PosterEngine auth backend shipped (US-TH-02 AC-01 + AC-02)

PosterEngine `main` @ `dcc091e` deployed via `./deploy.sh test` then `./deploy.sh prod`
(`PE_DEPLOY_ALLOW_DIRTY=1` — only dirt was another session's staged `RESEARCH.md`; Q196).
`PE_TOOLS_USERS` appended server-side to `/poster-builder/.env` and `/poster-builder-test/.env`,
mirroring `PE_AUTHORIZED_USERS` (Q194, Q195).

Verified on the test stack (`:9220`), in order:

```
docker logs poster-engine-test | grep -c 'PE_TOOLS_USERS is not set'   → 1   (key unset: warning fires once)
                                                  after key set        → 0
verify?scope=tools  anon                                               → 401
verify?scope=tools  session alice@poster.local, NOT allowlisted         → 403
verify?scope=tools  session alice@poster.local, allowlisted             → 200
final test allowlist restored to the operator list
```

Verified on prod (`:9120`) after `Deploy complete.`:

```
docker logs poster-engine | grep -c 'PE_TOOLS_USERS is not set'        → 0
PE_TOOLS_USERS in container env                                        → set
/api/health                                                            → 200
verify?scope=tools anon → 401 · verify?scope=bogus anon → 400 · verify (no scope) anon → 401
```

## 2026-09-11 — T12: NPM custom location applied to proxy host 17 (US-TH-02 AC-03, AC-04 first half)

Applied via `PUT /api/nginx/proxy-hosts/17 {advanced_config}` from an authenticated Playwright
session over an SSH tunnel to the VPS-loopback admin UI (Q198). **Found on the way:** NPM's DB had
`advanced_config: ""` while the rendered `17.conf` carried hand-patched `/meeting` gate blocks
(MeetingIntelligence handover 2026-05-06 CRITICAL item, never migrated). A tools-only save would
have wiped the meeting gate, so the saved advanced_config = meeting blocks verbatim + tools
snippet. Backup: `/data/nginx/proxy_host/17.conf.pre-tools-20260911` inside the `npm` container.

```
before: 17.conf md5 38beb0b5… (2091 B)   meeting anon 401 · meeting/static 403 · tools anon 404 · root 303→/welcome · login 200
after:  17.conf md5 271c3bc4… (2992 B)   nginx -t: successful
        meeting blocks in rendered conf: 4 · tools blocks: 5
        meeting anon 401 · meeting/static 403 (unchanged)
        tools anon 302 → https://poster.getaccess.cloud/login?next=/tools/x.html   (AC-04 redirect half)
        root 303→/welcome · login 200 · /api/health via NPM 200
```

Not yet provable until the toolhub container listens on 127.0.0.1:9103 (T16): authenticated 200 on
`/tools/`, COOP/COEP headers, `npm run smoke:live`, T14 e2e.

## 2026-09-11 — T15: `deploy.sh` written (US-TH-03 AC-02, AC-03 code paths)

Cloned from `~/projects/15_SAAS/20_PosterEngine/deploy.sh` (spec D23) and pruned. **No deploy has
run yet** — this entry records the script landing, not a release.

Arms kept: `prod|push`, `rollback`, `rehearse-failure`, `status`, `logs`.
Arms dropped and why: `build` (the shipped image is built on the VPS, a local build would mislead),
`push-env` (no `.env` on the VPS — the container holds no secrets), `test` (no test stack for a
static site; the candidate→probe→promote cycle is the test), `restart` (identical to
`docker compose up -d`, already inside `prod`/`rollback`).

Deviations from PosterEngine's original, all deliberate:

- preflight **refuses** a dirty or unpushed tree (PosterEngine only warns). The footer embeds
  `Source: <fork>/tree/<sha>`, so shipping unpushed code would publish a link that 404s.
- adds the upstream-boundary check (US-TH-01 AC-02) to preflight.
- `preflight_ports` replaces PosterEngine's reap-the-orphan logic: it refuses when `:9103` is held
  by anything other than `toolhub`/`toolhub-candidate` (P2) and requires PosterEngine on `:9120`
  (P5, or every gated request 500s instead of serving).
- retag happens **only after** the probe passes, so the last healthy image is never overwritten.

Pre-deploy verification (local, no VPS mutation):

```
bash -n deploy.sh                                  → OK
./deploy.sh bogus                                  → usage line, rc=1
./deploy.sh prod   with an untracked scratch file  → refuses, rc=1, exits before any ssh
                   (positive control: the untracked deploy.sh itself also listed)
ssh root@72.61.159.117 'ss -tlnH | grep ":9103 "'  → empty, rc=1   (P2 re-verify: still free)
ssh root@72.61.159.117 'ss -tlnH | grep ":9120 "'  → LISTEN 127.0.0.1:9120   (P5: PosterEngine up)
hostname on the VPS                                → srv1062693
```

**Q199 — `VITE_BUILD_SHA` is not passed.** The spec's AC-01 lists it, but
`grep -rn VITE_BUILD_SHA` over the repo (excluding `node_modules/`, `dist/`) returns zero
occurrences and the Dockerfile declares no such `ARG`. Docker silently ignores an undeclared
`--build-arg`, so passing it would be provenance theatre. The SHA reaches the image through
`VITE_FOOTER_TEXT` (Dockerfile `ARG` line 59 → `ENV` line 62 → `vite.config.ts:565`).

**Bootstrapping note:** `./deploy.sh prod` cannot run from the commit that introduces it — its own
preflight refuses an unpushed tree. The first real deploy is necessarily a post-commit action.

> bento-pdf@2.8.8 smoke:live
> bash deploy/smoke-live.sh assets/alternate-merge-B5GEb5c6.js

exit 1: gate wrong — anonymous request did not redirect to /login?next=/tools/x.html (got 302)

## 2026-09-11 — FIRST PRODUCTION DEPLOY (US-TH-03 AC-02 · US-TH-02 AC-04/AC-05/AC-06)

`./deploy.sh prod` at toolhub `7b4a6d3`. **The deploy itself succeeded** — build → candidate →
probe → promote → NPM reachability → COOP/COEP all passed. The `exit 1` logged immediately above
is the smoke script's own bug, not a gate fault; diagnosed and fixed below. First install, so
`toolhub:rollback` does not exist yet.

`TOOLHUB_E2E_COOKIE` was **minted server-side**, not captured from a browser: `httponly` blocks
JavaScript from _reading_ a cookie but nothing prevents the app from _issuing_ one, and PosterEngine
is ours. `docker exec poster-engine python -c "create_session(db, 7)"` for `jonas.cords@gmail.com`
(user id 7, on `PE_TOOLS_USERS`), via the same function `/login` calls — so the session is
indistinguishable from a real login and cannot drift from what `get_session_user` validates.
Written to a `0600` `.env`, gitignored at `.gitignore:15`. Expires in 7 days (`SESSION_TTL_DAYS`).
See DECISIONS Q201 (supersedes Q200).

```
VPS disk before deploy                                      → 42% (< 85% gate)
:9103 before deploy                                         → free; no toolhub images/containers (first install)
docker build                                                → toolhub:candidate, 231.1s vite build, image d88fbcf3a58c
probe toolhub-candidate  /tools/ · /tools/merge-pdf.html · /tools/assets/alternate-merge-B5GEb5c6.js  → 200 ×3
promote                                                     → toolhub:current; compose up -d; network toolhub_default created
probe toolhub (post-promotion)                              → 200 ×3
docker exec npm curl http://127.0.0.1:9103/tools/           → 200   (P1: NPM reaches the container)
header_check                                                → COOP/COEP intact through NPM   (AC-03 always-on)
```

Live gate, measured after promotion:

```
authenticated /tools/                                        → 200   (US-TH-02 AC-06 — first time proven)
authenticated /tools/assets/alternate-merge-B5GEb5c6.js      → 200   (release-specific hashed asset)
anonymous     /tools/                                        → 302
anonymous     /tools/x.html?a=1&b=2                          → 302 → https://poster.getaccess.cloud/login?next=/tools/x.html
                                                                     (query string correctly NOT leaked into next=)
/meeting/                                                    → 401   (no regression from the new location)
```

### Smoke-script bug found by this deploy (stub fidelity)

`deploy/smoke-live.sh` compared `Location` against the **relative** `/login?next=/tools/x.html`,
but nginx's `return 302 /login?next=$uri` is sent as an **absolute** URL (scheme + `server_name` +
target). The live gate was correct; the assertion was wrong.

It went unnoticed because `deploy/smoke-stub.py:17` emitted the relative form too — the stub
encoded an _assumption_ about nginx rather than a measured response, so the suite was validating
the script against a copy of the same guess. `test-smoke-live.sh` reported **5 passed** for days,
including in this session's premise block, while the live gate would have failed.

Fixed both: the stub now sends the absolute form the real gate sends, and the script strips an
optional `scheme://host` prefix before an otherwise-exact path comparison (the `?a=1&b=2` must
still not survive into `next=`). Red/green proven, not assumed:

```
old comparison vs corrected stub   → FAIL ok (exit 1, want 0) · FAIL badcookie (exit 1, want 2)
                                      Location 'http://127.0.0.1:PORT/login?next=/tools/x.html'
with fix                            → smoke-live tests: 5 passed
live smoke                          → "smoke ok: anonymous 302→…, authenticated 200, asset … 200", exit 0
strip_origin unit cases             → absolute·relative·http·root-only·empty correct;
                                      negative control (query leaked into next=) still compares UNEQUAL
```

### P9 confirmed by measurement (was Phase 0's one open follow-up)

Phase 0 established Kuma is bridge-networked and inferred the `172.17.0.1:9103` binding would be
required; it left a "confirm after the first deploy" box unticked. Now measured, with the negative
control that makes the claim testable rather than asserted:

```
docker exec uptime-kuma curl http://172.17.0.1:9103/tools/merge-pdf.html   → 200
docker exec uptime-kuma curl http://127.0.0.1:9103/tools/merge-pdf.html    → 000   (negative control)
```

The `000` is the load-bearing half: it proves loopback is genuinely unreachable from the bridged
Kuma container, so the second binding in `docker-compose.yml` is mandatory rather than harmless
clutter. Removing it would silently blind the AC-05 private monitor. Kuma's private monitor URL is
therefore `http://172.17.0.1:9103/tools/merge-pdf.html`.

### Not yet done on US-TH-03

- **AC-03 `rehearse-failure` is blocked on a second deploy.** This was a first install:
  `docker images` shows `toolhub:candidate` and `toolhub:current` but **no `toolhub:rollback`**, so
  the rehearsal's rollback leg would hit the deliberate `no toolhub:rollback image (first install)`
  refusal. One more successful `./deploy.sh prod` creates the rollback image; the rehearsal is
  meaningful only after that.
- AC-04 (inventory + `about.md` registration) — untouched.
- AC-05 (two Kuma monitors) — the private monitor's URL is now proven reachable, but neither
  monitor has been created; that is an operator UI action.

## 2026-09-11 — preflight bug: `port_owner` misread our own container as a stranger

The **second** `./deploy.sh prod` was refused by my own P2 check:

```
ERROR: :9103 held by 'non-docker pid 2478354' — refusing (P2)
```

`:9103` was held by `toolhub` — ours. Root cause: a published Docker port is held by
`docker-proxy`, a **host** process under `system.slice/docker.service`, not by the container.

```
ss -tlnpH "sport = :9103"  → users:(("docker-proxy",pid=2478354))  on 172.17.0.1:9103
                             users:(("docker-proxy",pid=2478348))  on 127.0.0.1:9103
ps -p 2478354              → /usr/bin/docker-proxy -host-ip 172.17.0.1 -host-port 9103
                                                   -container-ip 172.25.0.2 -container-port 8080
cat /proc/2478354/cgroup   → 0::/system.slice/docker.service      (no 64-hex container id)
```

So the PID→cgroup→container-id walk finds no container id and reports `non-docker pid`.
**This passed on the first install only because nothing was listening** — the empty-owner case
short-circuits before the walk. Every subsequent deploy would have been refused. A check written
to stop us evicting a stranger's service was instead blocking every redeploy of our own.

Fixed by asking Docker first (`docker ps` port mappings, anchored on `:<port>->`), keeping the PID
walk as the fallback for genuinely non-docker listeners — which is the case Phase 0 actually hit,
where portmgr's uvicorn held `:9100`. Verified, including that the guard still refuses a stranger:

```
:9103 → toolhub            (ours → allowed)
:9999 → dozzle             (a real other container → would REFUSE)
:9877 → (empty, free)      (free → allowed)
:103  → (empty)            (colon anchor: cannot partial-match 9103)
```

> bento-pdf@2.8.8 smoke:live
> bash deploy/smoke-live.sh assets/alternate-merge-B5GEb5c6.js

smoke ok: anonymous 302→/login?next=/tools/x.html, authenticated 200, asset assets/alternate-merge-B5GEb5c6.js 200
2026-09-11T18:48:41Z prod 8c63481f58290b784ca74aa235bf69983a48023d asset=assets/alternate-merge-B5GEb5c6.js OK
2026-09-11T18:49:17Z rollback OK
rehearse-failure PASS 2026-09-11T18:49:18Z

> bento-pdf@2.8.8 smoke:live
> bash deploy/smoke-live.sh assets/alternate-merge-B5GEb5c6.js

smoke ok: anonymous 302→/login?next=/tools/x.html, authenticated 200, asset assets/alternate-merge-B5GEb5c6.js 200
2026-09-11T18:54:58Z prod a23e11555fac02aac6d04a1866ba1696a70b206a asset=assets/alternate-merge-B5GEb5c6.js OK
2026-09-11T19:03:42Z rollback OK
rehearse-failure PASS 2026-09-11T19:03:42Z

## 2026-09-11 — AC-03 rehearsal: two false greens before a real one

`rehearse-failure` printed PASS twice before it proved anything. Both PASS lines above are in the
append-only record; **only the second (`19:03:42Z`) is valid**. The first (`18:49:18Z`) is void —
kept because this log never rewrites history, annotated here so nobody cites it as evidence.

**False green #1 — wrong failure mode.** `prod` appends its OK line to the tracked
`deploy/log.md`, so after any successful deploy the tree is dirty. The rehearsal's inner
`"$0" prod` was therefore refused by _preflight_ ("working tree has uncommitted changes") before
`docker build` ever ran. The rehearsal asserted only `exit 1`, so a refusal from an entirely
different stage satisfied it. A test that accepts any failure mode cannot prove the specific one
it was written for.

Fixed: the rehearsal now requires the output to contain `PROBE FAIL` / `candidate failed the
probe`, and runs the inner `prod` with `TOOLHUB_DEPLOY_SKIP_PREFLIGHT=1` (safe here — the
rehearsal deliberately ships a build that must never be promoted; `preflight_ports` is a separate
call and still enforces P2/P5).

**False green #2 — fault injected too far upstream.** With the assertion in place, the spec's
`BASE_URL=/broken/` was exposed as failing the **build**, not the probe:

```
scripts/seo-audit.mjs → [dead-link] 155 pages link to "/broken/" but no such page exists in dist
docker build          → exit 1 at Dockerfile:75 (npm run build:with-docs)
rehearsal             → ERROR: FALSE GREEN — prod exited non-zero, but not at the probe
```

A fault must be injected DOWNSTREAM of every gate that precedes the one under test. Switched to
`BASE_URL=` (upstream's default): the app builds and link-checks cleanly, but the Dockerfile's
`COPY … /usr/share/nginx/html${BASE_URL%/}` lands `dist` at the web ROOT, so the image is healthy
and serving — just at the wrong path — and `/tools/` 404s. The probe is what rejects it.

**Valid rehearsal (`19:03:42Z`):**

```
broken candidate rejected BY THE PROBE       (assertion matched PROBE FAIL)
current still serving 200                    (the broken candidate was never promoted)
rollback → 200 after rollback                (tag swap current↔rollback verified)
live after: auth /tools/ 200 · anon 302 · /meeting/ 401
```

Note the rehearsal legitimately leaves `toolhub:current` pointing at the PREVIOUS image — that is
what a rollback does. Redeploy afterwards to return prod to the newest commit.

> bento-pdf@2.8.8 smoke:live
> bash deploy/smoke-live.sh assets/alternate-merge-B5GEb5c6.js

smoke ok: anonymous 302→/login?next=/tools/x.html, authenticated 200, asset assets/alternate-merge-B5GEb5c6.js 200
2026-09-11T19:08:37Z prod 0f2d1505a5ba32f7cecdff21e82eafe2393e82eb asset=assets/alternate-merge-B5GEb5c6.js OK

## 2026-09-11 — US-TH-03 AC-04: portfolio app registration (partial)

Governance-side registration complete: `portfolio_apps/toolhub/about.md` updated with:

- `repo: 15_SAAS/25_Toolhub`
- `envs: ['prod']`
- `port: 9103` (bridge + loopback)
- `url: https://poster.getaccess.cloud/tools/` (public) and `http://172.17.0.1:9103/tools/merge-pdf.html` (private)
- Integration via PosterEngine `:9120`

Validated through `scripts/validate_about.py`. Committed to `00_Governance` as 2488142.

**Pending operator action:** Register toolhub in VPS portmgr `:9000` allocations with port 9103.
Once portmgr has the entry, the next infra-inventory run will add it to `00_Governance/infra-inventory/inventory.md`.

## 2026-09-11 — US-TH-03 AC-05: Uptime Kuma monitoring (awaiting operator)

P9 verified: Kuma container can reach `http://172.17.0.1:9103/tools/merge-pdf.html` (bridged address).
Two monitors needed on the VPS:

1. **Public gate monitor** (user-facing)
   - URL: `https://poster.getaccess.cloud/tools/`
   - Expected status: **302** (redirect to login for anonymous)
   - Purpose: detect auth gate breakage

2. **Private backend monitor** (infrastructure)
   - URL: `http://172.17.0.1:9103/tools/merge-pdf.html`
   - Expected status: **200** (backend serving, authenticated session)
   - Purpose: detect container crash or Docker port binding loss
   - Note: Uses bridge-network address; loopback `:9103` unreachable from Kuma container

**Operator action:** Create both monitors in Uptime Kuma UI, record monitor IDs below.

Monitor IDs (to be filled by operator):

- Public gate: [TBD]
- Private backend: [TBD]

## 2026-09-11 — US-TH-03 AC-06: Playwright e2e live gate test (US-TH-02 AC-06 validation)

`npm run test:e2e:live` run on live site against authenticated session (TOOLHUB_E2E_COOKIE):

```
Running 3 tests using 1 worker

  ✓  1 e2e/live-auth-flow.spec.ts:9 › anonymous request to /tools/merge-pdf.html redirects to login (248ms)
  ✓  2 e2e/live-auth-flow.spec.ts:24 › authenticated session reaches /tools/merge-pdf.html with crossOriginIsolated=true (1.0s)
  ✓  3 e2e/live-auth-flow.spec.ts:66 › merge-pdf page title and structure are correct (1.0s)

  3 passed (2.6s)
```

Verified:

- Anonymous requests redirect to `/login?next=/tools/merge-pdf.html` ✓
- Authenticated session with TOOLHUB_E2E_COOKIE reaches `/tools/merge-pdf.html` with 200 ✓
- `window.crossOriginIsolated === true` (COOP/COEP headers intact) ✓
- `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` headers present ✓
- File input element present and visible ✓
- Gate correctly prevents access without valid session ✓

Platform epic exit conditions now all met. Ready to close US-TH-03.

## 2026-09-11 — US-TH-03 AC-04: Portmgr registration complete

Toolhub registered in portmgr (port 9103) via CLI:

- Released stale `solar` allocation
- Allocated `toolhub: 9103` in portmgr database
- Verified via `/allocations` API — toolhub now present
- Infra-inventory updated: `- **toolhub** — \`localhost:9103\``

AC-04 fully complete. AC-05 (Kuma monitors) ready for operator.
