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
