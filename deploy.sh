#!/usr/bin/env bash
# Deploy toolhub to the VPS at /toolhub, served at https://poster.getaccess.cloud/tools/
# Usage: ./deploy.sh [prod|push|status|logs|rollback|rehearse-failure]
#
# Cloned from ~/projects/15_SAAS/20_PosterEngine/deploy.sh (US-TH-03 AC-02, spec D23).
# Deliberately DROPPED from the source: build|test|push-env|restart.
#   - no `.env` on the VPS: the container holds no secrets, so push-env has nothing to push
#   - no test stack for a static site; the candidate/probe/promote cycle below IS the test
#   - `build` is local-only and misleading here: the image that ships is built ON the VPS
#   - `restart` is `docker compose up -d`, already covered by prod/rollback
#
# Promotion model (AC-02): build as toolhub:candidate -> start it -> probe -> only then retag
# current->rollback and candidate->current. The last healthy image is never overwritten before
# the replacement has proven itself.

set -euo pipefail

VPS_HOST="root@72.61.159.117"
VPS_DIR="/toolhub"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=9103
FORK_URL="https://github.com/cordsjon/toolhub"
SITE_URL="https://poster.getaccess.cloud"

cmd="${1:-push}"

# ── Preflight ────────────────────────────────────────────────────────────────
# deploy rsyncs the TREE, not a git ref, so uncommitted or unpushed state ships
# silently. Unlike PosterEngine (which warns), AC-02 requires a REFUSAL here:
# the footer embeds the commit SHA as the source-attribution link, so a dirty
# tree would publish a footer pointing at code that does not exist on GitHub.
# TOOLHUB_DEPLOY_SKIP_PREFLIGHT=1 bypasses (emergency hotfix only).
preflight() {
  [ "${TOOLHUB_DEPLOY_SKIP_PREFLIGHT:-0}" = "1" ] && { echo "Preflight SKIPPED (TOOLHUB_DEPLOY_SKIP_PREFLIGHT=1)."; return 0; }

  echo "Preflight: checking working tree is clean and pushed..."
  if [ -n "$(git -C "$LOCAL_DIR" status --porcelain 2>/dev/null)" ]; then
    echo "ERROR: working tree has uncommitted changes — deploy ships the TREE, not a git ref,"
    echo "       and the footer would cite a SHA that is not on the fork remote."
    git -C "$LOCAL_DIR" status --short | sed 's/^/         /'
    exit 1
  fi
  local unpushed
  unpushed=$(git -C "$LOCAL_DIR" log --oneline '@{u}..HEAD' 2>/dev/null | wc -l | tr -d ' ')
  if [ "${unpushed:-0}" -gt 0 ]; then
    echo "ERROR: $unpushed local commit(s) not pushed to origin — the footer SHA link would 404."
    echo "       Push first: git push"
    exit 1
  fi

  echo "Preflight: upstream boundary..."
  if [ -x "$LOCAL_DIR/scripts/check-upstream-boundary.sh" ] || [ -f "$LOCAL_DIR/scripts/check-upstream-boundary.sh" ]; then
    bash "$LOCAL_DIR/scripts/check-upstream-boundary.sh" || { echo "ERROR: upstream boundary dirty — see US-TH-01 AC-02."; exit 1; }
  fi

  echo "Preflight: VPS disk (abort if > 85% full)..."
  local disk
  disk=$(ssh "$VPS_HOST" "df / | tail -1 | awk '{print \$5}' | tr -d '%'")
  echo "  VPS root disk usage: ${disk}%"
  [ "${disk:-0}" -gt 85 ] && { echo "ERROR: Disk ${disk}% > 85% — aborting."; exit 1; }

  echo "Preflight passed."
}

# Who holds :9103? Resolve the listening PID -> cgroup -> container name.
# `docker ps --filter publish=` does NOT match loopback-published ports (measured on
# PosterEngine's :9220 orphan), so the PID walk is the reliable path.
port_owner() {
  ssh "$VPS_HOST" '
    # Ask Docker FIRST. A published port is held by `docker-proxy`, a HOST process under
    # system.slice/docker.service — NOT by the container — so its cgroup carries no 64-hex
    # container id and a PID walk reports "non-docker pid". Measured 2026-09-11: the second
    # deploy was refused with "held by non-docker pid 2478354" while our own toolhub
    # container held the port. The PID walk only ever passed on a FIRST install, where the
    # empty-owner case short-circuits it. The port match is anchored on ":<port>->" so that
    # e.g. :103-> cannot match a 9103 mapping.
    name=$(docker ps --format "{{.Names}}\t{{.Ports}}" | awk -F"\t" "\$2 ~ /:'"$PORT"'->/ {print \$1}" | head -1)
    [ -n "$name" ] && { echo "$name"; exit 0; }
    # Not published by any container — fall back to the PID walk for genuinely non-docker
    # listeners (e.g. portmgr'"'"'s uvicorn, which is what held :9100 in Phase 0).
    pid=$(ss -tlnpH "sport = :'"$PORT"'" 2>/dev/null | grep -oE "pid=[0-9]+" | head -1 | cut -d= -f2); [ -z "$pid" ] && exit 0
    cid=$(grep -oE "[0-9a-f]{64}" /proc/$pid/cgroup 2>/dev/null | head -1); [ -z "$cid" ] && { echo "non-docker pid $pid"; exit 0; }
    docker ps --no-trunc --format "{{.ID}} {{.Names}}" | grep "^$cid" | awk "{print \$2}"'
}

