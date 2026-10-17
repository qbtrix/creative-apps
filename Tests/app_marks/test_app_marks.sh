#!/usr/bin/env bash
# Tests/app_marks/test_app_marks.sh: the app-mark scripts on scratch trees.
# scripts/check-app-marks: each rule (symbol table, switcher systemImage:,
# retired name beside an app), what passes (a title table, a tool symbol that
# names no app, comments, AppMark.swift itself), the baseline that only
# shrinks, and the PNG/SVG twins. scripts/render-marks --check on a copy of
# the repo's marks: clean passes; an edited SVG, a changed PNG and a stale
# AppMarkArt.swift fail; an SVG element it can't read is bad input.
# Run: bash Tests/app_marks/test_app_marks.sh   (exit 0 = all pass)
# bash 3.2 compatible, needs python3.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/../.."
check="$repo/scripts/check-app-marks"
render="$repo/scripts/render-marks"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() {  # expect <name> <want> <got>
  if [[ "$3" == "$2" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fail=1; fi
}
tree() { rm -rf "$tmp/r"; mkdir -p "$tmp/r/Sources" "$tmp/r/Tests"; }
add() { mkdir -p "$tmp/r/$(dirname "$1")"; printf '%s\n' "$2" >"$tmp/r/$1"; }
run() { python3 "$check" --root "$tmp/r" "$@" 2>&1; }
# hits: each Sources hit as path:line:rule, sorted, joined by "|".
hits() { run | grep -E '^Sources/' | sed -E 's/^([^:]+:[0-9]+): ([a-z]+):.*/\1:\2/' | sort | paste -sd'|' -; }

tree
add Sources/AApp/Rows.swift 'let symbols: [SuiteApp: String] = [.flare: "scribble.variable"]'
expect "a symbol table fails, and its retired value" \
  "Sources/AApp/Rows.swift:1:retired|Sources/AApp/Rows.swift:1:table" "$(hits)"
tree
add Sources/AApp/Icons.swift $'static let icons: [SuiteApp: String] = [\n  .flare: "sparkle.magnifyingglass",\n]'
expect "a table named icons with a dotted symbol fails" "1" "$(run >/dev/null; echo $?)"
tree
add Sources/SuiteModel/Titles.swift 'public static let titles: [SuiteApp: String] = [.flare: "New Animation", .photo: "New Image"]'
expect "a title table passes" "0" "$(run >/dev/null; echo $?)"
tree
add Sources/SuiteUI/Switcher.swift $'let items = [\n  AppSwitcherItem(id: "x", title: "X",\n                  systemImage: "star", shortcut: "1"),\n]'
expect "a switcher item with systemImage: fails at its call" "Sources/SuiteUI/Switcher.swift:2: switcher: AppSwitcherItem takes app:, not systemImage:" \
  "$(run | grep -E '^Sources')"
tree
add Sources/HaloApp/Row.swift 'SidebarItem(id: "h", title: "Halo", systemImage: "film")'
add Sources/AApp/Home.swift 'SidebarItem(id: home, title: "Home", systemImage: "house")'
add Sources/PhotoApp/Tool.swift 'case .brush: "paintbrush.pointed"'
add Sources/FlareApp/Scene.swift 'self.init(id: scene.id, title: scene.name, systemImage: "film")'
add Sources/SuiteUI/Note.swift '// The switcher once used "flame" for .flare.'
add Sources/SuiteUI/AppMark.swift 'let old: [SuiteApp: String] = [.flare: "flame"]'
expect "a retired name beside an app's name fails; tools, scenes, comments and AppMark.swift pass" \
  "Sources/AApp/Home.swift:1:retired|Sources/HaloApp/Row.swift:1:retired" "$(hits)"

tree
add Sources/AApp/Old.swift 'let s: [SuiteApp: String] = [.halo: "film.stack"]'
expect "the first update writes the baseline" "check-app-marks: baseline written, 1 grandfathered files." "$(run --update-baseline)"
expect "a listed file passes" "0" "$(run >/dev/null; echo $?)"
add Sources/BApp/New.swift 'let s: [SuiteApp: String] = [.flare: "flame"]'
expect "a new file fails" "1" "$(run >/dev/null; echo $?)"
expect "update refuses to grow the baseline" "1" "$(run --update-baseline >/dev/null 2>&1; echo $?)"
rm "$tmp/r/Sources/BApp/New.swift"
add Sources/AApp/Old.swift 'let s = AppMark(app: .halo)'
expect "a listed file that moved to AppMark asks to prune" \
  "Sources/AApp/Old.swift: listed in Tests/app-marks-baseline.txt but draws no old mark now" "$(run | head -1)"
expect "update prunes it" "check-app-marks: baseline written, 0 grandfathered files." "$(run --update-baseline)"

tree
mkdir -p "$tmp/r/Bundle/Icons" "$tmp/r/Bundle/Marks"
: >"$tmp/r/Bundle/Marks/Flare.svg"; : >"$tmp/r/Bundle/Icons/Flare.png"; : >"$tmp/r/Bundle/Icons/Flare-16.png"
expect "an SVG with its PNGs passes" "0" "$(run >/dev/null; echo $?)"
: >"$tmp/r/Bundle/Icons/Halo-32.png"; : >"$tmp/r/Bundle/Marks/Photo.svg"
expect "a PNG without its SVG, and an SVG without its PNG, fail" \
  "Bundle/Icons/Halo-32.png: no Bundle/Marks/Halo.svg renders it|Bundle/Marks/Photo.svg: no Bundle/Icons/Photo.png; run scripts/render-marks" \
  "$(run | grep -E '^Bundle' | paste -sd'|' -)"

# render-marks --check on a copy of the repo's marks, icons and generated art.
rm -rf "$tmp/m"; mkdir -p "$tmp/m/Bundle" "$tmp/m/Sources/SuiteUI"
cp -R "$repo/Bundle/Marks" "$repo/Bundle/Icons" "$tmp/m/Bundle/"
cp "$repo/Sources/SuiteUI/AppMarkArt.swift" "$tmp/m/Sources/SuiteUI/"
mcheck() { python3 "$render" --root "$tmp/m" --check 2>&1; }
expect "the repo's marks are current" "0" "$(mcheck >/dev/null; echo $?)"
printf '<!-- edited -->\n' >>"$tmp/m/Bundle/Marks/Halo.svg"
expect "an SVG edited without a rerender fails" "Bundle/Marks/Halo.svg changed since its PNGs were rendered" "$(mcheck | head -1)"
cp "$repo/Bundle/Marks/Halo.svg" "$tmp/m/Bundle/Marks/Halo.svg"
printf 'x' >>"$tmp/m/Bundle/Icons/Photo-16.png"
expect "a changed PNG fails" "Bundle/Icons/Photo-16.png is not the render marks.json records" "$(mcheck | head -1)"
cp "$repo/Bundle/Icons/Photo-16.png" "$tmp/m/Bundle/Icons/Photo-16.png"
printf '// hand edit\n' >>"$tmp/m/Sources/SuiteUI/AppMarkArt.swift"
expect "a hand-edited AppMarkArt.swift fails" "Sources/SuiteUI/AppMarkArt.swift is not what Bundle/Marks gives" "$(mcheck | head -1)"
cp "$repo/Sources/SuiteUI/AppMarkArt.swift" "$tmp/m/Sources/SuiteUI/"
sed -i.bak 's#<g id="flare-line"#<g id="flare-line"><polygon points="0,0 1,1 2,0"/></g><g id="unused"#' "$tmp/m/Bundle/Marks/Flare.svg"
expect "an element it can't read is bad input" "2" "$(mcheck >/dev/null; echo $?)"

exit $fail
