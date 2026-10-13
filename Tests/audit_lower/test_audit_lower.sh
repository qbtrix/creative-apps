#!/usr/bin/env bash
# Tests/audit_lower/test_audit_lower.sh: fixture tests for scripts/audit-lower,
# the decision behind CI's baseline lowering on dev. Counts only under the baseline lower
# it (a check at 0 leaves its app's line, an app stays even when emptied, the
# layout and key order hold); any count over it fails and writes nothing;
# counts on the baseline change nothing; an app the run didn't measure, or one
# the baseline doesn't list, is left alone. On a retry against a dev that moved
# since the measurement, only checks still at their measured-against count are
# lowered. No network; needs bash and jq.
#
# Run: bash Tests/audit_lower/test_audit_lower.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lower="$here/../../scripts/audit-lower"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

BASE='{
  "design": { "contrast": 2, "identifier": 33 },
  "halo": { "contrast": 2, "identifier": 10, "offscreen": 8, "unnamed": 5 },
  "photo": { "identifier": 54, "overlap": 1 }
}'

# run <name> <counts json> <want exit> <want stdout> <want baseline after> [<baseline now>]
# The counts were measured against BASE; a 6th argument is the baseline on dev
# since then, which the script gets with BASE as its MEASURED file.
run() {
  local got status after
  printf '%s\n' "${6:-$BASE}" >"$tmp/baseline.json"
  printf '%s\n' "$BASE" >"$tmp/measured.json"
  printf '%s\n' "$2" >"$tmp/counts.json"
  if [[ -n "${6:-}" ]]; then
    got=$("$lower" "$tmp/baseline.json" "$tmp/counts.json" "$tmp/measured.json" 2>"$tmp/err"); status=$?
  else
    got=$("$lower" "$tmp/baseline.json" "$tmp/counts.json" 2>"$tmp/err"); status=$?
  fi
  after=$(cat "$tmp/baseline.json")
  if [[ "$status" == "$3" && "$got" == "$4" && "$after" == "$5" ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1: exit $status (want $3)"; echo "  stdout: $got"; echo "  stderr: $(cat "$tmp/err")"
    echo "  baseline:"; echo "$after" | sed 's/^/    /'; fail=1
  fi
}

run "decrease only: lowers it in place and prints the change" \
  '{ "photo": { "identifier": 53, "overlap": 1 }, "design": { "contrast": 2, "identifier": 33 } }' 0 \
  '| photo | identifier | 54 | 53 |' \
  '{
  "design": { "contrast": 2, "identifier": 33 },
  "halo": { "contrast": 2, "identifier": 10, "offscreen": 8, "unnamed": 5 },
  "photo": { "identifier": 53, "overlap": 1 }
}'

run "a check at 0 leaves the line, an emptied app stays" \
  '{ "photo": { "identifier": 0, "overlap": 0 }, "halo": { "contrast": 2, "identifier": 9, "offscreen": 8, "unnamed": 0 } }' 0 \
  '| halo | identifier | 10 | 9 |
| halo | unnamed | 5 | 0 |
| photo | identifier | 54 | 0 |
| photo | overlap | 1 | 0 |' \
  '{
  "design": { "contrast": 2, "identifier": 33 },
  "halo": { "contrast": 2, "identifier": 9, "offscreen": 8 },
  "photo": {}
}'

run "any increase: fails and writes nothing, even beside a decrease" \
  '{ "photo": { "identifier": 50, "overlap": 2 } }' 1 '' "$BASE"
if grep -qxF 'photo overlap 1 -> 2' "$tmp/err"; then echo "ok   the increase is named on stderr"
else echo "FAIL the increase is named on stderr: $(cat "$tmp/err")"; fail=1; fi

run "a check new to an app counts from 0" \
  '{ "design": { "contrast": 2, "identifier": 33, "overlap": 1 } }' 1 '' "$BASE"

run "equal: nothing printed, nothing written" \
  '{ "photo": { "identifier": 54, "overlap": 1 }, "design": { "contrast": 2, "identifier": 33, "overlap": 0 } }' 0 '' "$BASE"

run "unmeasured and unlisted apps are left alone" \
  '{ "library": { "identifier": 99 }, "photo": { "identifier": 54, "overlap": 1 } }' 0 '' "$BASE"

run "counts that aren't app -> check -> count fail" '{ "photo": 3 }' 1 '' "$BASE"

# Retries: dev moved after the run measured photo identifier 53 and halo unnamed 4.
MEASURED_COUNTS='{ "photo": { "identifier": 53, "overlap": 1 }, "halo": { "contrast": 2, "identifier": 10, "offscreen": 8, "unnamed": 4 } }'
run "retry: an untouched line still lowers, a design change elsewhere is kept" "$MEASURED_COUNTS" 0 \
  '| halo | unnamed | 5 | 4 |
| photo | identifier | 54 | 53 |' \
  '{
  "design": { "contrast": 1, "identifier": 33 },
  "halo": { "contrast": 2, "identifier": 10, "offscreen": 8, "unnamed": 4 },
  "photo": { "identifier": 53, "overlap": 1 }
}' '{
  "design": { "contrast": 1, "identifier": 33 },
  "halo": { "contrast": 2, "identifier": 10, "offscreen": 8, "unnamed": 5 },
  "photo": { "identifier": 54, "overlap": 1 }
}'
MOVED='{
  "design": { "contrast": 2, "identifier": 33 },
  "halo": { "contrast": 2, "identifier": 10, "offscreen": 8, "unnamed": 5, "focus": 3 },
  "photo": { "identifier": 51, "overlap": 2 }
}'
run "retry: a count lowered, raised or added since is left for the next run" \
  '{ "photo": { "identifier": 53, "overlap": 1 }, "halo": { "contrast": 2, "identifier": 10, "offscreen": 8, "unnamed": 4 } }' 0 \
  '| halo | unnamed | 5 | 4 |' \
  '{
  "design": { "contrast": 2, "identifier": 33 },
  "halo": { "contrast": 2, "identifier": 10, "offscreen": 8, "unnamed": 4, "focus": 3 },
  "photo": { "identifier": 51, "overlap": 2 }
}' "$MOVED"

printf '%s\n' "$BASE" >"$tmp/baseline.json"
if "$lower" "$tmp/baseline.json" "$tmp/missing.json" 2>/dev/null; then echo "FAIL a missing counts file must fail"; fail=1
else echo "ok   a missing counts file fails"; fi

exit $fail
