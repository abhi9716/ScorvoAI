#!/usr/bin/env bash
# ScorvoAI backend endpoint smoke test.
#
# Usage:
#   ./test_endpoints.sh                                              # tests local backend
#   ./test_endpoints.sh https://scorvoai-production.up.railway.app    # tests prod
#   URL=https://scorvoai-production.up.railway.app ./test_endpoints.sh
#
# Exits non-zero if any endpoint fails. Suitable for CI / pre-deploy gates.

set -uo pipefail

URL="${1:-${URL:-http://localhost:8000}}"
GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; BOLD='\033[1m'; RESET='\033[0m'

PASS=0
FAIL=0
TOTAL=0

run_test() {
  local name="$1"; local method="$2"; local path="$3"; local body="${4:-}"; local expect_code="${5:-200}"; local timeout="${6:-30}"
  TOTAL=$((TOTAL+1))
  printf "  ${BOLD}%-30s${RESET} " "$name"
  local args=(-s -m "$timeout" -o /tmp/resp.json -w "%{http_code}|%{time_total}")
  if [[ "$method" == "POST" ]]; then
    args+=(-X POST -H "Content-Type: application/json" -d "$body")
  fi
  local out; out=$(curl "${args[@]}" "$URL$path" 2>&1) || { printf "${RED}✗ network error${RESET}\n"; FAIL=$((FAIL+1)); return; }
  local code=${out%%|*}
  local time=${out##*|}
  if [[ "$code" == "$expect_code" ]]; then
    printf "${GREEN}✓${RESET} HTTP $code (${time}s)\n"
    PASS=$((PASS+1))
  else
    printf "${RED}✗${RESET} HTTP $code (expected $expect_code, ${time}s)\n"
    echo "      body: $(head -c 200 /tmp/resp.json)"
    FAIL=$((FAIL+1))
  fi
}

echo
echo "${BOLD}── ScorvoAI Endpoint Tests ──${RESET}"
echo "Target: $URL"
echo

echo "${BOLD}Health & Readiness${RESET}"
run_test "GET  /health"          GET  /health
run_test "GET  /ready"           GET  /ready

echo
echo "${BOLD}Legacy endpoints (no Ollama)${RESET}"
run_test "GET  /quiz/subjects"   GET  /quiz/subjects
run_test "GET  /daily"           GET  /daily
run_test "GET  /analyze"         GET  /analyze
run_test "GET  /analyze/stats"   GET  /analyze/stats

echo
echo "${BOLD}AI endpoints (Gemma 4 via Ollama Cloud)${RESET}"
run_test "POST /chat"            POST /chat            '{"question":"Reply with single word OK"}'                                                       200 60
run_test "POST /solve"           POST /solve           '{"question":"What is 5+5?"}'                                                                     200 60
run_test "POST /lessons"         POST /lessons         '{"subject":"Polity","chapter":"Fundamental Rights","difficulty":"medium"}'                       200 90
run_test "GET  /quiz?ai=true"    GET  '/quiz?count=2&ai=true&subjects=Quantitative%20Aptitude&difficulty=easy' '' 200 90
run_test "GET  /current-affairs" GET  '/current-affairs?count=3'                                                                                          '' 200 120

echo
echo "${BOLD}── Summary ──${RESET}"
if [[ $FAIL -eq 0 ]]; then
  echo "${GREEN}${BOLD}✓ All $TOTAL tests passed${RESET}"
  exit 0
else
  echo "${RED}${BOLD}✗ $FAIL of $TOTAL tests failed${RESET} (${GREEN}$PASS passed${RESET})"
  exit 1
fi