# P5: PosterEngine must be up, or every gated request 500s instead of serving.
# P2: :9103 must be free or held by us — never evict a stranger's service.
preflight_ports() {
  ssh "$VPS_HOST" "ss -tlnp | grep -q ':9120 '" || { echo "ERROR: PosterEngine not listening on 127.0.0.1:9120 (P5)"; exit 1; }
  local owner; owner=$(port_owner)
  case "$owner" in
    ""|toolhub|toolhub-candidate) ;;
    *) echo "ERROR: :$PORT held by '$owner' — refusing (P2)"; exit 1 ;;
  esac
}

# The hashed asset is derived from the RUNNING image, never from the build host's dist/
# (dist is rsync-excluded, so no such directory exists on the VPS — a probe pointing there
# would 404 every time). Deriving per-release also means a stale asset path cannot pass.
derive_asset() {
  ssh "$VPS_HOST" "docker exec $1 cat /usr/share/nginx/html/tools/.vite/manifest.json" \
    | python3 -c 'import json,sys; m=json.load(sys.stdin); print(next(iter(m.values()))["file"])'
}

start_candidate() {
  ssh "$VPS_HOST" "docker rm -f toolhub-candidate >/dev/null 2>&1; docker stop toolhub >/dev/null 2>&1 || true; docker run -d --name toolhub-candidate -p 127.0.0.1:$PORT:8080 toolhub:candidate >/dev/null"
}

# $1 = container name. Each URL must return 200 within 120 s (60 tries x 2 s).
probe() {
  local asset; asset=$(derive_asset "$1") || { echo "PROBE FAIL: could not derive asset from $1"; return 1; }
  local path
  for path in /tools/ /tools/merge-pdf.html "/tools/$asset"; do
    ssh "$VPS_HOST" "for i in \$(seq 1 60); do [ \"\$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT$path)\" = 200 ] && exit 0; sleep 2; done; exit 1" \
      || { echo "PROBE FAIL: $path"; return 1; }
  done
}

fail_and_restore() {
  echo "ERROR: candidate failed the probe — last 50 log lines:"
  ssh "$VPS_HOST" "docker logs toolhub-candidate --tail 50; docker rm -f toolhub-candidate >/dev/null; cd $VPS_DIR && docker compose up -d"
}

# US-TH-03 AC-03, always-on: COOP/COEP must reach the browser unchanged through NPM.
# A proxy-config edit that silently strips them is caught at the deploy that introduces
# it, rather than at the next media-tool bug report (P8).
header_check() {
  local cookie h
  cookie=$(grep -E '^TOOLHUB_E2E_COOKIE=' "$LOCAL_DIR/.env" 2>/dev/null | cut -d= -f2-)
  if [ -z "$cookie" ]; then
    echo "ERROR: TOOLHUB_E2E_COOKIE missing from .env — cannot verify COOP/COEP through NPM (AC-03)."
    exit 1
  fi
  h=$(curl -sI -b "session_token=$cookie" "$SITE_URL/tools/merge-pdf.html")
  echo "$h" | grep -qi '^cross-origin-opener-policy: same-origin' \
    && echo "$h" | grep -qi '^cross-origin-embedder-policy: credentialless' \
    || { echo "ERROR: COOP/COEP missing or changed through NPM"; echo "$h" | sed 's/^/  /'; exit 1; }
  echo "  COOP/COEP intact through NPM."
}

