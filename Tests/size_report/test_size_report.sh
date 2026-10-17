#!/usr/bin/env bash
# Tests/size_report/test_size_report.sh: fixture test for scripts/size-report,
# the macOS job's size baseline (blueprint 7.5, packet BU-0). Copies the two
# bundle skeletons in fixture/ (FlareApp.app, DesignApp.app), builds a tiny
# executable into each with swiftc, linking a one-file module named SuiteUI so
# nm finds SuiteUI symbols, tars them, and checks:
#   - the JSON has SizeReport's keys exactly, one executable row per bundle
#     with bytes > 0, a bundle row each, the tarball row, and a suiteUISymbols
#     count >= 1 per app;
#   - with one bundle's executable removed, the script exits 1;
#   - on an AfterGlow.app fixture (BU-4: launcher, four frameworks, helpers,
#     <X>App.app symlinks) it adds the launcher, framework, helper and
#     whole-bundle rows and still counts symbols per app; a missing framework
#     exits 1.
# nm and swift demangle need Mach-O here, so off macOS it prints
# "skipped: needs macOS" and exits 0 (SIZE_REPORT_TEST_ANY_OS=1 runs it
# anyway, on whatever object format the local swiftc writes). Needs swiftc, jq.
#
# Run: bash Tests/size_report/test_size_report.sh   (exit 0 = all pass)
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
report="$here/../../scripts/size-report"

if [[ "$(uname -s)" != Darwin && -z "${SIZE_REPORT_TEST_ANY_OS:-}" ]]; then
  echo "skipped: needs macOS"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }

# A SuiteUI module with a type, a function and an inlinable generic the
# client specializes, linked into each fixture executable.
mkdir -p "$tmp/src" "$tmp/mod"
cat >"$tmp/src/SuiteUI.swift" <<'EOF'
public struct Panel { public var title: String; public init(title: String) { self.title = title } }
public func greet(_ p: Panel) -> String { "Hello, \(p.title)" }
@inlinable public func twice<T>(_ x: T) -> [T] { [x, x] }
EOF
cat >"$tmp/src/main.swift" <<'EOF'
import SuiteUI
print(greet(Panel(title: "fixture")), twice(CommandLine.arguments.count))
EOF
swiftc -parse-as-library -module-name SuiteUI -emit-module -emit-module-path "$tmp/mod/SuiteUI.swiftmodule" \
  -c "$tmp/src/SuiteUI.swift" -o "$tmp/mod/SuiteUI.o" || { echo "FAIL could not build the SuiteUI module"; exit 1; }

apps="$tmp/apps"
cp -R "$here/fixture" "$apps"
for x in Flare Design; do
  mkdir -p "$apps/${x}App.app/Contents/MacOS"
  swiftc -I "$tmp/mod" "$tmp/src/main.swift" "$tmp/mod/SuiteUI.o" -o "$apps/${x}App.app/Contents/MacOS/${x}App" \
    || { echo "FAIL could not build ${x}App"; exit 1; }
