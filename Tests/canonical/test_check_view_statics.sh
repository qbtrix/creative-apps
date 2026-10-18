#!/usr/bin/env bash
# Tests/canonical/test_check_view_statics.sh: scripts/check-view-statics, the
# "Statics on Views" ratchet (docs/engineering/swiftui-rules.md), on scratch trees:
# an unmarked static on a View is caught, `nonisolated`, `@MainActor` and the
# `// view-static: main-actor` opt-out pass, non-View types, nested non-View types,
# where clauses and `static let` never count, an extension of a View counts, and the
# baseline allows existing hits but only shrinks.
# Run: bash Tests/canonical/test_check_view_statics.sh   (exit 0 = all pass)
# bash 3.2 compatible, needs python3.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/../.."
lint="$repo/scripts/check-view-statics"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() {  # expect <name> <want> <got>
  if [[ "$3" == "$2" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fail=1; fi
}
tree() { rm -rf "$tmp/r"; mkdir -p "$tmp/r/Tests"; }
add() { mkdir -p "$tmp/r/$(dirname "$1")"; printf '%s\n' "$2" >"$tmp/r/$1"; }
run() { python3 "$lint" --root "$tmp/r" "$@" 2>&1; }
hits() { run --update-baseline --allow-increase >/dev/null; grep -v '^#' "$tmp/r/Tests/view-statics-baseline.txt" | paste -sd, -; }

tree
add Sources/HaloApp/Bad.swift $'struct Bad: View {\n  static func pure(_ x: Int) -> Int { x }\n  static var count = 0\n  var body: some View { Text("x") }\n}'
expect "an unmarked static func and var on a View are caught" \
  "Sources/HaloApp/Bad.swift::Bad.count,Sources/HaloApp/Bad.swift::Bad.pure" "$(hits)"

tree
add Sources/SuiteUI/Good.swift $'public struct Good: View {\n  public nonisolated static func a() -> Int { 1 }\n  nonisolated(unsafe) static var b = 0\n  nonisolated\n  static func c() {}\n  @MainActor static func d() {}\n  @MainActor\n  static func e() {}\n  // view-static: main-actor\n  static func f() {}\n  // view-static: main-actor\n  @inline(__always)\n  static func g() {}\n  static let h = 1\n  var body: some View { Text("x") }\n}'
expect "nonisolated, @MainActor, the opt-out comment and static let pass" "" "$(hits)"

tree
add Sources/SuiteUI/Elsewhere.swift $'struct Model { static func a() {} }\nenum Kind: Hashable { static var b = 0 }\nstruct Wrap<C>: Equatable where C: View { static func c() {} }\nstruct Mod: ViewModifier { static func d() {} }\nstruct Rep: NSViewRepresentable { static func e() {} }\n// struct Gone: View { static func f() {} }\nlet s = "struct Gone: View { static func g() {} }"'
expect "non-View types, where clauses, ViewModifier, comments and strings never count" "" "$(hits)"

tree
add Sources/PhotoApp/Nest.swift $'struct Nest: View {\n  struct Key: PreferenceKey { static var defaultValue = 0 }\n  func go() { let f = { (x: Int) in x }; _ = f(1) }\n  static func after() {}\n  var body: some View { Text("x") }\n}'
expect "a nested non-View type is skipped, a View static after it is still caught" "Sources/PhotoApp/Nest.swift::Nest.after" "$(hits)"

tree
add Sources/FlareApp/Ext.swift $'struct Panel: View { var body: some View { EmptyView() } }'
add Sources/FlareApp/Panel+Help.swift $'extension Panel {\n  static func help() -> String { "x" }\n  nonisolated static func ok() {}\n}\nextension Other { static func fine() {} }'
add Sources/FlareApp/Multi.swift $'final class Box: ObservableObject, View, Equatable {\n  static func x() {}\n  var body: some View { EmptyView() }\n}'
expect "an extension of a View counts, one of a non-View and View in a list are handled" \
  "Sources/FlareApp/Multi.swift::Box.x,Sources/FlareApp/Panel+Help.swift::Panel.help" "$(hits)"

tree
add Sources/Model/Out.swift $'struct Out: View { static func a() {} }'
add Sources/HaloModel/Out.swift $'struct Out: View { static func a() {} }'
expect "only Sources/SuiteUI and Sources/*App are scanned" "" "$(hits)"

# The ratchet: a hit is caught, the baseline allows it, a new one fails.
tree
add Sources/HaloApp/Old.swift $'struct Old: View { static func a() {} }'
expect "no baseline is bad input" "2" "$(run >/dev/null; echo $?)"
expect "update writes the baseline" "check-view-statics: baseline written, 1 grandfathered hits." "$(run --update-baseline)"
expect "the baseline allows the existing hit" "0|ok (1 grandfathered view statics, none new)" "$(out=$(run); echo "$?|$out")"
add Sources/HaloApp/New.swift $'struct New: View { static func b() {} }'
out=$(run); rc=$?
expect "a new hit fails" "1|Sources/HaloApp/New.swift::New.b: static on a View is @MainActor, a worker-thread @Test traps (new)" "$rc|$(head -1 <<<"$out")"
expect "update refuses to grow the baseline" "1" "$(run --update-baseline >/dev/null; echo $?)"
add Sources/HaloApp/New.swift $'struct New: View { nonisolated static func b() {} }'
expect "marking it nonisolated passes again" "0" "$(run >/dev/null; echo $?)"
add Sources/HaloApp/Old.swift $'struct Old: View { nonisolated static func a() {} }'
out=$(run); rc=$?
expect "a fixed hit must leave the baseline" \
  "1|Sources/HaloApp/Old.swift::Old.a: listed in Tests/view-statics-baseline.txt but no longer hits" "$rc|$(head -1 <<<"$out")"
expect "shrinking needs no flag" "check-view-statics: baseline written, 0 grandfathered hits." "$(run --update-baseline)"

# The repo itself: its baseline matches its tree.
expect "the repo passes its own baseline" "0" "$(python3 "$lint" >/dev/null 2>&1; echo $?)"
exit "$fail"
