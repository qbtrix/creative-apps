#!/usr/bin/env bash
# Tests/quarantine/test_quarantine.sh: fixture tests for scripts/quarantine,
# the journey quarantine's check and its live list for scripts/ui-test. Each
# case writes a quarantine.json into a scratch UITests/ with a few journey
# files, fixes TODAY, and runs the script with a stub `gh` that reports the
# owner issue's state (OPEN, CLOSED, missing, or no access). No network; needs
# bash and jq. bash 3.2 compatible.
#
# Run: bash Tests/quarantine/test_quarantine.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
q="$here/../../scripts/quarantine"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
TODAY=2026-10-16

mkdir -p "$tmp/UITests" "$tmp/bin" "$tmp/nogh"
printf '%s\n' 'final class HaloJourneyTests: XCTestCase {' '    @MainActor func testLayoutAtWidths() {}' '}' \
  >"$tmp/UITests/HaloJourneyTests.swift"
printf '%s\n' 'final class HaloLayersJourneyTests: XCTestCase {' '    func testLayerHousekeeping() throws {}' '}' \
  >"$tmp/UITests/HaloJourneyTests+Layers.swift"
printf '%s\n' 'extension HaloJourneyTests {' '    @MainActor func testParentAndBlend() {}' '}' \
  >"$tmp/UITests/HaloJourneyTests+Parent.swift"
# A file named like a target, but no Library target main file: its tests don't count.
printf '%s\n' 'final class LibraryShellJourneyTests: XCTestCase {' '    func testLaunch() {}' '}' \
  >"$tmp/UITests/LibraryJourneyTests+Shell.swift"

# The stub gh: GH_STATE is what `gh issue view N --json state -q .state` does.
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_CALLS"
case "$GH_STATE" in
  missing) echo "GraphQL: Could not resolve to an issue or pull request with the number of $3. (repository.issue)" >&2; exit 1 ;;
  denied) echo "HTTP 401: Bad credentials (https://api.github.com/graphql)" >&2; exit 1 ;;
  *) echo "$GH_STATE" ;;
esac
EOF
chmod +x "$tmp/bin/gh"
# A PATH with only what the script runs, and no gh.
for c in jq grep dirname date; do ln -s "$(command -v "$c")" "$tmp/nogh/$c"; done
export GH_CALLS="$tmp/calls"

entry() { # entry <test> <owner> <reason> <expires>
  jq -nc --arg t "$1" --arg o "$2" --arg r "$3" --arg e "$4" '{test: $t, owner: $o, reason: $r, expires: $e}'
}
GOOD=$(entry HaloJourneyTests/HaloLayersJourneyTests/testLayerHousekeeping '#1177' 'H-J9 reorders the duplicated row' 2026-10-23)

