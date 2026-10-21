#!/usr/bin/env bash
# Tests/canonical/test_check_render_contract.sh: scripts/check-render-contract, the
# render contract's lint (docs/render-contract.md), on scratch trees: each offscreen
# pattern is caught in a canvas or overlay view and only there, the allow escape needs a
# reason, comments and strings never count, a GPU-route `return nil` (by return type or
# the gpu-route marker) and a dispatcher readback are caught unless marked with a
# registered cpu-op, and the baseline allows existing hits but only shrinks.
# Run: bash Tests/canonical/test_check_render_contract.sh   (exit 0 = all pass)
# bash 3.2 compatible, needs python3.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$here/../.."
lint="$repo/scripts/check-render-contract"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
expect() {  # expect <name> <want> <got>
  if [[ "$3" == "$2" ]]; then echo "ok   $1"; else printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3"; fail=1; fi
}
tree() { rm -rf "$tmp/r"; mkdir -p "$tmp/r/Tests"; printf 'blur-x  a test op  #1\n' >"$tmp/r/Tests/render-cpu-ops.txt"; }
add() { mkdir -p "$tmp/r/$(dirname "$1")"; printf '%s\n' "$2" >"$tmp/r/$1"; }
run() { python3 "$lint" --root "$tmp/r" "$@" 2>&1; }
hits() { run --update-baseline --allow-increase >/dev/null; grep -v '^#' "$tmp/r/Tests/render-contract-baseline.txt" | paste -sd, -; }

tree
add Sources/FlareApp/FlareStage.swift $'// .drawingGroup() in a comment\nstruct Art: View {\n  var body: some View {\n    Canvas { c, s in }.drawingGroup()\n  }\n}\nstruct Board: View {\n  var body: some View { Rectangle().fill(ImagePaint(image: i)).compositingGroup() }\n}\nlet s = "Canvas { }"'
expect "each offscreen pattern in a canvas view is caught, comments and strings are not" \
  "Sources/FlareApp/FlareStage.swift::Art.Canvas,Sources/FlareApp/FlareStage.swift::Art.drawingGroup,Sources/FlareApp/FlareStage.swift::Board.ImagePaint,Sources/FlareApp/FlareStage.swift::Board.compositingGroup" "$(hits)"

tree
add Sources/HaloApp/HaloViewerCanvas.swift $'struct V: View {\n  var body: some View {\n    SwiftUI.Canvas(opaque: false) { c, s in }\n    Thumb().drawingGroup() // render-contract: allow 24 pt badge, viewport-bounded\n    Thumb().drawingGroup() // render-contract: allow\n  }\n}'
expect "SwiftUI.Canvas( counts, allow with a reason passes, allow without one does not" \
  "Sources/HaloApp/HaloViewerCanvas.swift::V.Canvas,Sources/HaloApp/HaloViewerCanvas.swift::V.drawingGroup" "$(hits)"

tree
add Sources/SuiteUI/Ruler.swift $'struct Ruler: View { var body: some View { Canvas { c, s in }.drawingGroup() } }'
add Sources/SuiteUI/AppMark.swift $'struct AppMark: View { var body: some View { Canvas { c, s in } } }'
add Sources/SuiteUI/Gallery/GalleryAppMarks.swift $'struct M: View { var body: some View { Canvas { c, s in } } }'
add Sources/AfterGlowApp/HomeCanvas.swift $'struct H: View { var body: some View { Canvas { c, s in } } }'
add Sources/PhotoModel/PhotoCanvas.swift $'struct TileCanvas { func f() { _ = MyCanvas(x) } }'
expect "controls, app marks, non-canvas apps, Models and other Canvas names are out of scope" "" "$(hits)"

tree
add Sources/PhotoApp/PhotoEditor.swift $'// render-contract: canvas-view\nstruct E: View { var body: some View { Color.clear.drawingGroup() } }'
add Sources/SuiteUI/CanvasCheckerboard.swift $'struct C: View { var body: some View { Rectangle().fill(ImagePaint(image: i)) } }'
add Sources/LibraryApp/LibraryLoupe.swift $'struct L: View { var body: some View { Img().compositingGroup() } }'
expect "the canvas-view marker opts a file in; SuiteUI Canvas* and Loupe files are in scope" \
  "Sources/LibraryApp/LibraryLoupe.swift::L.compositingGroup,Sources/PhotoApp/PhotoEditor.swift::E.drawingGroup,Sources/SuiteUI/CanvasCheckerboard.swift::C.ImagePaint" "$(hits)"

