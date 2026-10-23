# Feature packet: svg-place (Flare)

**Feature:** SVG art comes into Flare as layers you animate. File > Place…
(⇧⌘P) and a drop on the window read an SVG with FlareCore's `SVGImport` and
add its layers to the edited scene or symbol, fitted inside the scene and
centred, each group its own layer with its colours, in one undo step. What the
reader skipped (filters, embedded images) shows in the status line. It runs
through SuiteKernel's `place.image`, so the CLI and an agent import SVG too.
**Line:** `line:flare` · **Wave:** 7 (`waves.md`) · **Lead branch:** `lead/svg-place`
**Beta:** captain, 2026-10-20 ("Flare has no SVG import"). Labels `beta` and `p1` when filed.

**Covers:** feature map `flare/svg-place` (adopter of S20 and E11's Flare
half); real job RJ-F06 (closes here).

**Depends on:** `suiteui/placed-images` **PL-a** (cross-line); PF-4 needs its
**PL-7**. Same line: gradient-fill's **FG-m** (it owns
`FlareCommandCatalog.swift` and `Tests/command-ids/flare.txt`) before PF-6;
gradient-fill's **FG-z** (`flare.md`) before PF-8; live-scenes, layers-files and
draw-key-save (built). creative-core: nothing new; `SVGImport` (#439) is on
the pinned core.

**Beta gaps A (#3432, merged first).** Its packets share files with this one, so these slices also wait on theirs: PF-m on `shape-tools:FS-m`, `stroke-style:FK-m`.

**Hand-offs:** `FlareCommands.swift` is adopt-command-catalog's (#2999): PF-3
starts after AC-flare's `Belt-Slice-Done:`. The stage view is stage-edit's
(`FlareStage.swift`), so the drop target sits on the window, not the stage,
and places at the scene centre.

**Rule 20.** No Flare importer and no picture type. FlareCore reads the SVG;
`FlarePlace+Kernel.swift` conforms `FlareWorkspace` to `PlacedImageTarget`
with `placeFormats = [.svg]` and expands the asset into layers in
`insertPlaced`. The fit is the kernel's `PlaceRules.fitted`, applied as one
FlareCore `Matrix` to every imported shape. Flare keeps no picture, so
`place.replace`, `place.reset-size`, `place.focus` and `fill` are unavailable
with "Flare places SVG art as layers you edit." A PNG or JPEG is refused with
the kernel's `formatHelp` for this target ("Flare places SVG files."): FlareCore
has no image shape (a creative-core issue, not this packet).

Blueprint sections: flare.md 2 (menus), 3.4 (edit), 5 (files).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| PF-a | `FlareWorkspace`'s `PlacedImageTarget` conformance and its import report exist as stubs, and the checks and RJ-F06's job are written, disabled. | PF-1, PF-2 | MJ-PF | suiteui/placed-images PL-a (cross-line) |
| PF-u | File > Place… and a window drop run `place.image` on the stubs, the status line shows the report, with snapshots, the render budget and the journey written. | PF-3, PF-4 | FJ-P1 | PF-a; key-select-all:KS-a (`FlareCommands.swift`); flare-export (built, it owns `FlareWindow.swift`) |
| PF-m | Placing an SVG adds its groups as layers with their colours, fitted and centred in the edited owner, as one undo step, refuses rasters with the reason, and runs from the catalog. | PF-5, PF-6 | MJ-PF | PF-a; gradient-fill:FG-m (PF-6); PL-7 (cross-line) |
| PF-z | The window runs on live services, the journey passes on live, and the blueprint lists Place. | PF-7, PF-8 | FJ-P1 | PF-u, PF-m; gradient-fill:FG-z (PF-8) |

PF-u waits only on PF-a (rule 18); PF-m never waits on PF-u. MJ-PF is the
Model walk in `FlarePlaceTests` (Linux).

## Journey steps

1. New animation (`FlarePlaceJourneyTests.testPlaceSVGArt`).
2. File > Place… (PF-3) and choose the journey kit's `two-groups.svg` (a red
   and a blue group, 240 × 80): two layers, `red` and `blue`, appear centred,
   in the SVG's colours; the status line reads "Placed two-groups.svg: 2
   layers."
3. Select `blue` and key its x at 0 and 24 frames: only the blue part moves.
4. Undo twice: the keys go, then both placed layers go in one step.
5. Place `photo.png`: nothing is added; the status line reads "Flare places
   SVG files."

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F06 | closes with `flare/svg-place` | C | `Tests/RealJobs/flare/place-svg/place-svg.jobs.json`: `place.image` of `logo.svg` (base64; two groups, a red `#E53935` and a blue `#1E88E5`, the blue one with a hole), `file.save` | `input/blank.flare` (one 480 × 270 scene) |

Trap: black fills, or the groups flattened into one path. Assertion: the
saved scene has two new layers named after the groups, the first shape's fill
is (229, 57, 53) and the second's (30, 136, 229) within 1/255, and the blue
shape keeps two contours. Mutation: `FlareModel.FlarePlace+Kernel.json`, every
imported layer merged into one → `FlarePlaceTests.groupsStayLayers`.

## Screens and states

`flare-place-svg` (the two placed layers on the stage), `flare-place-report`
(the status line after a file with a skipped filter), light and dark.

## Contract slice

```swift
// Sources/FlareModel/FlarePlace+Kernel.swift (PF-1 stubs, PF-5 bodies)
extension FlareWorkspace: PlacedImageTarget {
    public var placeHelp: String? { get }              // no document; a locked owner
    public var placeCanvas: Rect { get }               // the edited scene's (or symbol's) frame
    public var placeFillBox: Rect? { get }             // nil
    public var placeFormats: Set<PlacedFormat> { get } // [.svg]
    public var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { get }   // nil
    public func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size                   // throws formatHelp
    /// SVGImport's scene: its layers, each shape through the fit matrix, appended on top of the edited owner
    /// in one apply group named `name`; returns the first new layer's id.
    public mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String
    public mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws // throws
    /// "Placed logo.svg: 2 layers." plus "Skipped filter (3)." when the reader skipped any; nil before a place.
    public var placeReport: String? { get }
}
```

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| PF-1 | – | The conformance and `placeReport` as stubs; `FlarePlaceTests` written, disabled | `Sources/FlareModel/FlarePlace+Kernel.swift`, `Tests/FlareModelTests/FlarePlaceTests.swift` | PL-a | ~150, 2 |
| PF-2 | – | RJ-F06's job folder with `waits_on: PF-6`, its fixtures | `Tests/RealJobs/flare/place-svg/` | PF-1 | ~80, 3 |
| PF-3 | – | Reachable: File > Place… ⇧⌘P (the panel limited to SVG), the window's `placeDropTarget(formats: [.svg])`, both running `place.image` with no point; the report in the status line | `Sources/FlareApp/FlarePlace.swift`, `Sources/FlareApp/FlareCommands.swift`, `Sources/FlareApp/FlareWindow.swift` | PF-1 | ~160, 3 |
| PF-4 | – | Snapshots, the render budget test, the journey written and skipped (`XCTSkip("waits on PF-7")`) | `Tests/AppSnapshotTests/FlarePlaceSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetFlarePlaceTests.swift`, `UITests/FlareJourneyTests+Place.swift` | PF-3 | ~200, 3 |
| PF-5 | – | Conformance bodies: import, fit matrix, one apply group, the report; turns on `FlarePlaceTests` | `Sources/FlareModel/FlarePlace+Kernel.swift`, `Tests/FlareModelTests/FlarePlaceTests.swift`, `Tests/mutations/FlareModel.FlarePlace+Kernel.json` | PF-1, PL-7 | ~260, 3 |
| PF-6 | – | The five specs in the catalog and the id list; turns on RJ-F06 | `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/RealJobs/flare/place-svg/` | PF-2, PF-5, gradient-fill:FG-m | ~40, 3 |
| PF-7 | – | Live: the journey turned on, on live services | `UITests/FlareJourneyTests+Place.swift` | PF-4, PF-6 | ~40, 1 |
| PF-8 | – | flare.md lists Place and SVG import; `status: built`; `feature-done` | `docs/blueprints/flare.md`, `docs/blueprints/flare/features/svg-place.wave.json` | PF-7, gradient-fill:FG-z | ~30, 2 |

PF-6 is under 50 lines; the lead folds it into PF-5's slice PR (rule 22). It
stays its own row because it waits on gradient-fill's FG-m and PF-5 doesn't.

## Build waves

- Wave 1: PF-1. Independent in this wave: PF-1 alone.
- Wave 2: PF-2, PF-3, PF-5. Independent in this wave: all three.
- Wave 3: PF-4, PF-6. Independent in this wave: both.
- Wave 4: PF-7. Independent in this wave: PF-7 alone.
- Wave 5: PF-8 (shared prose, `feature-done`, final). Independent in this wave: PF-8 alone.

Longest chain: PF-1 → PF-3 → PF-4 → PF-7 → PF-8 (5). Chain of 5: the menu
needs the conformance, the journey drives the menu, PF-7 turns it on live,
PF-8 is the prose task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| PF-1 | the suite compiles, disabled; every existing Flare test passes | the conformance breaks the build | – (stub) |
| PF-2 | the job is listed and skipped by `waits_on` | – | – |
| PF-3 | `FlarePlaceSnapshots.placed` (PF-4's, first in the slice PR) | the menu item or drop is missing | – (UI) |
| PF-4 | `FlarePlaceSnapshots`; `RenderBudgetFlarePlaceTests.placeInThreeBodies` | budget over | – (UI) |
| PF-5 | `FlarePlaceTests`: `two-groups.svg` adds two layers with their names and colours on top of the selected layer; a 960 × 320 SVG in a 480 × 270 scene is scaled to 480 × 160 and centred; the ring keeps its hole; one undo removes both; a PNG is refused with "Flare places SVG files." and adds nothing; a damaged SVG adds nothing and reports the reader's reason; `placeReport` names a skipped filter | a colour, name, fit or step count is wrong | `FlareModel.FlarePlace+Kernel`: layers merged into one → `.groupsStayLayers`; fit matrix skipped → `.fitsInsideScene`; each layer its own apply (two steps) → `.oneUndoStep` |
| PF-6 | `CommandPathTests` and the catalog's id ledger list the five ids; RJ-F06 passes on Linux | an id is missing, or the job fails | – (registration; the behaviour's mutations are PF-5's) |
| PF-7 | `FlarePlaceJourneyTests.testPlaceSVGArt` steps 1 to 5 | a step fails | – |
| PF-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: placing a 2,000-path SVG with the stage live | ≤ 3 window bodies for the place; import ≤ 200 ms debug (reported) | `RenderBudgetFlarePlaceTests.placeInThreeBodies` |
| One gesture, one step | a place is one undo step however many layers it adds | `FlarePlaceTests.oneUndoStep` |
| No dead controls | Place… in `flare.controls`, enabled with a document open | `testPlaceSVGArt` |
| Audit | zero new over Flare's baseline | `audit-flare-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): PF-m merged-done with RJ-F06 green in the
Linux job; PF-u's feel gate and `Mac-Finish:`; PF-z's journey on live. Then
`Belt-Contact-Sheet:` with `flare-place-*`.

## Not in this packet

Raster images in Flare (FlareCore has no image shape), Lottie import (the
reader exists; a menu item and its own job are a follow-up), placing at the
drop point on the stage (the stage is stage-edit's), editing the placed art's
anchors (S18), linked SVG that updates when the file changes.
