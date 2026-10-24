#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # check() evals its single-quoted condition, which reads these
# Tests/ui_test/test_local_keys.sh: fixture test for scripts/ui-test's
# local-key journeys, the ones that post key events and so run only on the
# local Mac gate (#3035, #3559). It runs a copy of scripts/ui-test in a temp
# tree with stub scripts/quarantine, scripts/bundle-apps, xcodegen, xcodebuild
# and xcrun, and checks: on a hosted runner (RUNNER_ENVIRONMENT=github-hosted)
# each local-key journey goes to xcodebuild as -skip-testing and prints a
# "skipped: needs local key events" line; with the variable unset (this Mac)
# or self-hosted, none is skipped; and each listed journey still exists in
# UITests/, so a rename can't leave a dead skip. Needs bash and jq.
#
# Run: bash Tests/ui_test/test_local_keys.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/../.."
fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/scripts" "$tmp/bin"
cp "$repo/scripts/ui-test" "$tmp/scripts/ui-test"
printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/scripts/quarantine"
printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/scripts/bundle-apps"
printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/bin/xcodegen"
printf '#!/usr/bin/env bash\nexit 1\n' >"$tmp/bin/xcrun"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >"%s/xcodebuild.args"\n' "$tmp" >"$tmp/bin/xcodebuild"
chmod +x "$tmp/scripts/"* "$tmp/bin/"*

# run <RUNNER_ENVIRONMENT or "unset">: ui-test's output in $out, xcodebuild's args in $args
run() {
  rm -f "$tmp/xcodebuild.args"
  if [[ "$1" == unset ]]; then
    out=$(env -u RUNNER_ENVIRONMENT -u GITHUB_STEP_SUMMARY PATH="$tmp/bin:$PATH" "$tmp/scripts/ui-test" 2>&1)
  else
    out=$(env -u GITHUB_STEP_SUMMARY RUNNER_ENVIRONMENT="$1" PATH="$tmp/bin:$PATH" "$tmp/scripts/ui-test" 2>&1)
  fi
  args=$(cat "$tmp/xcodebuild.args" 2>/dev/null)
}
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

run github-hosted
hosted_out=$out
for t in FlareJourneyTests/FlareDrawJourneys/testDrawShapesWithEachTool \
  FlareJourneyTests/FlareEditOrderJourneys/testSelectAllOrderAndEscape \
  FlareJourneyTests/FlareViewJourneys/testZoomPanAndGuides; do
  check "hosted skips $t" 'printf "%s\n" "$args" | grep -qxF -- "-skip-testing:$t"'
  check "hosted prints the skip line for $t" '[[ "$out" == *"ui-test: skipped: needs local key events: $t"* ]]'
done

run unset
check "this Mac (unset) skips no local-key journey" '[[ "$args" != *FlareEditOrderJourneys* && "$out" != *"needs local key events"* ]]'
check "this Mac (unset) still runs xcodebuild" '[[ "$args" == *"-scheme"* ]]'
run self-hosted
check "a self-hosted runner skips no local-key journey" '[[ "$args" != *FlareEditOrderJourneys* && "$out" != *"needs local key events"* ]]'

# Each skipped journey's Target/Class/testName exists in UITests/ (the quarantine check's rule).
while IFS=/ read -r target class name; do
  [[ -n "$name" ]] || continue
  found=""
  for f in "$repo/UITests/$target.swift" "$repo/UITests/$target+"*.swift; do
    [[ -f "$f" ]] || continue
    if grep -qE "(class|extension)[[:space:]]+$class([^A-Za-z0-9_]|\$)" "$f" \
        && grep -qE "func[[:space:]]+${name}[[:space:]]*\(" "$f"; then found=1; break; fi
  done
  check "$target/$class/$name exists in UITests/" '[[ -n "$found" ]]'
# A here-string, not < <(...): under macOS bash 3.2 the first journey's glob came back
# unexpanded while the process-substitution child was live (8 of 8 runs in a gate tree).
done <<<"$(printf '%s\n' "$hosted_out" | sed -n 's/^ui-test: skipped: needs local key events: //p')"

exit $fail
