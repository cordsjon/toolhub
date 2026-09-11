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

anon=$(code "$BASE/tools/x.html?a=1&b=2")
[ "$anon" -ge 500 ] && { echo "exit 3: PosterEngine auth backend unreachable — check the poster-engine container (anonymous $anon)"; exit 3; }
if [ "$anon" != "302" ] || [ "$(loc "$BASE/tools/x.html?a=1&b=2")" != "/login?next=/tools/x.html" ]; then
  echo "exit 1: gate wrong — anonymous request did not redirect to /login?next=/tools/x.html (got $anon)"; exit 1; fi

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
