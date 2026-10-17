#!/usr/bin/env bash
# Tests/ci_findings/test_ci_findings.sh: fixture test for scripts/ci-findings
# against a stub `gh` (a script first on PATH that answers `issue list` and
# `issue view` from fixture files and logs every write). Cases: a red test with
# an open finding is updated and keeps the Feature:, Slice: and Owner: lines
# of the old body (and drops its stale Error/Run lines); a red test with no
# finding is filed with its line label; a passing test with an open finding is
# commented on and closed; a test that did not run in the log stays open; a
# test that failed and passed (a retry) stays open; an unreadable body is
# never overwritten. Needs bash and jq.
#
# Run: bash Tests/ci_findings/test_ci_findings.sh   (exit 0 = all pass)
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
# Stub gh: $FX holds list.json and body.<n> fixtures; writes append to $FX/calls.
case "$1 $2" in
  "issue list") cat "$FX/list.json" ;;
  "issue view") [[ -e "$FX/body.$3" ]] && cat "$FX/body.$3" || exit 1 ;;
  "issue edit") echo "edit $3" >>"$FX/calls"; cp "${5:?}" "$FX/edited.$3" ;;
  "issue create") echo "create $*" >>"$FX/calls" ;;
  "issue comment") echo "comment $3 $*" >>"$FX/calls" ;;
  "issue close") echo "close $3" >>"$FX/calls" ;;
  *) echo "stub gh: unexpected $*" >&2; exit 2 ;;
esac
GH
chmod +x "$tmp/bin/gh"

export FX="$tmp/fx" PATH="$tmp/bin:$PATH" RUN_URL="https://example.test/runs/9" GITHUB_REF_NAME=dev GITHUB_SHA=abc123
mkdir "$FX"
cat >"$FX/list.json" <<'JSON'
[
 {"number":11,"title":"CI finding: FlareJourneyTests/ExportJourney/testExport"},
 {"number":12,"title":"CI finding: FlareJourneyTests/ExportJourney/testBrush"},
 {"number":13,"title":"CI finding: PhotoJourneyTests/CropJourney/testCrop"},
 {"number":14,"title":"CI finding: PhotoJourneyTests/CropJourney/testFlaky"},
 {"number":15,"title":"CI finding: HaloJourneyTests/OpenJourney/testOpen"},
 {"number":99,"title":"Unrelated issue"}
]
JSON
printf 'Old text.\nError: stale\nRun: https://example.test/runs/1\n\nFeature: flare-export\nSlice: s2\nOwner: @lead-flare\n' >"$FX/body.11"
printf 'Test: x\n' >"$FX/body.12"
# #15 has no body fixture: gh issue view fails, so the edit must be skipped.

cat >"$tmp/ui.log" <<'LOG'
Test Case '-[FlareJourneyTests.ExportJourney testExport]' started.
/src/Export.swift:9: error: -[FlareJourneyTests.ExportJourney testExport] : XCTAssertTrue failed - no sheet
Test Case '-[FlareJourneyTests.ExportJourney testExport]' failed (4.0 seconds).
Test Case '-[FlareJourneyTests.ExportJourney testBrush]' passed (1.0 seconds).
Test Case '-[PhotoJourneyTests.CropJourney testCrop]' skipped (0.0 seconds).
Test Case '-[PhotoJourneyTests.CropJourney testFlaky]' failed (1.0 seconds).
Test Case '-[PhotoJourneyTests.CropJourney testFlaky]' passed (1.0 seconds).
Test Case '-[HaloJourneyTests.OpenJourney testOpen]' failed (1.0 seconds).
Test Case '-[LibraryJourneyTests.ShelfJourney testShelf]' failed (1.0 seconds).
Test Case '-[SuiteUIJourneyTests.HomeJourney testHome]' passed (1.0 seconds).
LOG

out=$("$root/scripts/ci-findings" "$tmp/ui.log" 2>&1); status=$?
calls=$(cat "$FX/calls")
check "exits 0" '[[ $status -eq 0 ]]'
check "an update keeps Feature:" 'grep -qx "Feature: flare-export" "$FX/edited.11"'
check "an update keeps Slice: and Owner:" 'grep -qx "Slice: s2" "$FX/edited.11" && grep -qx "Owner: @lead-flare" "$FX/edited.11"'
check "an update rewrites the rest (new error, new run, no stale line)" \
  'grep -q "^Error: XCTAssertTrue failed - no sheet" "$FX/edited.11" && grep -q "runs/9" "$FX/edited.11" && ! grep -q "stale" "$FX/edited.11"'
check "a new red test is filed with its line label" '[[ "$calls" == *"create issue create --title CI finding: LibraryJourneyTests/ShelfJourney/testShelf --label finding,line:library"* ]]'
check "an unreadable body is never overwritten" '[[ "$calls" != *"edit 15"* && "$out" == *"left its body alone"* ]]'
check "a passing test closes its finding with a comment" \
  '[[ "$calls" == *"comment 12 issue comment 12 --body Passes on run https://example.test/runs/9"* && "$calls" == *"close 12"* ]]'
check "a test that did not run stays open" '[[ "$calls" != *"13"* ]]'
check "a test that failed and passed stays open" '[[ "$calls" != *"close 14"* && "$calls" != *"comment 14"* ]]'
check "a failing test is not closed" '[[ "$calls" != *"close 11"* ]]'
check "an unrelated issue is untouched" '[[ "$calls" != *"99"* ]]'

exit $fail