tree
add Sources/PhotoModel/PhotoRenderRoute.swift $'protocol P {\n  func need() -> RenderSurface?\n}\nextension W {\n  func gpu(_ r: Rect) throws\n    -> RenderSurface?\n  {\n    guard ok else { return nil }\n    let xs = items.compactMap { x -> Int? in return nil }\n    guard blur else { return nil } // render-contract: cpu-op blur-x\n    guard mask else { return nil } // render-contract: cpu-op mask-z\n    return s\n  }\n  func other() -> Int? { return nil }\n  var tiles: ResidentSurfaces? { return nil }\n}'
add Sources/PhotoModel/PhotoLayers.swift $'func gpu() -> RenderSurface? { return nil }'
add Sources/PhotoModel/PhotoLiveTone.swift $'// render-contract: gpu-route\n@inline(__always)\nfunc plan() -> Plan? {\n  guard ok else { return nil }\n  return p\n}\n// render-contract: gpu-route\nvar x = 1\nfunc after() -> Plan? { return nil }'
expect "a GPU-route return nil is caught in any file (closures too), the gpu-route marker opts a func in, a registered cpu-op passes, an unknown one fails, other funcs are not scanned" \
  "Sources/PhotoModel/PhotoLayers.swift::gpu.gpu-nil,Sources/PhotoModel/PhotoLiveTone.swift::plan.gpu-nil,Sources/PhotoModel/PhotoRenderRoute.swift::gpu.gpu-nil,Sources/PhotoModel/PhotoRenderRoute.swift::gpu.gpu-nil,Sources/PhotoModel/PhotoRenderRoute.swift::gpu.gpu-nil" "$(hits)"
expect "the unknown cpu-op says so" \
  "Sources/PhotoModel/PhotoRenderRoute.swift:11: gpu.gpu-nil: cpu-op \`mask-z\` is not in Tests/render-cpu-ops.txt (new)" \
  "$(rm -f "$tmp/r/Tests/render-contract-baseline.txt"; run --update-baseline >/dev/null; printf '' >"$tmp/r/Tests/render-contract-baseline.txt"; run | grep mask-z)"

tree
add Sources/PhotoModel/PhotoRenderRoute.swift $'func a() { let p = dispatcher.read(s) }\nfunc b() { let p = dispatcher.read(s) } // render-contract: cpu-op blur-x\nfunc c() { let p = d.dispatcher.read(s) } // render-contract: allow eyedropper samples one pixel\nfunc d() { let p = store.read(f) }'
add Sources/DesignApp/DesignExport.swift $'func e() { let p = renderDispatcher.read(s) }'
expect "a dispatcher readback anywhere is caught unless registered or allowed; other .read( calls are not" \
  "Sources/DesignApp/DesignExport.swift::e.readback,Sources/PhotoModel/PhotoRenderRoute.swift::a.readback" "$(hits)"

# The ratchet: a hit is caught, the baseline allows it, a new one fails.
tree
add Sources/FlareApp/FlareStage.swift $'struct Old: View { var body: some View { Canvas { c, s in } } }'
expect "no baseline is bad input" "2" "$(run >/dev/null; echo $?)"
expect "update writes the baseline" "check-render-contract: baseline written, 1 grandfathered hits." "$(run --update-baseline)"
expect "the baseline allows the existing hit" "0|ok (1 grandfathered render-contract hits, none new)" "$(out=$(run); echo "$?|$out")"
add Sources/FlareApp/FlareStage.swift $'struct Old: View { var body: some View { Canvas { c, s in }; Canvas { c, s in } } }'
out=$(run); rc=$?
expect "a second hit with the same key fails" \
  "1|Sources/FlareApp/FlareStage.swift:1: Old.Canvas: SwiftUI Canvas over the canvas rasterizes on the CPU; draw it in the CALayer/Metal canvas (new)" "$rc|$(head -1 <<<"$out")"
expect "update refuses to grow the baseline" "1" "$(run --update-baseline >/dev/null; echo $?)"
add Sources/FlareApp/FlareStage.swift $'struct Old: View { var body: some View { Color.clear } }'
out=$(run); rc=$?
expect "a fixed hit must leave the baseline" \
  "1|Sources/FlareApp/FlareStage.swift::Old.Canvas: listed in Tests/render-contract-baseline.txt but no longer hits" "$rc|$(head -1 <<<"$out")"
expect "shrinking needs no flag" "check-render-contract: baseline written, 0 grandfathered hits." "$(run --update-baseline)"

# The repo itself: its baseline matches its tree.
expect "the repo passes its own baseline" "0" "$(python3 "$lint" >/dev/null 2>&1; echo $?)"
exit "$fail"
