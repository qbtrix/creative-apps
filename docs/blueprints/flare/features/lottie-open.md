# Feature packet: lottie-open

**Feature:** start from an existing Lottie. File > Open (and dropping a file on
the window or the Dock icon) accepts a Lottie `.json`: FlareCore's
`LottieImport.document(from:)` (at the pin) reads shapes, solids, styles,
transforms, keys, masks and mattes into a Flare document, and its
`ImportReport.skipped` (precomps, images, text, expressions) is shown in a note
that names each skipped layer, never silently. The document opens untitled
with the Lottie's name, so Save writes a `.flare` and the original JSON is never
overwritten; Export writes Lottie as usual. A file that isn't a Lottie, is over
the reader's limits or is malformed gets a named error. Every action is a
catalog command (`file.open` takes `.json`; `import.report` reads the last
note), so an agent can open and recolour a Lottie too.
**Line:** `line:flare` · **Wave:** 8 (`waves.md`) · **Lead branch:** `lead/lottie-open`
**Beta:** captain, 2026-10-21 (beta gaps, Flare must-haves). Labels `beta` and `p1` when filed.

**Covers:** `2026-10-21-beta-gaps-combined.md` Flare must-have "open a Lottie
file"; Flare audit B5; feature map A2 (open; dotLottie with machines and
themes stays later); RJ-F12 (re-pointed here).

**Depends on:** layers-files and flare-export (built). FlareCore at the pin
`2258b62` has the reader (vector-import, built). **Waits:** Flare's file-flow
(**FL-m**) owns the open and drop paths and `FlareFiles.swift`, and pen-paths
(**FP-m**) is the last owner of Flare's catalog; LO-u and LO-m start after them.
suite no-placeholders' NP-flare also edits the catalog (cross-line hand-off). The stage draws an opened file's colour, trim and morph
keys only once the stage-matches-export fix (creative-core `fix/flare-sampler`,
creative-apps `fix/flare-stage-matches-export`, in flight) merges; until then
the journey's recolour step checks the Lottie export, not the stage.

**Rule 20.** The reader is FlareCore's; no Lottie parsing in the app. The
skipped note reuses export's `ExportScan` row view for its list.

**C4:** none (FlareModel and FlareApp components cover the new files).

