#!/usr/bin/env bash
# Tests/canonical/test_check_body_counts.sh: scripts/check-body-counts, the
# "count the test's own windows" ratchet (factory lesson 345), on scratch trees:
# a stored `bodyRuns` counter or a `+=` on one is caught in Sources and Tests, a
# BodyCounted view passes, a `bodyRuns` read is fine inside BodyCountSuites and
# caught outside it, a test reading a Sources static Int counter is caught,
# comments never count, and the baseline allows existing hits but only shrinks.
# Run: bash Tests/canonical/test_check_body_counts.sh   (exit 0 = all pass)
# bash 3.2 compatible, needs python3.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lint="$here/../../scripts/check-body-counts"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() {  # expect <name> <want> <got>
  if [[ "$3" == "$2" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fail=1; fi
}
tree() { rm -rf "$tmp/r"; mkdir -p "$tmp/r/Tests" "$tmp/r/Sources"; }
add() { mkdir -p "$tmp/r/$(dirname "$1")"; printf '%s\n' "$2" >"$tmp/r/$1"; }
run() { python3 "$lint" --root "$tmp/r" "$@" 2>&1; }
hits() { run --update-baseline --allow-increase >/dev/null; grep -v '^#' "$tmp/r/Tests/body-counts-baseline.txt" | paste -sd, -; }

tree
add Sources/HaloApp/Old.swift $'struct Old: View {\n    static var bodyRuns = 0\n    var body: some View {\n        let _ = Self.bodyRuns += 1\n        Text("x")\n    }\n}'
add Tests/AppSnapshotTests/Page.swift $'private struct Page: View {\n    @MainActor static var bodyRuns: Int = 0\n    var body: some View { Text("x") }\n}'
expect "a stored bodyRuns counter and its += are caught in Sources and Tests" \
  "Sources/HaloApp/Old.swift::Old.bodyRuns,Tests/AppSnapshotTests/Page.swift::Page.bodyRuns" "$(hits)"

tree
add Sources/SuiteUI/New.swift $'struct New: View, BodyCounted {\n    @Environment(\\.bodyTally) private var bodyTally\n    // static var bodyRuns = 0 in a comment\n    var body: some View {\n        let _ = bodyTally.ran(Self.self)\n        Text("bodyRuns += 1")\n    }\n}'
add Tests/AppSnapshotTests/NewTests.swift $'extension BodyCountSuites {\n    @Suite struct NewTests {\n        @Test func a() { #expect(New.bodyRuns <= 3) }\n    }\n}'
expect "a BodyTally counter, a scoped read, comments and strings pass" "" "$(hits)"

tree
add Tests/SuiteUITests/LooseTests.swift $'@Suite struct LooseTests {\n    @Test func a() { #expect(TimelineLane<String>.bodyRuns == 0) }\n}'
expect "a bodyRuns read outside BodyCountSuites is caught" "Tests/SuiteUITests/LooseTests.swift::TimelineLane.bodyRuns" "$(hits)"

tree
add Sources/PhotoApp/Renderer.swift $'final class Renderer {\n    static var pictures = 0, inFlight = 0\n    static var lifts: Int = 0\n    static var name = "x"\n    var made = 0\n}'
add Tests/AppSnapshotTests/RendererTests.swift $'extension BodyCountSuites {\n    @Suite struct RendererTests {\n        @Test func a() { #expect(Renderer.inFlight == 0 && Renderer.lifts < 3 && Renderer.name == "x") }\n    }\n}'
expect "a test reading a Sources static Int counter is caught" \
  "Tests/AppSnapshotTests/RendererTests.swift::Renderer.inFlight,Tests/AppSnapshotTests/RendererTests.swift::Renderer.lifts" "$(hits)"

out=$(run); rc=$?
expect "listed hits pass" "0|check-body-counts: clean (2 grandfathered in Tests/body-counts-baseline.txt)" "$rc|$out"

add Tests/AppSnapshotTests/More.swift $'@Suite struct More { @Test func a() { #expect(Renderer.pictures == 0) } }'
out=$(run); rc=$?
expect "a new hit fails" "1|Tests/AppSnapshotTests/More.swift::Renderer.pictures" "$rc|$(sed 's/: .*//' <<<"$out")"
out=$(run --update-baseline); rc=$?
expect "the baseline refuses to grow" "1" "$rc"

rm "$tmp/r/Tests/AppSnapshotTests/More.swift" "$tmp/r/Tests/AppSnapshotTests/RendererTests.swift"
out=$(run); rc=$?
expect "a listed hit that is gone fails until pruned" "1" "$rc"
run --update-baseline >/dev/null
expect "pruning empties the baseline" "" "$(grep -v '^#' "$tmp/r/Tests/body-counts-baseline.txt" | paste -sd, -)"

exit $fail
