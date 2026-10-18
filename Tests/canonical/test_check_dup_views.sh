#!/usr/bin/env bash
# Tests/canonical/test_check_dup_views.sh: scripts/check-dup-views, the
# SuiteUI-first ratchet for views (docs/factory/lead.md rules 16 and 20), on
# scratch trees that use the repo's real concept and signature tables: rule A
# (name stem, adapters exempt), rule B (body signature, comments skipped),
# rule C (shape twin, across files, against SuiteUI too), the baseline that
# only shrinks, and the fast lane's --paths mode with Allow-Dup-View.
# Run: bash Tests/canonical/test_check_dup_views.sh   (exit 0 = all pass)
# bash 3.2 compatible, needs python3.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/../.."
lint="$repo/scripts/check-dup-views"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() {  # expect <name> <want> <got>
  if [[ "$3" == "$2" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fail=1; fi
}
tree() { rm -rf "$tmp/r"; mkdir -p "$tmp/r/Tests"; cp "$repo"/Tests/canonical-ui-{concepts,signatures}.txt "$tmp/r/Tests/"; }
add() { mkdir -p "$tmp/r/$(dirname "$1")"; printf '%s\n' "$2" >"$tmp/r/$1"; }
run() { python3 "$lint" --root "$tmp/r" "$@" 2>&1; }
hits() { run --update-baseline --allow-increase >/dev/null; grep -v '^#' "$tmp/r/Tests/canonical-ui-baseline.txt" | paste -sd, -; }
# busy <Name>: a 12-line busy note, the shape rule C sees as one view.
busy() { cat <<EOF
struct $1: View {
    let text: String
    var body: some View {
        GlassPanel {
            HStack(spacing: SuiteSpacing.small) {
                ProgressView().controlSize(.small)
                Text(text).font(SuiteFont.inspectorMeta)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
        }
        .accessibilityIdentifier("$1")
    }
}
EOF
}

tree
add Sources/HaloApp/HaloRenderSheet.swift $'struct HaloRenderSheet: View {\n  var body: some View { Text("x") }\n}'
add Sources/HaloApp/HaloRender+Suite.swift $'struct HaloExportSheet: View { var body: some View { Text("x") } }'
add Sources/HaloApp/Inline.swift $'struct ExportSheetAdapter: View { var body: some View { Text("x") } }\nstruct SheetModel {}\nstruct Snapshot: View { var body: some View { EmptyView() } }'
add Sources/PhotoApp/PhotoMergeNote.swift $'private struct PhotoMergeNote<T>: View, Equatable { var body: some View { EmptyView() } }'
add Sources/SuiteUI/SuiteSheet.swift $'public struct SuiteSheet: View { public var body: some View { EmptyView() } }'
expect "rule A: name stems, first concept wins, adapters, models and SuiteUI never count" \
  "A Sources/HaloApp/HaloRenderSheet.swift::HaloRenderSheet Sheet,A Sources/PhotoApp/PhotoMergeNote.swift::PhotoMergeNote BusyNote" "$(hits)"

tree
add Sources/LibraryApp/LibraryNotice.swift $'struct LibraryBanner: View {\n  var body: some View {\n    // Label("x", systemImage: "y").foregroundStyle(SuiteColor.stateError)\n    Label("Failed", systemImage: "exclamationmark.triangle").foregroundStyle(SuiteColor.stateError)\n  }\n}\nstruct LibraryQuiet: View {\n  var body: some View {\n    /* Label( SuiteColor.stateError */ Text("ok")\n  }\n}'
add Sources/FlareApp/FlareControls.swift $'private struct Key: PreferenceKey { static var defaultValue: [ControlEntry] = [] }'
expect "rule B: every regex of a signature, comments skipped, file-level signatures" \
  "B Sources/FlareApp/FlareControls.swift::* app-inventory,B Sources/LibraryApp/LibraryNotice.swift::LibraryBanner error-label" "$(hits)"

tree
add Sources/FlareApp/FlareOpen.swift "$(busy FlareOpenRow)"
add Sources/HaloApp/HaloOpen.swift "$(busy HaloOpenRow | sed 's/text/message/g')"
add Sources/HaloApp/HaloOpenToo.swift "$(busy HaloOpenRowToo)"
expect "rule C: shape twins across files, renamed variables and strings ignored" \
  "B Sources/FlareApp/FlareOpen.swift::FlareOpenRow busy-glass,B Sources/HaloApp/HaloOpen.swift::HaloOpenRow busy-glass,B Sources/HaloApp/HaloOpenToo.swift::HaloOpenRowToo busy-glass,C Sources/FlareApp/FlareOpen.swift::FlareOpenRow ~ Sources/HaloApp/HaloOpen.swift::HaloOpenRow,C Sources/FlareApp/FlareOpen.swift::FlareOpenRow ~ Sources/HaloApp/HaloOpenToo.swift::HaloOpenRowToo,C Sources/HaloApp/HaloOpen.swift::HaloOpenRow ~ Sources/HaloApp/HaloOpenToo.swift::HaloOpenRowToo" \
  "$(hits)"

tree
add Sources/SuiteUI/BusyNote.swift "$(busy BusyNote)"
add Sources/SuiteUI/Gallery/BusyPage.swift "$(busy BusyPage)"
add Sources/PhotoApp/PhotoWait.swift "$(busy PhotoWait | sed 's/GlassPanel/SurfaceCard/')"
expect "rule C: an app copy of a SuiteUI view hits, Gallery pages are not a far side" \
  "C Sources/PhotoApp/PhotoWait.swift::PhotoWait ~ Sources/SuiteUI/BusyNote.swift::BusyNote" "$(hits)"
add Sources/PhotoApp/PhotoTiny.swift $'struct PhotoTiny: View {\n  var body: some View { GlassPanel { HStack { ProgressView().controlSize(.small) } } }\n}'
expect "rule C: bodies under 10 lines never pair" "C Sources/PhotoApp/PhotoWait.swift::PhotoWait ~ Sources/SuiteUI/BusyNote.swift::BusyNote" \
  "$(hits | tr ',' '\n' | grep '^C' | paste -sd, -)"

# The ratchet: a duplicate is caught, the baseline allows it, a new one fails.
tree
add Sources/HaloApp/HaloRenderSheet.swift $'struct HaloRenderSheet: View { var body: some View { EmptyView() } }'
expect "no baseline is bad input" "2" "$(run >/dev/null; echo $?)"
expect "update writes the baseline" "check-dup-views: baseline written, 1 grandfathered hits." "$(run --update-baseline)"
expect "the baseline allows the existing duplicate" "0|ok (1 grandfathered view hits, none new)" "$(out=$(run); echo "$?|$out")"
add Sources/PhotoApp/PhotoExportSheet.swift $'struct PhotoExportSheet: View { var body: some View { EmptyView() } }'
out=$(run); rc=$?
expect "a new duplicate fails" "1|Sources/PhotoApp/PhotoExportSheet.swift::PhotoExportSheet: app-local Sheet view (new)" "$rc|$(head -1 <<<"$out")"
expect "update refuses to grow the baseline" "1" "$(run --update-baseline >/dev/null; echo $?)"
expect "update with --allow-increase grows it" "check-dup-views: baseline written, 2 grandfathered hits." "$(run --update-baseline --allow-increase)"
rm "$tmp/r/Sources/HaloApp/HaloRenderSheet.swift"
out=$(run); rc=$?
expect "a gone duplicate must leave the baseline" \
  "1|A Sources/HaloApp/HaloRenderSheet.swift::HaloRenderSheet Sheet: listed in Tests/canonical-ui-baseline.txt but no longer hits" "$rc|$(head -1 <<<"$out")"
expect "shrinking needs no flag" "check-dup-views: baseline written, 1 grandfathered hits." "$(run --update-baseline)"
expect "the shrunk tree passes" "0" "$(run >/dev/null; echo $?)"

printf '%s\n' Sources/HaloApp/HaloRenderSheet.swift Sources/PhotoApp/PhotoNoticeRow.swift \
  Sources/PhotoApp/Export+Suite.swift Sources/SuiteUI/SuiteSheet.swift Sources/PhotoModel/PhotoSheet.swift >"$tmp/paths"
lane() { printf "$1" >"$tmp/body"; python3 "$lint" --root "$tmp/r" --paths "$tmp/paths" --body "$tmp/body" | paste -sd, -; }
expect "lane: no Allow-Dup-View flags both app files" "Sources/HaloApp/HaloRenderSheet.swift (Sheet),Sources/PhotoApp/PhotoNoticeRow.swift (Notice)" "$(lane 'Closes #1\n')"
expect "lane: Allow-Dup-View with a reason clears its concept only" "Sources/PhotoApp/PhotoNoticeRow.swift (Notice)" \
  "$(lane 'Allow-Dup-View: sheet SuiteSheet lands in #900\n')"
expect "lane: Allow-Dup-View without a reason clears nothing" "Sources/HaloApp/HaloRenderSheet.swift (Sheet),Sources/PhotoApp/PhotoNoticeRow.swift (Notice)" \
  "$(lane 'Allow-Dup-View: Sheet\n')"

# The repo itself: its baseline matches its tree.
expect "the repo passes its own baseline" "0" "$(python3 "$lint" >/dev/null 2>&1; echo $?)"
exit "$fail"
