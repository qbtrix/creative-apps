#!/usr/bin/env bash
# Tests/canonical/test_check_app_local_surfaces.sh: scripts/check-app-local-surfaces, the
# "no AppKit surface or tab control in an app" ratchet (docs/engineering/swiftui-rules.md
# rules 5 and 12), on scratch trees: a new app-local NSOutlineView fails, the same file in
# SuiteUI or SuiteShell passes, comments and strings never count, a baselined hit passes,
# and a stale baseline line fails.
# Run: bash Tests/canonical/test_check_app_local_surfaces.sh   (exit 0 = all pass)
# bash 3.2 compatible, needs python3.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lint="$here/../../scripts/check-app-local-surfaces"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() {  # expect <name> <want> <got>
  if [[ "$3" == "$2" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fail=1; fi
}
tree() { rm -rf "$tmp/r"; mkdir -p "$tmp/r/Tests"; }
add() { mkdir -p "$tmp/r/$(dirname "$1")"; printf '%s\n' "$2" >"$tmp/r/$1"; }
run() { python3 "$lint" --root "$tmp/r" "$@" 2>&1; }
hits() { run --update-baseline --allow-increase >/dev/null; grep -v '^#' "$tmp/r/Tests/app-local-surfaces-baseline.txt" | paste -sd, -; }

tree
add Sources/HaloApp/Bad.swift $'import AppKit\nstruct Bad: NSViewRepresentable { let v = NSOutlineView() }\nlet t = TabView { }\nlet p = Picker("x", selection: $s) { }.pickerStyle(.segmented)'
expect "every listed token is caught, once per file" \
  "Sources/HaloApp/Bad.swift: .pickerStyle(.segmented),Sources/HaloApp/Bad.swift: NSOutlineView,Sources/HaloApp/Bad.swift: NSViewRepresentable,Sources/HaloApp/Bad.swift: TabView" "$(hits)"

tree
add Sources/SuiteUI/Host.swift $'struct H: NSViewRepresentable { let v = NSOutlineView() }'
add Sources/SuiteShell/Win.swift $'struct W: NSViewRepresentable {}'
add Sources/HaloModel/M.swift $'let v = NSTableView()'
expect "SuiteUI, SuiteShell and non-App targets are not scanned" "" "$(hits)"

tree
add Sources/PhotoApp/Quiet.swift $'// NSOutlineView is in SuiteUI\nlet s = "NSTabView"\nlet a = MyTabView()\nlet b = SidebarNSTableView()\nlet c = other.TabView'
expect "comments, strings and longer identifiers never count" "" "$(hits)"

tree
add Sources/HaloApp/Old.swift $'let v = NSOutlineView()'
expect "no baseline is bad input" "2" "$(run >/dev/null; echo $?)"
expect "update writes the baseline" "check-app-local-surfaces: baseline written, 1 grandfathered hits." "$(run --update-baseline)"
expect "a baselined hit passes" "0|ok (1 grandfathered app-local surfaces, none new)" "$(out=$(run); echo "$?|$out")"
add Sources/FlareApp/New.swift $'let v = NSOutlineView()'
out=$(run); rc=$?
expect "a new app-local NSOutlineView fails" "1|Sources/FlareApp/New.swift: NSOutlineView: app-local surface (new)" "$rc|$(head -1 <<<"$out")"
expect "the message names the rules and the SuiteUI hosts" "3" "$(grep -o 'rules 5 and 12\|CanvasHost\|SegmentedTabs' <<<"$out" | wc -l | tr -d ' ')"
expect "update refuses to grow the baseline" "1" "$(run --update-baseline >/dev/null; echo $?)"
rm "$tmp/r/Sources/FlareApp/New.swift"
add Sources/HaloApp/Old.swift $'let v = 1'
out=$(run); rc=$?
expect "a stale baseline line fails" \
  "1|Sources/HaloApp/Old.swift: NSOutlineView: listed in Tests/app-local-surfaces-baseline.txt but no longer hits" "$rc|$(head -1 <<<"$out")"
expect "shrinking needs no flag" "check-app-local-surfaces: baseline written, 0 grandfathered hits." "$(run --update-baseline)"

exit "$fail"
