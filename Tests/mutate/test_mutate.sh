#!/usr/bin/env bash
# Tests/mutate/test_mutate.sh: fixture test for scripts/mutate's checks that run
# before any build. --validate passes a plan whose every `find` occurs exactly
# once, and fails (exit 1, naming the problem) on a stale anchor, a duplicated
# one, a missing key, a `replace` equal to its `find` and a plan that isn't a
# list. A run refuses a stale anchor before it builds, and an --only that
# matches no label exits 1 instead of passing on nothing. The plans and their
# target file live in a scratch dir (absolute paths), so nothing here touches
# Sources/ or runs swift. Needs bash and python3.
#
# Run: bash Tests/mutate/test_mutate.sh   (exit 0 = all pass)
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

printf '%s\n' 'let a = x <= y' 'let b = 1' 'let c = 1' >"$tmp/Sample.txt"
# plan NAME ENTRY...: writes $tmp/NAME.json, a JSON list of the given entries.
plan() { local name=$1; shift; (IFS=,; printf '[%s]\n' "$*") >"$tmp/$name.json"; }
entry() { printf '{"label":"%s","file":"%s","find":"%s","replace":"%s","tests":"%s"}' "$1" "$tmp/Sample.txt" "$2" "$3" "${4-SampleTests}"; }
validate() { out=$(python3 "$root/scripts/mutate" --validate --plan "$tmp/$1.json" 2>&1); status=$?; }

plan good "$(entry "flip the edge" 'x <= y' 'x < y')" "$(entry "drop b" 'let b = 1' '')"
validate good
check "anchors that occur once pass" '[[ $status -eq 0 && "$out" == *"OK: 2 anchors in 1 plan(s)"* ]]'

plan stale "$(entry "gone" 'let d = 1' 'let d = 2')"
validate stale
check "a stale anchor fails and says so" '[[ $status -eq 1 && "$out" == *"gone: find occurs 0 times"* ]]'

plan twice "$(entry "ambiguous" '= 1' '= 2')"
validate twice
check "an anchor that occurs twice fails" '[[ $status -eq 1 && "$out" == *"ambiguous: find occurs 2 times"* ]]'

printf '[{"label":"no tests","file":"%s","find":"let b = 1","replace":""}]\n' "$tmp/Sample.txt" >"$tmp/nokey.json"
validate nokey
check "a missing key fails" '[[ $status -eq 1 && "$out" == *"#1: missing or empty tests"* ]]'

plan same "$(entry "no-op" 'let b = 1' 'let b = 1')"
validate same
check "a replace equal to its find fails" '[[ $status -eq 1 && "$out" == *"plants nothing"* ]]'

echo '{"label":"x"}' >"$tmp/object.json"
validate object
check "a plan that isn't a list fails" '[[ $status -eq 1 && "$out" == *"must be a JSON list"* ]]'

out=$(python3 "$root/scripts/mutate" --plan "$tmp/stale.json" 2>&1); status=$?
check "a run refuses a stale anchor before it builds" '[[ $status -eq 1 && "$out" == *"occurs 0 times"* && "$out" != *baseline* ]]'

out=$(python3 "$root/scripts/mutate" --plan "$tmp/good.json" --only "no such label" 2>&1); status=$?
check "an --only that matches nothing exits 1" '[[ $status -eq 1 && "$out" == *"No label contains"* ]]'

exit $fail