done
(cd "$apps" && tar -czf "$tmp/app-builds.tar.gz" ./*.app)

run() { APPS="Flare Design" APPS_DIR="$apps" TARBALL="$tmp/app-builds.tar.gz" OUT="$tmp/out/size-report.json" \
  COMMIT=fixture "$report" >"$tmp/stdout" 2>"$tmp/stderr"; }

run; status=$?
json="$tmp/out/size-report.json"
check "exits 0 on the fixture" '[[ $status == 0 ]]'
check "keys are SizeReport's exactly" \
  '[[ $(jq -c "keys" "$json") == "[\"commit\",\"entries\",\"suiteUISymbols\"]" ]] && [[ $(jq -c "[.entries[] | keys] | unique" "$json") == "[[\"bytes\",\"kind\",\"name\"]]" ]]'
for x in Flare Design; do
  check "one $x executable row with bytes > 0" \
    "[[ \$(jq '[.entries[] | select(.name == \"$x\" and .kind == \"executable\" and .bytes > 0)] | length' \"\$json\") == 1 ]]"
  check "one ${x}App.app bundle row with bytes > 0" \
    "[[ \$(jq '[.entries[] | select(.name == \"${x}App.app\" and .kind == \"appBundle\" and .bytes > 0)] | length' \"\$json\") == 1 ]]"
  check "a suiteUISymbols count for $x" "jq -e '.suiteUISymbols.$x | type == \"number\" and . >= 1' \"\$json\" >/dev/null"
done
check "one tarball row with bytes > 0" \
  "[[ \$(jq '[.entries[] | select(.kind == \"tarball\" and .bytes > 0)] | length' \"\$json\") == 1 ]]"
check "prints the markdown table" 'grep -q "^| Flare | executable |" "$tmp/stdout"'

# AfterGlow.app (BU-4): launcher, four frameworks, two helpers, the old
# <X>App.app paths as symlinks into it.
suite="$tmp/suite"
ag="$suite/AfterGlow.app"
mkdir -p "$ag/Contents/MacOS"
cp "$apps/FlareApp.app/Contents/MacOS/FlareApp" "$ag/Contents/MacOS/AfterGlow"
for f in SuiteUI SuiteModel SuiteShell CreativeEngines; do
  mkdir -p "$ag/Contents/Frameworks/$f.framework/Versions/A"
  printf 'fixture %s\n' "$f" >"$ag/Contents/Frameworks/$f.framework/Versions/A/$f"
  ln -s A "$ag/Contents/Frameworks/$f.framework/Versions/Current"
done
for x in Flare Design; do
  mkdir -p "$ag/Contents/Helpers/$x.app/Contents/MacOS"
  cp "$apps/${x}App.app/Contents/MacOS/${x}App" "$ag/Contents/Helpers/$x.app/Contents/MacOS/$x"
  ln -s "AfterGlow.app/Contents/Helpers/$x.app" "$suite/${x}App.app"
done
(cd "$suite" && tar -czf "$tmp/suite.tar.gz" ./*.app)
srun() { APPS="Flare Design" APPS_DIR="$suite" TARBALL="$tmp/suite.tar.gz" OUT="$tmp/out/suite.json" \
  COMMIT=fixture "$report" >"$tmp/stdout" 2>"$tmp/stderr"; }
srun; status=$?
sjson="$tmp/out/suite.json"
check "AfterGlow.app: exits 0" '[[ $status == 0 ]]'
check "AfterGlow.app: one launcher row" \
  "[[ \$(jq '[.entries[] | select(.name == \"AfterGlow\" and .kind == \"executable\" and .bytes > 0)] | length' \"\$sjson\") == 1 ]]"
check "AfterGlow.app: four framework rows, Versions/Current not counted twice" \
  "[[ \$(jq -c '[.entries[] | select(.kind == \"framework\") | .name] | sort' \"\$sjson\") == '[\"CreativeEngines.framework\",\"SuiteModel.framework\",\"SuiteShell.framework\",\"SuiteUI.framework\"]' ]] && [[ \$(jq '.entries[] | select(.name == \"SuiteUI.framework\") | .bytes' \"\$sjson\") == 16 ]]"
check "AfterGlow.app: helper rows Flare.app and Design.app" \
  "[[ \$(jq -c '[.entries[] | select(.kind == \"appBundle\") | .name] | sort' \"\$sjson\") == '[\"Design.app\",\"Flare.app\"]' ]]"
check "AfterGlow.app: one whole-bundle row" \
  "[[ \$(jq '[.entries[] | select(.name == \"AfterGlow.app\" and .kind == \"wholeBundle\" and .bytes > 0)] | length' \"\$sjson\") == 1 ]]"
check "AfterGlow.app: helper executables measured, symbols per app" \
  "[[ \$(jq '[.entries[] | select(.kind == \"executable\" and .bytes > 0)] | length' \"\$sjson\") == 3 ]] && jq -e '.suiteUISymbols | (keys == [\"Design\",\"Flare\"]) and .Flare >= 1 and .Design >= 1' \"\$sjson\" >/dev/null"
check "AfterGlow.app: the table prints no null" '! grep -q null "$tmp/stdout"'
rm -rf "$ag/Contents/Frameworks/SuiteShell.framework"
srun; status=$?
check "AfterGlow.app: a missing framework exits 1" '[[ $status == 1 ]] && grep -q "missing framework" "$tmp/stderr"'

rm "$apps/DesignApp.app/Contents/MacOS/DesignApp"
run; status=$?
check "a missing executable exits 1" '[[ $status == 1 ]] && grep -q "missing executable" "$tmp/stderr"'
rm -rf "$apps/DesignApp.app"
run; status=$?
check "a missing bundle exits 1" '[[ $status == 1 ]] && grep -q "missing bundle" "$tmp/stderr"'

if [[ $fail != 0 ]]; then
  echo "--- stdout"; cat "$tmp/stdout"; echo "--- stderr"; cat "$tmp/stderr"
fi
exit "$fail"