# run <name> <json> <want exit> <want stdout> [<gh state, or nogh>] [<mode>]
run() {
  local got status path="$tmp/bin:$PATH"
  printf '%s\n' "$2" >"$tmp/UITests/quarantine.json"
  : >"$GH_CALLS"
  [[ "${5:-OPEN}" == nogh ]] && path="$tmp/nogh"
  got=$(PATH="$path" GH_STATE="${5:-OPEN}" "$BASH" "$q" "${6:-check}" "$tmp/UITests/quarantine.json" "$TODAY" 2>&1); status=$?
  if [[ "$status" == "$3" && "$got" == "$4" ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1: exit $status (want $3)"; echo "  got:  $got"; echo "  want: $4"; fail=1
  fi
}

run "an owned, unexpired entry passes" "[$GOOD]" 0 '1 quarantined, all owned and unexpired'
if grep -qx 'issue view 1177 -R qbtrix/creative-apps --json state -q .state' "$GH_CALLS"; then echo "ok   the owner is looked up once"
else echo "FAIL the owner is looked up once: $(cat "$GH_CALLS")"; fail=1; fi
run "an empty quarantine passes without gh" '[]' 0 '0 quarantined, all owned and unexpired' nogh
run "a class declared by an extension in another file counts" \
  "[$(entry HaloJourneyTests/HaloJourneyTests/testParentAndBlend '#1' 'Parent menu opens the Apple menu' 2026-10-20)]" \
  0 '1 quarantined, all owned and unexpired'

run "expired on its date" "[$(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths '#1019' 'lanes run past the edge' 2026-10-16)]" \
  1 'HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: expired on 2026-10-16: fix it, or renew with a new date and reason'
run "7 days out is the latest" "[$(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths '#1019' 'lanes' 2026-10-23)]" \
  0 '1 quarantined, all owned and unexpired'
run "8 days out fails" "[$(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths '#1019' 'lanes' 2026-10-24)]" \
  1 'HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: expires 2026-10-24, more than 7 days out (latest 2026-10-23)'
TODAY=2026-10-28 run "the 7 days cross a month end" \
  "[$(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths '#1019' 'lanes' 2026-11-05)]" \
  1 'HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: expires 2026-11-05, more than 7 days out (latest 2026-11-04)'
run "a date that isn't YYYY-MM-DD fails" "[$(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths '#1019' 'lanes' 10/20/2026)]" \
  1 'HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: expires must be YYYY-MM-DD'

run "an owner that isn't #<number> fails" "[$(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths 'halo lead' 'lanes' 2026-10-20)]" \
  1 'HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: owner must be an open issue, #<number>'
run "no owner and no reason fail" '[{"test": "HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths", "expires": "2026-10-20"}]' \
  1 'HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: owner must be an open issue, #<number>
HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: reason is empty: say why it fails'
run "a blank reason fails" "[$(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths '#1019' '   ' 2026-10-20)]" \
  1 'HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: reason is empty: say why it fails'

run "a test that isn't in UITests fails" "[$(entry HaloJourneyTests/HaloJourneyTests/testGone '#1' 'gone' 2026-10-20)]" \
  1 "HaloJourneyTests/HaloJourneyTests/testGone: no such test in $tmp/UITests"
run "a test under the wrong class fails" "[$(entry HaloJourneyTests/HaloJourneyTests/testLayerHousekeeping '#1' 'x' 2026-10-20)]" \
  1 "HaloJourneyTests/HaloJourneyTests/testLayerHousekeeping: no such test in $tmp/UITests"
run "a target without its main file fails" "[$(entry LibraryJourneyTests/LibraryShellJourneyTests/testLaunch '#1' 'x' 2026-10-20)]" \
  1 "LibraryJourneyTests/LibraryShellJourneyTests/testLaunch: no such test in $tmp/UITests"
run "a test that isn't Target/Class/testName fails" "[$(entry HaloJourneyTests.testLayoutAtWidths '#1' 'x' 2026-10-20)]" \
  1 'HaloJourneyTests.testLayoutAtWidths: test must be Target/Class/testName'

run "a closed owner fails" "[$GOOD]" 1 'owner #1177 is CLOSED, not open: remove its entries or name an open owner' CLOSED
run "a missing owner fails" "[$GOOD]" 1 'owner #1177 is MISSING, not open: remove its entries or name an open owner' missing
run "gh without access skips the owner check only" "[$GOOD]" 0 'SKIP owner issues not checked: gh can'"'"'t read #1177 from qbtrix/creative-apps
1 quarantined, all owned and unexpired' denied
run "no gh skips the owner check only" "[$GOOD]" 0 'SKIP owner issues not checked: gh not found
1 quarantined, all owned and unexpired' nogh
run "no gh still fails an expired entry" \
  "[$(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths '#1019' 'lanes' 2026-10-01)]" 1 'SKIP owner issues not checked: gh not found
HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths: expired on 2026-10-01: fix it, or renew with a new date and reason' nogh
run "an object instead of a list fails" "$GOOD" 1 "$tmp/UITests/quarantine.json: not a JSON array of entries"

run "live lists unexpired entries only, as TSV" \
  "[$GOOD, $(entry HaloJourneyTests/HaloJourneyTests/testLayoutAtWidths '#1019' 'lanes' 2026-10-16)]" 0 \
  "$(printf 'HaloJourneyTests/HaloLayersJourneyTests/testLayerHousekeeping\t#1177\t2026-10-23\tH-J9 reorders the duplicated row')" \
  nogh live
run "live on an empty quarantine prints nothing" '[]' 0 '' nogh live

exit $fail
