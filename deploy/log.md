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
