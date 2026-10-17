#!/usr/bin/env bash
# Tests/canonical/test_check_dup_logic.sh: scripts/check-dup-logic, the
# canonical-first ratchet (docs/factory/lead.md rule 20), on scratch trees that
# use the repo's real Tests/canonical-concepts.txt: stem matching by name and
# by primary type, the adapter exemption, the SuiteModel exclusion, the
# baseline that only shrinks, and the fast lane's --paths mode with Allow-Dup.
# Run: bash Tests/canonical/test_check_dup_logic.sh   (exit 0 = all pass)
# bash 3.2 compatible, needs python3.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/../.."
lint="$repo/scripts/check-dup-logic"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() {  # expect <name> <want> <got>
  if [[ "$3" == "$2" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fail=1; fi
}
# tree: a fresh scratch repo with the real concepts file and no baseline.
tree() { rm -rf "$tmp/r"; mkdir -p "$tmp/r/Tests"; cp "$repo/Tests/canonical-concepts.txt" "$tmp/r/Tests/"; }
# add <path> [<swift line>]: one source file in the tree.
add() { mkdir -p "$tmp/r/$(dirname "$1")"; printf '%s\n' "${2:-// empty}" >"$tmp/r/$1"; }
run() { python3 "$lint" --root "$tmp/r" "$@" 2>&1; }
# concept_files <path>...: the paths the --paths mode flags (no body), joined by ",".
concept_files() { printf '%s\n' "$@" >"$tmp/paths"; python3 "$lint" --root "$tmp/r" --paths "$tmp/paths" | paste -sd, -; }

tree
expect "matches by name, with inflections and CamelCase boundaries" \
  "Sources/PhotoModel/PhotoUndoStack.swift (Undo),Sources/FlareModel/Fakes/FakeKeyframes.swift (Keyframe),Sources/LibraryModel/Live/LiveExporter.swift (Export),Sources/DesignModel/Live/LiveTransforming.swift (Transform),Sources/FlareApp/FlareWindow+Layers.swift (Layers),Sources/HaloModel/HaloSnapGuides.swift (Snap),Sources/HaloModel/HaloBones.swift (Bones),Sources/HaloModel/HaloParenting.swift (Parent)" \
  "$(concept_files Sources/PhotoModel/PhotoUndoStack.swift Sources/FlareModel/Fakes/FakeKeyframes.swift \
      Sources/LibraryModel/Live/LiveExporter.swift Sources/DesignModel/Live/LiveTransforming.swift \
      Sources/FlareApp/FlareWindow+Layers.swift Sources/HaloModel/HaloSnapGuides.swift \
      Sources/HaloModel/HaloBones.swift Sources/HaloModel/HaloParenting.swift)"
expect "no match: Snapshot is not Snap, Layer is not Layers, Undoable is not Undo" "" \
  "$(concept_files Sources/PhotoApp/PhotoSnapshotView.swift Sources/DesignModel/DesignLayer.swift \
      Sources/HaloModel/Undoable.swift Sources/FlareModel/Cropless.swift)"
expect "adapters, SuiteModel, SuiteUI, tests and non-Swift files never count" "" \
  "$(concept_files Sources/PhotoModel/PhotoHistory+Kernel.swift Sources/DesignModel/SelectionAdapter.swift \
      Sources/SuiteModel/History/History.swift Sources/SuiteUI/SelectionRing.swift \
      Tests/PhotoModelTests/PhotoHistoryTests.swift Sources/PhotoModel/History.md)"

tree
add Sources/PhotoModel/PhotoHistory.swift 'public struct PhotoHistory {}'
add Sources/PhotoModel/PhotoDocument.swift 'public struct PhotoDocument {}'
expect "update writes the baseline" "check-dup-logic: baseline written, 1 grandfathered files." "$(run --update-baseline)"
expect "the baseline lists the concept file" "Sources/PhotoModel/PhotoHistory.swift" "$(grep -v '^#' "$tmp/r/Tests/canonical-baseline.txt")"
expect "a clean tree passes" "ok (1 grandfathered concept files, none new)" "$(run)"

add Sources/HaloModel/HaloMarquee.swift 'struct HaloMarquee {}'
out=$(run); rc=$?
expect "a new concept file fails" "1|Sources/HaloModel/HaloMarquee.swift: new app-local Marquee logic" "$rc|$(head -1 <<<"$out")"
expect "update refuses to grow the baseline" "1" "$(run --update-baseline >/dev/null; echo $?)"
expect "update with --allow-increase grows it" "check-dup-logic: baseline written, 2 grandfathered files." "$(run --update-baseline --allow-increase)"
rm "$tmp/r/Sources/HaloModel/HaloMarquee.swift"

add Sources/DesignApp/Canvas/Overlay.swift $'// struct UndoNote is a comment, not a type\n@MainActor public final class SelectionOverlayModel {}'
expect "matches by primary type, comments skipped" "Sources/DesignApp/Canvas/Overlay.swift: new app-local Selection logic" "$(run | head -1)"
rm "$tmp/r/Sources/DesignApp/Canvas/Overlay.swift"
add Sources/DesignApp/Canvas/Overlay+Kernel.swift 'struct SelectionOverlay {}'
add Sources/SuiteModel/Selection/Selection.swift 'public struct Selection {}'

out=$(run); rc=$?
expect "a removed file must leave the baseline" "1|Sources/HaloModel/HaloMarquee.swift: listed in Tests/canonical-baseline.txt but no longer a concept file" \
  "$rc|$(head -1 <<<"$out")"
expect "shrinking needs no flag" "check-dup-logic: baseline written, 1 grandfathered files." "$(run --update-baseline)"
expect "adapters and SuiteModel pass" "ok (1 grandfathered concept files, none new)" "$(run)"

printf '%s\n' Sources/HaloModel/HaloMarquee.swift Sources/PhotoApp/CropTool.swift Sources/PhotoModel/PhotoDocument.swift >"$tmp/paths"
lane() { printf "$1" >"$tmp/body"; python3 "$lint" --root "$tmp/r" --paths "$tmp/paths" --body "$tmp/body" | paste -sd, -; }
expect "lane: no Allow-Dup flags both" "Sources/HaloModel/HaloMarquee.swift (Marquee),Sources/PhotoApp/CropTool.swift (Crop)" "$(lane 'Closes #1\n')"
expect "lane: Allow-Dup with a reason clears its concept only" "Sources/PhotoApp/CropTool.swift (Crop)" \
  "$(lane 'Closes #1\nAllow-Dup: marquee the kernel lands next week, #900\n')"
expect "lane: Allow-Dup without a reason clears nothing" "Sources/HaloModel/HaloMarquee.swift (Marquee),Sources/PhotoApp/CropTool.swift (Crop)" \
  "$(lane 'Allow-Dup: Marquee\nAllow-Dup: Crop   \n')"
expect "lane: exit 1 on a hit, 0 when clear" "1,0" \
  "$(lane '' >/dev/null; python3 "$lint" --root "$tmp/r" --paths "$tmp/paths" >/dev/null; a=$?
     printf '%s\n' Sources/PhotoModel/PhotoDocument.swift >"$tmp/paths"; python3 "$lint" --root "$tmp/r" --paths "$tmp/paths" >/dev/null; echo "$a,$?")"

# The repo itself: its baseline matches its tree.
expect "the repo passes its own baseline" "0" "$(python3 "$lint" >/dev/null 2>&1; echo $?)"
exit "$fail"