**Clean-room.** The Lottie format from its public docs (FlareCore's reader).

Blueprint sections: flare.md 4 (files), 6 (Lottie).

**Hand-off (beta gaps C1 to C12, suiteui line, cross-line):** the XK4 kernel-gap adopts (clipboard-interop CB-flare, frame-rates FR-flare, anchor-parenting AN-flare-m, document-setup DS-flare, brush-keys BK-flare) also edit `FlareCommandCatalog.swift` and `Tests/command-ids/flare.txt`. The slices here that edit those files start after those adopts' slices on the same app have merged, or before them with their lead told; the checker can't see this across lines.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| LO-a | Flare declares the Lottie open path and the import note as stubs, with the checks written and disabled. | LO-1, LO-2 | MJ-LO | – |
| LO-u | File > Open and drop accept a Lottie JSON and the window shows the import note listing what was skipped, on the stubs, within the render budget. | LO-4, LO-4b | FJ-LO | LO-a; file-flow:FL-m (open and drop paths) |
| LO-m | A Lottie opens as an untitled Flare document with its keys, masks and mattes, every skipped item named, and malformed or over-limit files refused with a reason, through the catalog. | LO-3, LO-3h | MJ-LO | LO-a; file-flow:FL-m (`FlareFiles.swift`); pen-paths:FP-m (the catalog and ledger, the last on this line) |
| LO-z | Opening and recolouring a Lottie runs live end to end, RJ-F12 passes, and the feature is built. | LO-5, LO-6 | FJ-LO, MJ-LO | LO-u, LO-m |

**Screen early.** LO-u builds the open path's UI and the note on LO-a's stubs, beside LO-m.

## Journey steps

`MJ-LO` on Linux (`FlareLottieOpenTests`, `FlareLottieOpenCLITests`), then:
1. File > Open the bounce fixture: an untitled document named "bounce" with its layers and keys; the note says nothing was skipped; open the precomp fixture: the note names the precomp and the image; Dismiss (LO-4, LO-5).
2. Select the ball, set its fill orange, Export > Lottie; Save offers a new `.flare` (LO-5; `FJ-LO`, `FlareLottieOpenJourneyTests.testOpenAndRecolour`).

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-F12 | closes (re-pointed to `flare/lottie-open`; `needs` keep A2) | C | `Tests/RealJobs/flare/open-recolour-lottie/`: `afterglow run flare --open bounce.json`, set the ball's fill, export Lottie | `bounce.lottie.json` |

Trap: the open drops keys or masks without a word, or Save overwrites the
downloaded JSON. Assertion: the exported Lottie has the same keyframe count and
frames as the input with the new colour in `fl.c`, the run's `import.report`
lists exactly the fixture's skipped kinds, and the input file's bytes are
unchanged. Mutation: `FlareModel.FlareLottieOpen` (`.namesEverySkip`). LO-2
writes it; LO-5 enables it.

## Screens and states

`flare-lottie-open-note` (two skipped items named), `flare-lottie-opened` (the bounce on stage).

## Contract slice

```swift
// Sources/FlareModel/FlareLottieOpen.swift (LO-1 stub, LO-3 body). Linux-safe.
public enum FlareLottieOpen {
    public static let fileExtensions = ["json"]
    /// The document and one sentence per skipped item ("The precomp \"Logo\" isn't supported yet and was left out.").
    public static func open(data: Data, name: String) throws(FlareOpenError) -> (FlareDocument, [String])
}
```

| id | title | params | unavailable when |
|---|---|---|---|
| `file.open` (extended) | – | `{path}` now also `.json` | as today |
| `import.report` | – (query) | – → `{skipped: [sentence]}` | nothing opened from a Lottie |

## Pseudocode

- **Open.** Read the file (refuse over `LottieImport.maxBytes` before reading
  it all); `LottieImport.document(from:)`; wrap as an untitled `FlareDocument`
  named for the file's stem; map each `skipped` entry to a sentence.
- **Never overwrite.** The document has no file URL until Save As; Save
  behaves as Save As with the stem and `.flare`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LO-1 | – | **Checks first.** `FlareLottieOpenTests` (fixtures: a two-layer bounce, a file with a precomp and an image, a malformed file, an over-limit file) written, disabled (`waits on LO-3`); `FlareLottieOpen` (`open(data:name:) throws -> (FlareDocument, [String])`) as a stub | `Sources/FlareModel/FlareLottieOpen.swift`, `Tests/FlareModelTests/FlareLottieOpenTests.swift`, `Tests/FlareModelTests/Fixtures/bounce.lottie.json`, `Tests/FlareModelTests/Fixtures/precomp.lottie.json` | – | ~160, 4 |
| LO-2 | – | `FlareLottieOpenJourneyTests` written, skipped until LO-5; RJ-F12's check re-pointed, disabled | `UITests/FlareJourneyTests+LottieOpen.swift`, `Tests/RealJobs/flare/open-recolour-lottie/open-recolour-lottie.jobs.json` | LO-1 | ~100, 2 |
| LO-4 | – | **Reachable first.** The open panel's types include Lottie JSON; a drop of a `.json` routes to it; the import note (SuiteUI `InspectorNote` with the skipped rows, dismissable) above the stage; a stub open shows "Opening Lottie arrives with LO-3." | `Sources/FlareApp/FlareFilePanels.swift`, `Sources/FlareApp/FlareWindow+File.swift`, `Sources/FlareApp/FlareImportNote.swift` | LO-1 | ~180, 3 |
| LO-4b | – | Render budget test: open the bounce fixture and dismiss the note | `Tests/AppSnapshotTests/RenderBudgetFlareLottieOpenTests.swift` | LO-4 | ~60, 1 |
| LO-3 | – | `FlareLottieOpen` body over `LottieImport.document(from:)`: an untitled document named for the file, the report's skipped list as plain sentences, the reader's errors as named refusals; `FlareFiles` routes `.json`; `FlareHeadless.openExtensions` gains `json`; `import.report` in the catalog; turns on `FlareLottieOpenTests` | `Sources/FlareModel/FlareLottieOpen.swift`, `Sources/FlareModel/FlareFiles.swift`, `Sources/FlareModel/FlareHeadless.swift`, `Sources/FlareModel/FlareCommandCatalog.swift`, `Tests/command-ids/flare.txt`, `Tests/FlareModelTests/FlareLottieOpenTests.swift`, `Tests/mutations/FlareModel.FlareLottieOpen.json` | LO-1 | ~220, 7 |
| LO-3h | – | The headless open on Linux: `afterglow run flare --open x.json` works; the CLI's tests cover it | `Tests/AfterGlowCLITests/FlareLottieOpenCLITests.swift` | LO-3 | ~60, 1 |
| LO-5 | – | The open and the note on live; the journey on (open the bounce, recolour the ball, export Lottie); RJ-F12 enabled | `Sources/FlareApp/FlareWindow+File.swift`, `UITests/FlareJourneyTests+LottieOpen.swift`, `Tests/RealJobs/flare/open-recolour-lottie/open-recolour-lottie.jobs.json` | LO-4, LO-3, LO-2 | ~100, 3 |
| LO-6 | – | `status: built`; `feature-done` | `docs/blueprints/flare/features/lottie-open.wave.json` | LO-5 | ~10, 1 |

## Build waves

- Wave 1: LO-1. Independent in this wave: LO-1 alone.
- Wave 2: LO-2, LO-4, LO-3. Independent in this wave: all.
- Wave 3: LO-4b, LO-3h, LO-5. Independent in this wave: all.
- Wave 4: LO-6. Independent in this wave: LO-6 alone.

Longest chain: LO-1 → LO-4 → LO-5 → LO-6 (4). Chain of 4: the stubs, the open body, the live window, the done task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| LO-1 | compiles, disabled by name | a signature the window calls is missing | – (stubs) |
| LO-2 | `scripts/jobs check` | the job names a missing command | – (tests) |
| LO-4 | the panel offers JSON; the note carries its ids and a Dismiss | a JSON can't be picked or the note can't be dismissed | – (view; render budget row) |
| LO-4b | `RenderBudgetFlareLottieOpenTests.openInThreeBodies` | opening re-renders the window per layer | – (budget) |
| LO-3 | `FlareLottieOpenTests`: the bounce opens with its position keys at the same frames; the precomp file names the precomp and the image as skipped; the malformed file is refused with "isn't a Lottie file"; Save never targets the JSON | a skipped layer goes unmentioned, keys move, or Save would overwrite the JSON | `FlareModel.FlareLottieOpen`: skipped list dropped → `.namesEverySkip`; document given the JSON's URL → `.opensUntitled` |
| LO-3h | `FlareLottieOpenCLITests` | the CLI can't open a Lottie | – (test) |
| LO-5 | `FJ-LO`; RJ-F12 on Linux | the window opens the JSON as text or loses the keys | – (window wiring) |
| LO-6 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: open a 50-layer Lottie | ≤ 3 window bodies; open ≤ 300 ms | `RenderBudgetFlareLottieOpenTests.openInThreeBodies` |
| never silent | every skipped item named | `FlareLottieOpenTests` |
| never overwrite | the input JSON's bytes unchanged after Save | RJ-F12 |

## Done check

Per slice (rules 6, 15, 17, 21, 22): LO-a and LO-m green on Linux with
`Mutate:` clean; LO-u and LO-z through the feel gate (`mouse`) with their
`Mac-Finish:` lines; RJ-F12 green on Linux. Then `Belt-Contact-Sheet:`.
