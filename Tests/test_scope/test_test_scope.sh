#!/usr/bin/env bash
# Tests/test_scope/test_test_scope.sh: tests for scripts/test-scope, the one
# table of which swift tests run where. Changed paths map to the right test
# filters (a Design Model file runs DesignModelTests only), apps map to the
# filters CI's scoped runs use, every entry of Tests/perf-suites.txt and
# Tests/heavy-suites.txt names a test that exists, every test asserting a
# wall-clock bound is in the perf list or the shrink-only timing baseline
# (scripts/test-scope timing, with its own fixture cases), the perf
# and heavy regexes take exactly the listed tests (a suite, one test of a
# suite, a free test) and nothing beside them, and perf-report
# flags only a bound missed by more than its multiple. No swift; needs
# python3. bash 3.2 compatible.
#
# Run: bash Tests/test_scope/test_test_scope.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$here/../.."
ts="$root/scripts/test-scope"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

# check NAME WANT GOT
check() {
  if [[ "$2" == "$3" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fail=1; fi
}
# changed [--linux] PATH...: the two filter lines joined by ";", or "all".
changed() {
  local flag=()
  [[ "$1" != --linux ]] || { flag=(--linux); shift; }
  printf '%s\n' "$@" | python3 "$ts" changed ${flag[@]+"${flag[@]}"} | paste -sd';' -
}

design_snaps='^AppSnapshotTests\.(BodyCountSuites/)?((RenderBudget)?Design[A-Za-z]*/|AppSnapshotTests/design\()'
photo_snaps='^AppSnapshotTests\.(BodyCountSuites/)?((RenderBudget)?Photo[A-Za-z]*/|AppSnapshotTests/photo\()'
suiteui_snaps='^AppSnapshotTests\.(BodyCountSuites/)?((Suite[A-Za-z]*|GoldenImageTests|SnapshotHostTests)/|(suite[A-Za-z]*|snapshotsDrawRealSlidersNotPlaceholders|theCapsuleDrawsOnlyBehindTheCurrentItem|aDisabledBarCommandDrawsDimmerThanAnEnabledOne)\(|AppSnapshotTests/suiteGallery\()'

# Changed paths to tests.
check "a Design Model file runs DesignModelTests and the CLI's tests" \
  '^(AfterGlowCLITests|DesignModelTests)\.;' "$(changed Sources/DesignModel/DesignNode.swift)"
check "a Design App file runs Design's snapshot suites only" \
  ";$design_snaps" "$(changed Sources/DesignApp/DesignWindow.swift)"
check "a Model file, another app's view and a doc" \
  "^(AfterGlowCLITests|DesignModelTests)\\.;$photo_snaps" "$(changed Sources/DesignModel/A.swift Sources/PhotoApp/B.swift docs/engineering.md)"
check "SuiteModel runs every Model's tests" \
  '^(DesignModelTests|FlareModelTests|HaloModelTests|LibraryModelTests|PhotoModelTests|SuiteModelTests)\.;' \
  "$(changed Sources/SuiteModel/Values/SuiteApp.swift)"
check "SuiteKernel runs SuiteKernelTests and every Model's tests" \
  '^(AfterGlowCLITests|DesignModelTests|FlareModelTests|HaloModelTests|LibraryModelTests|PhotoModelTests|SuiteKernelTests)\.;' \
  "$(changed Sources/SuiteKernel/Geometry.swift)"
check "a kernel module file runs the same" \
  '^(AfterGlowCLITests|DesignModelTests|FlareModelTests|HaloModelTests|LibraryModelTests|PhotoModelTests|SuiteKernelTests)\.;' \
  "$(changed Sources/SuiteKernel/History/History.swift)"
check "SuiteUI runs SuiteUITests and its snapshot suites" \
  "^(SuiteUITests)\\.;$suiteui_snaps" "$(changed Sources/SuiteUI/Tokens.swift)"
check "AfterGlow and SuiteShell run the suite scope" \
  '^(AfterGlowCLITests|SuiteKernelTests|SuiteModelTests)\.;' "$(changed Sources/AfterGlowApp/HomeWindow.swift Sources/SuiteShell/SuiteCommands.swift)"
check "the CLI and its entry run AfterGlowCLITests only" '^(AfterGlowCLITests)\.;' \
  "$(changed Sources/AfterGlowCLI/main.swift Sources/AfterGlowCLICore/CLI.swift)"
check "a CLI test file or a real job runs AfterGlowCLITests only" '^(AfterGlowCLITests)\.;' \
  "$(changed Tests/AfterGlowCLITests/CLIShapeTests.swift Tests/RealJobs/fake/grow/grow.jobs.json)"
check "a Model test file runs its target" '^(HaloModelTests)\.;' "$(changed Tests/HaloModelTests/HaloEditTests.swift)"
check "a kernel test file runs SuiteKernelTests only" '^(SuiteKernelTests)\.;' \
  "$(changed Tests/SuiteKernelTests/KernelShapeTests.swift)"
check "--linux keeps SuiteKernelTests, which Linux builds" '^(SuiteKernelTests)\.;' \
  "$(changed --linux Tests/SuiteKernelTests/KernelShapeTests.swift Sources/SuiteUI/C.swift)"
check "an app's snapshot file runs that app's snapshot suites" \
  ";$photo_snaps" "$(changed Tests/AppSnapshotTests/PhotoBrushSnapshots.swift)"
check "an app's render budget file runs that app's snapshot suites" \
  ";$photo_snaps" "$(changed Tests/AppSnapshotTests/RenderBudgetPhotoTests.swift)"
check "a shared snapshot file runs every snapshot" \
  ';^AppSnapshotTests\.' "$(changed Tests/AppSnapshotTests/GoldenImage.swift)"
check "docs, scripts, journeys, CI and the perf list run no tests" ';' \
  "$(changed docs/factory/lead.md scripts/ci .github/workflows/ci.yml UITests/DesignJourneyTests.swift Tests/perf-suites.txt Tests/test_scope/test_test_scope.sh)"
check "Package.swift runs everything" all "$(changed Sources/DesignModel/A.swift Package.swift)"
check "a Sources folder the table doesn't know runs everything" all "$(changed Sources/NewModel/A.swift)"
check "--linux drops what Linux doesn't build" \
  '^(AfterGlowCLITests|DesignModelTests)\.;' "$(changed --linux Sources/DesignModel/A.swift Sources/DesignApp/B.swift Sources/SuiteUI/C.swift)"

# Apps to tests, as CI's scoped runs use them.
check "app photo" "^(PhotoModelTests)\\.;$photo_snaps" "$(python3 "$ts" app photo | paste -sd';' -)"
check "app suite" '^(AfterGlowCLITests|SuiteKernelTests|SuiteModelTests)\.;' "$(python3 "$ts" app suite | paste -sd';' -)"
check "app suiteui" "^(AppAuditTests|SuiteKernelTests|SuiteUITests)\\.;$suiteui_snaps" "$(python3 "$ts" app suiteui | paste -sd';' -)"
check "app design,photo: the union, as a lane batch scopes its macOS gate" \
  "^(DesignModelTests|PhotoModelTests)\\.;" "$(python3 "$ts" app design,photo | paste -sd';' - | cut -d';' -f1);"
python3 "$ts" app photo,nope >/dev/null 2>&1
check "an unknown app in a list is refused" 1 "$?"
python3 "$ts" app nope >/dev/null 2>&1
check "an unknown app is refused" 1 "$?"

# Code paths to the apps the lane's macOS build-only run compiles (build-apps).
apps() { printf '%s\n' "$@" | python3 "$ts" build-apps; }
check "build-apps: one app's Model, tests, app, snapshots and journeys" photo \
  "$(apps Sources/PhotoModel/A.swift Tests/PhotoModelTests/B.swift Sources/PhotoApp/C.swift \
    Tests/AppSnapshotTests/PhotoBrushSnapshots.swift Tests/AppSnapshotTests/RenderBudgetPhotoTests.swift UITests/PhotoJourneyTests+Layers.swift)"
check "build-apps: two apps give both" design,photo "$(apps Sources/PhotoApp/C.swift Sources/DesignModel/X.swift)"
for p in Sources/SuiteUI/Tokens.swift Sources/SuiteKernel/Geometry.swift Sources/SuiteModel/Values/SuiteApp.swift \
    Sources/SuiteShell/SuiteCommands.swift Sources/AfterGlowApp/HomeWindow.swift Sources/AfterGlowCLI/main.swift \
    Tests/AfterGlowCLITests/CLIShapeTests.swift Tests/SuiteUITests/TokensTests.swift Tests/AppAuditTests/Checks/Overlap.swift \
    Tests/AppSnapshotTests/GoldenImage.swift UITests/Journey.swift UITests/Audit.swift UITests/SuiteJourneyTests.swift \
    Package.swift project.yml Sources/NewModel/A.swift; do
  check "build-apps: shared $p builds all" all "$(apps Sources/PhotoApp/C.swift "$p")"
done
check "build-apps: no paths builds all" all "$(printf '' | python3 "$ts" build-apps)"

# Changed paths to the `app` scopes whose tests cover what `changed` picks (scopes).
scopes() { printf '%s\n' "$@" | python3 "$ts" scopes; }
check "scopes: a Model and an app's snapshots, not the CLI tests Linux runs" photo "$(scopes Sources/PhotoModel/A.swift Sources/PhotoApp/B.swift)"
check "scopes: SuiteUI and its tests" suiteui "$(scopes Sources/SuiteUI/A.swift Tests/SuiteUITests/B.swift Tests/AppAuditTests/C.swift)"
check "scopes: a fixture and the kernel's" design,suite "$(scopes Tests/DesignModelTests/Fixtures/a.svg Tests/SuiteKernelTests/Fixtures/place/a.json)"
check "scopes: a golden PNG and Package.swift are all" all,all "$(scopes Tests/AppSnapshotTests/Golden/canvas/a.png),$(scopes Package.swift)"
check "scopes: docs, scripts, journeys and real jobs are none" "" "$(scopes docs/a.md scripts/ci UITests/PhotoJourneyTests.swift Tests/RealJobs/photo/x/input/a.png)"

# Every perf and heavy list entry names a test that exists.
missing=""
while read -r app id; do
  case "$app" in ''|'#'*) continue ;; esac
  target=${id%%.*} rest=${id#*.}
  IFS=/ read -ra parts <<<"$rest"
  n=${#parts[@]} last=${parts[$((${#parts[@]} - 1))]}
  if [[ $n -eq 1 ]]; then  # a suite (a serialized parent is an enum) or a free test
    grep -rqE "(struct|enum|func) $last[[:space:](<:]" "$root/Tests/$target" || missing="$missing $id"
    continue
  fi
  # Every part before the last is a suite (a nested one has its parent enum first).
  for p in "${parts[@]:0:n-1}"; do
    grep -rqE "(struct|enum) $p[[:space:]:{]" "$root/Tests/$target" || missing="$missing $id"
  done
  # The last is a nested suite or a test of the suite before it.
  grep -rqE "struct $last[[:space:]:{]" "$root/Tests/$target" && continue
  suite=${parts[$((n - 2))]}
  file=$(grep -rlE "struct $suite[[:space:]:{]" "$root/Tests/$target" | head -1)
  [[ -n "$file" ]] && grep -qE "func $last\\(" "$file" || missing="$missing $id"
done < <(cat "$root/Tests/perf-suites.txt" "$root/Tests/heavy-suites.txt")
check "every Tests/perf-suites.txt and Tests/heavy-suites.txt entry names a test in Tests/" "" "$missing"

# Every test that asserts a wall-clock bound is in the perf list.
check "every wall-clock test in Tests/ is in Tests/perf-suites.txt (land a new one .disabled and ask the supervisor for its line; // not-timing: only for a look-alike)" "" "$(python3 "$ts" timing)"

# What timing takes: a fixture tree whose perf list holds one suite.
mkdir -p "$tmp/tree/PhotoModelTests"
cat >"$tmp/tree/PhotoModelTests/A.swift" <<'EOF'
import Testing
let clock = ContinuousClock()
@Suite struct ListedTests {
    @Test func timed() { #expect(clock.measure {} < .milliseconds(5)) }
    @Test func helperTimed() { expectP95(step, atMost: 8, target: 4) }
}
@Suite(.disabled("waits"))
struct OffTests {
    @Test func timed() { #expect(elapsed < .seconds(1)) }
}
@Test(.disabled("waits")) func offTest() { #expect(elapsed < .seconds(1)) }
@Test func marked() {
    // not-timing: an injected clock
    #expect(now < .seconds(1))
}
@Test func bodies() { #expect(bodies <= 3, "median \(bodies)") }
@Test func lowerBound() { #expect(elapsed >= .milliseconds(3)) }
@Test func timedMedian() { #expect(cost.median <= 50 * scale) }
@Test(arguments: [1,
                  2]) func unlisted(n: Int) { #expect(took < .seconds(1)) }
@Test func helperP95() { expectP95(step, atMost: 8, target: 4) }
@Test func helperBodies() { expectBodies(step, atMost: 3, target: 3) }
@Test func framesDrawn() { if let redrawn { #expect(redrawn >= 30, "drew \(redrawn)") } }
@Test func stepsSent() { #expect(step.steps >= 120) }
EOF
# A helper that asserts a timing bound makes every test calling it a timing test.
cat >"$tmp/tree/PhotoModelTests/Harness.swift" <<'EOF'
let harnessClock = ContinuousClock()
func expectP95(_ step: Step, atMost budget: Double, target: Double) { #expect(step.p95 <= budget) }
func expectBodies(_ step: Step, atMost budget: Int, target: Int) { #expect(step.bodies <= budget) }
EOF
printf '%s\n' '@Test func untimedMedian() { #expect(copies.median <= 2) }' >"$tmp/tree/PhotoModelTests/B.swift"
# Ratios: a test whose own body reads a clock (Date() counts, in a nested func
# too) and bounds a ratio under 10x is a timing test; 10x passes, an abs()
# tolerance passes, a ratio in a test that reads no clock passes (a shared
# helper reading one doesn't count), and a Date() file's named bound is a bound.
cat >"$tmp/tree/PhotoModelTests/C.swift" <<'EOF'
import Testing
func render() -> Double { let start = Date(); return Date().timeIntervalSince(start) }
@Test func tightRatio() {
    func seconds(_ work: () -> Void) -> Double { let start = Date(); work(); return Date().timeIntervalSince(start) }
    let narrow = seconds {}
    let wide = seconds {}
    #expect(wide < narrow * 3 + 0.1, "wide \(wide) s, narrow \(narrow) s")
}
@Test func wideRatio() {
    let start = Date(); let narrow = Date().timeIntervalSince(start); let wide = Date().timeIntervalSince(start)
    #expect(wide < narrow * 10)
}
@Test func tolerance() { let g = Date().timeIntervalSince(Date()); #expect(abs(back - g) <= g * 1e-12) }
@Test func countRatio() { let disabled = render(); let enabled = render(); #expect(disabled < enabled * 0.8, "dimmer") }
@Test func divided() {
    let start = Date(); let narrow = Date().timeIntervalSince(start); let wide = Date().timeIntervalSince(start)
    #expect(wide / narrow <= 2.5, "ratio")
}
@Test func dateBudget() { let elapsed = render(); #expect(elapsed < 0.5) }
EOF
printf '%s\n' 'photo PhotoModelTests.ListedTests' >"$tmp/listed.txt"
: >"$tmp/no-baseline.txt"
printf '%s\n' '# grandfathered' 'PhotoModelTests.unlisted' 'PhotoModelTests.gone' >"$tmp/baseline.txt"
check "timing names each unlisted bound: a Duration, a timing name or a frames-drawn floor in a file that reads a clock, a ratio under 10x in a test that reads one, or a call to a helper that asserts one" \
  'PhotoModelTests.timedMedian;PhotoModelTests.unlisted;PhotoModelTests.helperP95;PhotoModelTests.framesDrawn;PhotoModelTests.tightRatio;PhotoModelTests.divided;PhotoModelTests.dateBudget' \
  "$(TESTS_DIR="$tmp/tree" PERF_SUITES="$tmp/listed.txt" TIMING_BASELINE="$tmp/no-baseline.txt" python3 "$ts" timing | cut -d' ' -f1 | paste -sd';' -)"
check "timing passes a baselined test and names a baseline line that no longer times (the baseline only shrinks)" \
  'PhotoModelTests.timedMedian;PhotoModelTests.helperP95;PhotoModelTests.framesDrawn;PhotoModelTests.tightRatio;PhotoModelTests.divided;PhotoModelTests.dateBudget;PhotoModelTests.gone' \
  "$(TESTS_DIR="$tmp/tree" PERF_SUITES="$tmp/listed.txt" TIMING_BASELINE="$tmp/baseline.txt" python3 "$ts" timing | cut -d' ' -f1 | paste -sd';' -)"

# ids: each @Test of a file as a perf-list id (the fast lane's quarantine resolves a red test's file this way).
printf '%s\n' 'import Testing' '@Suite struct OpenTests {' '    @Test func opens() {}' '    enum Nested {' '        @Test func inner() {}' '    }' '}' '@Test func freeOne() {}' >"$tmp/Ids.swift"
check "ids prints Target.Suite/test, nested suites joined, and Target.freeTest" \
  'PhotoModelTests.OpenTests/opens;PhotoModelTests.OpenTests/Nested/inner;PhotoModelTests.freeOne' \
  "$(python3 "$ts" ids PhotoModelTests "$tmp/Ids.swift" | paste -sd';' -)"

# The perf regex: exactly the listed tests, by suite, one test or free test.
perf=$(python3 "$ts" perf)
takes() { grep -qE "$perf" <<<"$1" && echo yes || echo no; }
check "takes a listed suite's test" yes "$(takes 'PhotoModelTests.PhotoEditBudgetTests/editBudgets()')"
check "takes a listed suite's parameterized test" yes "$(takes 'HaloModelTests.HaloKeysBudgetTests/viewerDragStep(services:)')"
check "takes a listed test of a mixed suite" yes \
  "$(takes 'PhotoModelTests.PhotoCompositeCostTests/aLayerCostsAboutOnePictureCopyNotOnePerTile()')"
check "leaves its suite's other tests in the gate" no \
  "$(takes 'PhotoModelTests.PhotoCompositeCostTests/theTiledPathMatchesThePicturePath()')"
check "leaves PhotoStrokePacerTests' order tests in the gate" no \
  "$(takes 'AppSnapshotTests.PhotoStrokePacerTests/aSampleAfterTheSpacingAppliesAtOnce()')"
check "leaves HaloFilesBudgetTests' size test in the gate" no "$(takes 'HaloModelTests.HaloFilesBudgetTests/hugeFitsTheLimit()')"
check "takes a nested suite's timing test" yes "$(takes 'AppSnapshotTests.BodyCountSuites/RenderBudgetHaloTests/timing()')"
check "leaves that nested suite's bodies test in the gate" no "$(takes 'AppSnapshotTests.BodyCountSuites/RenderBudgetHaloTests/bodies()')"
check "a nested suite is in its app's scope" yes \
  "$(grep -qE "$photo_snaps" <<<'AppSnapshotTests.BodyCountSuites/PhotoWindowStrokeTests/aBrushStrokeRedrawsOnlyTheCanvas()' && echo yes || echo no)"
check "takes a listed free test" yes "$(takes 'FlareModelTests.hitWithinBudget()')"
check "leaves a free test that only shares a prefix" no "$(takes 'FlareModelTests.hitWithinBudgetTwice()')"
check "leaves a suite that only shares a prefix" no "$(takes 'PhotoModelTests.PhotoBudgetTestsHelpers/x()')"
check "leaves another target's suite of the same name" no "$(takes 'DesignModelTests.PhotoBudgetTests/x()')"
photo=$(python3 "$ts" perf photo)
check "perf photo takes Photo's" yes "$(grep -qE "$photo" <<<'AppSnapshotTests.PhotoBrushLatencyTests/x()' && echo yes || echo no)"
check "perf photo leaves Halo's" no "$(grep -qE "$photo" <<<'HaloModelTests.HaloViewerBudgetTests/x()' && echo yes || echo no)"
printf '%s\n' 'photo PhotoModelTests.PhotoBudgetTests' >"$tmp/photo-only.txt"
check "perf for an app with none is empty, never a match-all regex" "" "$(PERF_SUITES="$tmp/photo-only.txt" python3 "$ts" perf halo)"
printf '%s\n' '# nothing yet' >"$tmp/empty.txt"
check "an empty list gives no regex" "" "$(PERF_SUITES="$tmp/empty.txt" python3 "$ts" perf)"
printf '%s\n' 'photo PhotoModelTests' >"$tmp/bad.txt"
PERF_SUITES="$tmp/bad.txt" python3 "$ts" perf >/dev/null 2>&1
check "a malformed entry is refused" 1 "$?"
printf '%s\n' 'paint PhotoModelTests.PhotoBudgetTests' >"$tmp/bad.txt"
PERF_SUITES="$tmp/bad.txt" python3 "$ts" perf >/dev/null 2>&1
check "an unknown app in the list is refused" 1 "$?"

# The heavy regex: the listed tests, all or those a --changed filter takes.
printf '%s\n' '# heavy' 'photo PhotoModelTests.PhotoRenderRouteTests' 'library LibraryModelTests.matchesFullPipeline' >"$tmp/heavy.txt"
heavy=$(HEAVY_SUITES="$tmp/heavy.txt" python3 "$ts" heavy)
takes_heavy() { grep -qE "$heavy" <<<"$1" && echo yes || echo no; }
check "heavy takes a listed suite's test" yes "$(takes_heavy 'PhotoModelTests.PhotoRenderRouteTests/aRegionsSurfaceIsTheRenderedRegion()')"
check "heavy takes a listed free test" yes "$(takes_heavy 'LibraryModelTests.matchesFullPipeline()')"
check "heavy leaves the rest of the target" no "$(takes_heavy 'PhotoModelTests.PhotoRendererTests/aFrameIsTheCompositeInDisplayBytes()')"
check "heavy within a changed filter keeps that target's" '^(PhotoModelTests\.PhotoRenderRouteTests)(/|\()' \
  "$(HEAVY_SUITES="$tmp/heavy.txt" python3 "$ts" heavy '^(DesignModelTests|PhotoModelTests)\.')"
check "heavy within a filter that takes none is empty, never a match-all regex" "" \
  "$(HEAVY_SUITES="$tmp/heavy.txt" python3 "$ts" heavy '^(SuiteModelTests)\.')"
check "an empty heavy list gives no regex" "" "$(HEAVY_SUITES="$tmp/empty.txt" python3 "$ts" heavy)"

# shard K/N: the sorted distinct top-level suites (a nested suite stays with its
# parent; free tests on their own) go round-robin; every shard agrees, nothing
# is listed twice or dropped, and the snapshot suites come on the second line.
ids=$'FlareModelTests.A/t1()\nFlareModelTests.A/t2(x:)\nFlareModelTests.free()\nAppSnapshotTests.BodyCountSuites/RenderBudgetX/t()\nAppSnapshotTests.S/t()\nPhotoModelTests.B/t()\nwarning: not a test'
check "shard 1/2 takes units 0, 2 and 4 of the sorted list" \
  $'^(FlareModelTests\\.A|PhotoModelTests\\.B)(/|\\()\n^(AppSnapshotTests\\.BodyCountSuites)(/|\\()' "$(printf '%s\n' "$ids" | python3 "$ts" shard 1/2)"
check "shard 2/2 takes units 1 and 3" $'^(FlareModelTests\\.free)(/|\\()\n^(AppSnapshotTests\\.S)(/|\\()' "$(printf '%s\n' "$ids" | python3 "$ts" shard 2/2)"
check "a shard with no suite prints two empty lines, never a match-all regex" "" "$(printf '%s\n' 'T.A/t()' | python3 "$ts" shard 2/2 | tr -d '\n')"
printf '%s\n' "$ids" | python3 "$ts" shard 3/2 >/dev/null 2>&1
check "shard K past N is refused" 1 "$?"

# perf-report: what Swift Testing prints for a missed bound, both ways it
# shows the values, and a test that only says "failed".
cat >"$tmp/perf.log" <<'EOF'
◇ Test editBudgets() started.
PhotoBudget move p50 12.0 ms p95 14.0 ms max 20.0 ms (60 events, gated)
✘ Test editBudgets() recorded an issue at PhotoEditBudgetTests.swift:99:21: Expectation failed: series.p50 <= budget
↳ PB-1 move: median 0.012 seconds
↳ series.p50 <= budget → false
↳   series.p50 → 0.012 seconds
↳     _low → 12000000000000000
↳     _high → 0
↳   budget → 0.003 seconds
↳     _low → 3000000000000000
↳     _high → 0
✘ Test editBudgets() failed after 1.0 seconds with 1 issue.
✘ Test hitWithinBudget() recorded an issue at LiveStageBudgetTests.swift:30:5: Expectation failed: (runs.median → 0.015 seconds) <= (budget → 0.01 seconds)
✘ Test hitWithinBudget() failed after 0.5 seconds with 1 issue.
✘ Test aBrushEventReachesTheCanvasInTimeWithBytesForItsDirtyTiles() recorded an issue at PhotoBrushDisplayTests.swift:128:9: Expectation failed: overBudget.count == 0
✘ Test aBrushEventReachesTheCanvasInTimeWithBytesForItsDirtyTiles() failed after 3.0 seconds with 1 issue.
✔ Test cloneOrHeal(tool:) with 2 test cases passed after 0.4 seconds.
✘ Test run with 3 tests in 3 suites failed after 5.0 seconds with 3 issues.
✔ Test run with 1 test in 1 suite passed after 0.4 seconds.
EOF
python3 "$ts" perf-report "$tmp/perf.log" >"$tmp/report.md" 2>"$tmp/warnings"
check "perf-report exits 0 on failed tests" 0 "$?"
row() { grep -F "| \`$1\` |" "$tmp/report.md" | sed "s/^| \`$1\` | //; s/ |\$//"; }
check "a bound missed 4x is flagged (the ↳ form)" '**flagged: 4.0x its bound**' "$(row 'editBudgets()')"
check "a bound missed 1.5x is reported, not flagged (the inline form)" 'over its bound, 1.5x' "$(row 'hitWithinBudget()')"
check "a failure with no measured bound is reported" 'failed (no measured bound in its issue)' \
  "$(row 'aBrushEventReachesTheCanvasInTimeWithBytesForItsDirtyTiles()')"
check "a parameterized pass is listed" passed "$(row 'cloneOrHeal(tool:)')"
check "one warning, for the flagged test" '::warning title=Perf flag::editBudgets() measured 4.0x its bound (flagged over 3x)' \
  "$(cat "$tmp/warnings")"
check "the report carries every target's result line" 2 "$(grep -c 'Test run with' "$tmp/report.md")"
check "the report carries what the tests printed" yes \
  "$(grep -qx 'PhotoBudget move p50 12.0 ms p95 14.0 ms max 20.0 ms (60 events, gated)' "$tmp/report.md" && echo yes || echo no)"
printf '%s\n' '◇ Test editBudgets() started.' >"$tmp/died.log"
python3 "$ts" perf-report "$tmp/died.log" >/dev/null 2>"$tmp/warnings"
check "a run with no result line warns" '::warning title=Perf::the perf run printed no result line; it died or timed out' \
  "$(cat "$tmp/warnings")"

exit $fail