case "$cmd" in
  prod | push)
    preflight
    preflight_ports
    sha=$(git -C "$LOCAL_DIR" rev-parse HEAD)

    echo "Syncing to $VPS_HOST:$VPS_DIR ..."
    ssh "$VPS_HOST" "mkdir -p $VPS_DIR"
    rsync -az --delete \
      --exclude='.git' --exclude='node_modules' --exclude='dist' --exclude='.env' --exclude='test-results' \
      "$LOCAL_DIR/" "$VPS_HOST:$VPS_DIR/"
    echo "Sync complete."

    echo "Building toolhub:candidate on the VPS ..."
    ssh "$VPS_HOST" "cd $VPS_DIR && docker build -t toolhub:candidate \
      --build-arg BASE_URL=/tools/ --build-arg SIMPLE_MODE=true --build-arg VITE_BRAND_NAME=toolhub \
      --build-arg VITE_DEFAULT_LANGUAGE=de --build-arg SITE_URL=$SITE_URL \
      --build-arg VITE_FOOTER_TEXT='Source: $FORK_URL/tree/$sha' ${TOOLHUB_EXTRA_BUILD_ARGS:-} ."
    # NOTE: the spec's AC-01 also lists VITE_BUILD_SHA, but the Dockerfile declares no such
    # ARG and nothing in the repo reads it (verified 2026-09-11: grep found zero occurrences
    # outside node_modules/dist). Docker silently ignores an undeclared --build-arg, so
    # passing it would be provenance theatre. The commit SHA genuinely reaches the image
    # through VITE_FOOTER_TEXT above (ARG line 59 -> ENV line 62 -> vite.config.ts:565).

    echo "Starting candidate and probing ..."
    start_candidate && probe toolhub-candidate || { fail_and_restore; exit 1; }

    echo "Probe passed — promoting candidate to current ..."
    ssh "$VPS_HOST" "docker rm -f toolhub-candidate >/dev/null; docker tag toolhub:current toolhub:rollback 2>/dev/null || true; docker tag toolhub:candidate toolhub:current; cd $VPS_DIR && docker compose up -d"
    probe toolhub || { echo "ERROR: promoted image failed its probe"; exit 1; }

    asset=$(derive_asset toolhub)
    echo "Verifying NPM can reach toolhub (P1) ..."
    ssh "$VPS_HOST" "docker exec npm curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT/tools/" \
      | grep -q '^200$' || { echo "ERROR: NPM cannot reach toolhub (P1)"; exit 1; }

    header_check
    npm run smoke:live -- "$asset" | tee -a deploy/log.md
    echo "$(date -u +%FT%TZ) prod $sha asset=$asset OK" >> deploy/log.md
    echo "Deploy complete."
    ;;

  rollback)
    ssh "$VPS_HOST" "docker image inspect toolhub:rollback >/dev/null 2>&1" \
      || { echo "ERROR: no toolhub:rollback image (first install)"; exit 1; }
    echo "Rolling back to toolhub:rollback ..."
    ssh "$VPS_HOST" "docker rm -f toolhub >/dev/null 2>&1 || true; docker tag toolhub:current toolhub:candidate-failed 2>/dev/null || true; docker tag toolhub:rollback toolhub:current; cd $VPS_DIR && docker compose up -d"
    probe toolhub || { echo "ERROR: rollback image failed its probe — service unstable."; exit 1; }
    # Swap the tags back: the image we just rolled away from becomes the rollback target.
    ssh "$VPS_HOST" "docker tag toolhub:candidate-failed toolhub:rollback 2>/dev/null || true"
    echo "$(date -u +%FT%TZ) rollback OK" >> deploy/log.md
    echo "Rollback complete."
    ;;

  rehearse-failure)
    # AC-03: prove the deploy DETECTS a broken build and that current keeps serving.
    # BASE_URL=/broken/ also moves .vite/manifest.json to /usr/share/nginx/html/broken/,
    # so derive_asset fails first — the rehearsal proves DETECTION only, not probe-URL
    # coverage (spec: accepted, triage D5). Run once; it is a platform-epic exit condition.
    echo "Rehearsing a failed deploy (BASE_URL=/broken/) ..."
    if ( export TOOLHUB_EXTRA_BUILD_ARGS="--build-arg BASE_URL=/broken/"; "$0" prod ); then
      echo "ERROR: rehearsal FAILED — a broken build was promoted (expected exit 1)."
      exit 1
    fi
    echo "  broken candidate was rejected, as expected."

    code=$(ssh "$VPS_HOST" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT/tools/merge-pdf.html")
    [ "$code" = "200" ] || { echo "ERROR: rehearsal — current is not serving after the rejected candidate (got $code)"; exit 1; }
    echo "  current still serving 200."

    "$0" rollback || { echo "ERROR: rehearsal — rollback exited non-zero."; exit 1; }
    code=$(ssh "$VPS_HOST" "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:$PORT/tools/merge-pdf.html")
    [ "$code" = "200" ] || { echo "ERROR: rehearsal — not serving 200 after rollback (got $code)"; exit 1; }
    echo "  200 after rollback."

    echo "rehearse-failure PASS $(date -u +%FT%TZ)" >> deploy/log.md
    echo "rehearse-failure PASS"
    ;;

  status)
    ssh "$VPS_HOST" "docker ps --filter name=toolhub --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
    echo -n "http://127.0.0.1:$PORT/tools/merge-pdf.html → "
    ssh "$VPS_HOST" "curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:$PORT/tools/merge-pdf.html"
    ;;

  logs)
    ssh "$VPS_HOST" "docker logs toolhub --tail 50"
    ;;

  *)
    echo "Usage: $0 [prod|push|status|logs|rollback|rehearse-failure]"
    exit 1
    ;;
esac
