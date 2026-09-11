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
