#!/usr/bin/env bash
# toolhub live smoke (US-TH-02 AC-05). Exit 0 ok · 1 gate wrong (site exposed or allowlisted cookie 403)
# · 2 cookie expired/revoked · 3 auth backend unreachable (nginx returns 5xx when the auth_request subrequest fails).
set -uo pipefail
BASE="${TOOLHUB_SMOKE_BASE:-https://poster.getaccess.cloud}"
ASSET="${1:-}"                      # hashed asset path derived by deploy.sh from the running image, e.g. assets/main-abc123.js
[ -f .env ] && TOOLHUB_E2E_COOKIE="${TOOLHUB_E2E_COOKIE:-$(grep -E '^TOOLHUB_E2E_COOKIE=' .env | cut -d= -f2-)}"
: "${TOOLHUB_E2E_COOKIE:?TOOLHUB_E2E_COOKIE missing (.env)}"
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
loc()  { curl -sI "$@" | awk 'tolower($1)=="location:"{print $2}' | tr -d '\r'; }
# nginx's `return 302 /login?next=$uri` is sent as an ABSOLUTE URL (scheme + server_name +
# the relative target), so the live gate answers `https://host/login?next=…` while a naive
# stub answers `/login?next=…`. Measured against the live gate 2026-09-11 on the first real
# deploy: comparing against the relative form alone failed a correct gate. Strip an optional
# scheme+host prefix so both forms compare equal, and keep the path comparison exact —
# the `?a=1&b=2` in the probe URL must NOT survive into `next=`.
strip_origin() { case "$1" in http://*|https://*) printf '%s' "/${1#*://*/}" ;; *) printf '%s' "$1" ;; esac; }

anon=$(code "$BASE/tools/x.html?a=1&b=2")
[ "$anon" -ge 500 ] && { echo "exit 3: PosterEngine auth backend unreachable — check the poster-engine container (anonymous $anon)"; exit 3; }
anon_loc=$(strip_origin "$(loc "$BASE/tools/x.html?a=1&b=2")")
if [ "$anon" != "302" ] || [ "$anon_loc" != "/login?next=/tools/x.html" ]; then
  echo "exit 1: gate wrong — anonymous request did not redirect to /login?next=/tools/x.html (got $anon, Location '$anon_loc')"; exit 1; fi

auth=$(code -b "session_token=$TOOLHUB_E2E_COOKIE" "$BASE/tools/")
case "$auth" in
  5*) echo "exit 3: PosterEngine auth backend unreachable — check the poster-engine container (authenticated $auth)"; exit 3 ;;
  302) echo "exit 2: TOOLHUB_E2E_COOKIE expired or revoked — re-capture via the login page"; exit 2 ;;
  403) echo "exit 1: gate wrong — allowlisted cookie got 403"; exit 1 ;;
  200) ;;
  *) echo "exit 1: gate wrong — authenticated /tools/ returned $auth"; exit 1 ;;
esac
if [ -n "$ASSET" ]; then
  a=$(code -b "session_token=$TOOLHUB_E2E_COOKIE" "$BASE/tools/$ASSET")
  [ "$a" = "200" ] || { echo "exit 1: hashed asset $ASSET returned $a"; exit 1; }
fi
echo "smoke ok: anonymous 302→/login?next=/tools/x.html, authenticated 200${ASSET:+, asset $ASSET 200}"
