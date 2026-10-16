#!/usr/bin/env bash
# Tests/test_died/test_test_died.sh: fixture test for scripts/test-died. A
# `swift test` log that stops mid-run must print TEST PROCESS DIED and exactly
# the tests that started and never finished, and exit 1. A finished test,
# failed or passed, a parameterized test's case lines, an issue a test
# recorded while running, and a colored line must not count. The same log
# with Swift Testing's summary line is a normal failure: no output, exit 0.
# Needs bash and python3.
#
# Run: bash Tests/test_died/test_test_died.sh   (exit 0 = all pass)
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

esc=$'\e'
cat >"$tmp/died.log" <<LOG
[1/1] Planning build
◇ Test run started.
◇ Suite PhotoExportTests started.
◇ Test aFinishedTest() started.
◇ Test aFailedTest() started.
✘ Test aFailedTest() recorded an issue at PhotoExportTests.swift:12:5: Expectation failed: 1 == 2
✘ Test aFailedTest() failed after 0.010 seconds with 1 issue.
◇ Test aParameterizedTest(scheme:) started.
◇ Test case passing 1 argument scheme → .light to aParameterizedTest(scheme:) started.
◇ Test case passing 1 argument scheme → .dark to aParameterizedTest(scheme:) started.
✔ Test aParameterizedTest(scheme:) with 2 test cases passed after 0.020 seconds.
◇ Test theHungTest() started.
${esc}[1m◇ Test aColoredUnfinishedTest(_:_:) started.${esc}[0m
◇ Test sameName() started.
◇ Test sameName() started.
✔ Test sameName() passed after 0.001 seconds.
✘ Test theHungTest() recorded an issue at HungTests.swift:3:1: Expectation failed
✔ Test aFinishedTest() passed after 0.030 seconds.
Test Case '-[AppAuditTests.Tally testCounts]' started.
Test Case '-[AppAuditTests.Tally testCounts]' passed (0.002 seconds).
Test Case '-[AppAuditTests.Tally testDies]' started.
✔ Suite PhotoExportTests passed after 0.100 seconds.
LOG

out=$(python3 "$root/scripts/test-died" "$tmp/died.log"); status=$?
check "a dead run exits 1" '[[ $status -eq 1 ]]'
check "it says TEST PROCESS DIED" '[[ "$out" == *"TEST PROCESS DIED"* ]]'
listed=$(printf '%s\n' "$out" | sed -n 's/^  //p')
want=$'theHungTest()\naColoredUnfinishedTest(_:_:)\nsameName()\n-[AppAuditTests.Tally testDies]'
check "it lists exactly the unfinished tests, in start order" '[[ "$listed" == "$want" ]]'
check "it counts them" '[[ "$out" == *"4 test(s) started and never finished"* ]]'

cp "$tmp/died.log" "$tmp/finished.log"
echo "✘ Test run with 7 tests in 1 suite failed after 0.200 seconds with 1 issue." >>"$tmp/finished.log"
out=$(python3 "$root/scripts/test-died" "$tmp/finished.log"); status=$?
check "a run with its summary exits 0" '[[ $status -eq 0 ]]'
check "and prints nothing" '[[ -z "$out" ]]'

python3 "$root/scripts/test-died" >/dev/null 2>&1; status=$?
check "no log is a usage error" '[[ $status -eq 2 ]]'

exit $fail
