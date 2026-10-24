#!/usr/bin/env bash
# Tests/journeys_wait/test_journeys_wait.sh: fixture tests for `decide` in
# scripts/journeys-wait, the hold behind journeys.yml's `Journeys wait` job.
# Cases: nothing alive goes; a queued ci.yml run holds; two older alive
# journeys runs hold and one lets through; a run pending on its concurrency
# group, a completed run, and a newer run of another scope or branch don't
# count; a newer alive run of the same branch and scope supersedes this one
# (and wins over a hold); the slot count follows JOURNEYS_SLOTS. No network;
# needs bash and jq.
#
# Run: bash Tests/journeys_wait/test_journeys_wait.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../scripts/journeys-wait
source "$here/../../scripts/journeys-wait"
fail=0

# run <id> <status> [<scope>] [<branch>]: one journeys run as the API lists it
run() { printf '{"id":%s,"status":"%s","head_branch":"%s","display_title":"after CI run 1: journeys %s at abc"}' "$1" "$2" "${4:-dev}" "${3:-flare}"; }
# check <name> <want> <own id> <ci queued> <runs...>: decide on run 50, scope flare, branch dev
check() {
  local name=$1 want=$2 ci=$3; shift 3
  local runs got
  runs=$(printf '%s\n' "$@" | jq -s .)
  got=$(decide 50 dev flare "$runs" "$ci")
  if [[ "$got" == "$want" ]]; then echo "ok   $name"; else echo "FAIL $name: want '$want', got '$got'"; fail=1; fi
}

check "nothing else alive goes" go 0 "$(run 50 in_progress)"
check "a queued ci.yml run holds" "hold 1 ci.yml run(s) queued for a macOS runner" 1 "$(run 50 in_progress)"
check "one older alive run lets through" go 0 "$(run 10 in_progress)" "$(run 50 in_progress)"
check "two older alive runs hold" "hold 2 older journeys run(s) alive (slots: 2)" 0 \
  "$(run 10 in_progress photo)" "$(run 20 queued design)" "$(run 50 in_progress)"
check "an older pending run holds no runner" go 0 "$(run 10 in_progress photo)" "$(run 20 pending design)" "$(run 50 in_progress)"
check "a completed older run doesn't count" go 0 "$(run 10 completed photo)" "$(run 20 in_progress design)" "$(run 50 in_progress)"
check "newer runs of other scopes don't count" go 0 "$(run 60 in_progress photo)" "$(run 70 queued full)" "$(run 50 in_progress)"
check "a newer run of this scope on a branch doesn't count" go 0 "$(run 60 pending flare fix/x)" "$(run 50 in_progress)"
check "a newer pending run of this scope supersedes" "superseded 60" 0 "$(run 60 pending)" "$(run 50 in_progress)"
check "superseded wins over a hold, newest named" "superseded 70" 1 \
  "$(run 10 in_progress photo)" "$(run 20 in_progress design)" "$(run 60 queued)" "$(run 70 in_progress)" "$(run 50 in_progress)"
check "a completed newer run of this scope doesn't supersede" go 0 "$(run 60 completed)" "$(run 50 in_progress)"
JOURNEYS_SLOTS=3 check "the slot count follows JOURNEYS_SLOTS" go 0 \
  "$(run 10 in_progress photo)" "$(run 20 queued design)" "$(run 50 in_progress)"

exit $fail
