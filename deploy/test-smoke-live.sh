#!/usr/bin/env bash
# Tests for deploy/smoke-live.sh (US-TH-02 AC-05): every exit-code branch is forced through
# deploy/smoke-stub.py so the discriminator cannot rot silently. Run: bash deploy/test-smoke-live.sh
set -uo pipefail
cd "$(dirname "$0")/.."

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("",0));print(s.getsockname()[1])'; }

fail=0
run_case() {  # <stub mode> <expected exit> <expected stdout substring>
  local mode=$1 want=$2 msg=$3 port pid out rc
  port=$(free_port)
  STUB_MODE="$mode" python3 deploy/smoke-stub.py "$port" &
  pid=$!
  for _ in $(seq 1 50); do
    curl -s -o /dev/null "http://127.0.0.1:$port/" 2>/dev/null && break
    sleep 0.1
  done
  out=$(TOOLHUB_SMOKE_BASE="http://127.0.0.1:$port" TOOLHUB_E2E_COOKIE=good bash deploy/smoke-live.sh 2>&1)
  rc=$?
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  if [ "$rc" = "$want" ] && [[ "$out" == *"$msg"* ]]; then
    echo "PASS $mode (exit $rc)"
  else
    echo "FAIL $mode: exit $rc (want $want), output: $out"
    fail=1
  fi
}

run_case ok            0 "smoke ok"
run_case badcookie     2 "TOOLHUB_E2E_COOKIE expired or revoked"
run_case backend-down  3 "PosterEngine auth backend unreachable"
run_case exposed       1 "gate wrong"
run_case forbidden     1 "gate wrong"

[ "$fail" -eq 0 ] && echo "smoke-live tests: 5 passed"
exit "$fail"
