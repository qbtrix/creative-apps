# Feature packet: suite-harness

**Feature:** the test harness every SuiteUI and app feature proves its work
on: golden compare and the snapshot host in four appearances, the journey
template that picks up a second journey file, the component gallery behind
`-SuiteGallery`, the control inventory (`suite.controls`), the frame probe
(`suite.perf`), the shared contracts with `EditRun`, and the one token sheet
for waves 2 to 4.
**Line:** `line:suiteui` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/suite-harness`
**Status:** built on `dev`: SH-1 to SH-10 merged (#786, #787, #850, #867, #866, #869, #871, #874, #875, #877, #878); Anatomy round 1 fixes merged (#881, #883, #884, #885). Review rounds continue in `docs/leads/suite-harness/RECORD.md` on `lead/suite-harness`.

**Covers:** #773 (contracts, SH-1), #774 (token sheet, SH-2), #283
(secondary text contrast, SH-3), #330 (QH-1 `FrameProbe`, SH-4), #775
(control inventory, SH-5), #776 (gallery, SH-6), #333 (QH-4 journey files,
SH-7), #331 (QH-2 golden compare, SH-9), #332 (QH-2b snapshot host, SH-10).
Each closes through the task PR named below. SH-8 (SJ25 and the gate
constants) has no issue of its own; its PR says "Part of the suite-harness
feature".

**Depends on:** nothing open. #329 (S0 tokens) is closed; no creative-core
issue (SuiteUI knows no engine).

**This packet supersedes the "Touch only these files" lists** of #330, #331,
#332 and #333 (review of #765): the task table below is the owned-file list.
#333's smoke file is `UITests/SuiteJourneyTests+Smoke.swift`, not a Flare
file, and its acceptance is restated in SH-7. Section 7.2's QH-4 row in
`docs/blueprints/flare.md` still names `FlareJourneyTests+Smoke.swift`; that
row is Flare's to correct, and nothing in Flare's plan reads the smoke file.

Blueprint sections it builds on: 0.4 (what is missing), 4.1 (where the
journeys run), 5.1 and 5.3 (contracts), 6.2 (tokens, gallery look), 7.1 and
7.4 (probe and golden rules), 8.3 (owned files).

**Building blind.** Everything here except the contracts is macOS-only:
`Sources/SuiteUI/`, `Tests/SuiteUITests/`, `Tests/AppSnapshotTests/` and
`UITests/` compile only in the `macOS` job on `dev`. `scripts/ci` on Linux
still runs the lints over these files (no-crash, the SuiteUI design lint:
raw colors, fonts and sizes only in `Tokens.swift`, glass only in
`Glass.swift`). So: check every API with the `apple-docs` MCP and say so in
the PR, copy the imports and shape of a SuiteUI file that already builds,
and keep every rule pure and unit-tested. The contracts can be checked on
Linux by hand, as section 5.1 says:
`swiftc -swift-version 6 -warnings-as-errors Shim.swift <the new Contracts files> main.swift`
with a `main.swift` trimmed to the harness Fakes.

## Captain questions this packet assumes

Section 9's Q1, Q2, Q3 and Q9 decide this packet. They were not answered
when it was written, so it builds the blueprint's recommendation for each,
in a shape that a "no" changes in one task:

| Q | Assumed | If the captain says no |
|---|---|---|
| Q1 Linux target for SuiteUI's rules | not assumed: no task edits `Package.swift` (protected). Contracts sit in `Sources/SuiteUI/Contracts/`, Foundation-only | nothing in this packet changes; a later scripts/manifest issue moves the folder |
| Q2 gallery behind a launch flag | yes, `-SuiteGallery` in `SuiteWindow` | SH-6 becomes a gallery target, which needs `Package.swift` and `scripts/bundle-apps` (both protected): the lead stops SH-6 to SH-8 and comments on the feature issue |
| Q3 a `suiteui` key in `UITests/audit-baseline.json` at 0 | yes. Adding an app at 0 is not a loosening (CLAUDE.md, Fast lane) | SH-7 drops the key and the gallery shots tally under `library`; SJ0 and SJ25 still run |
| Q9 one publisher of `suite.controls` | yes: SuiteUI's `ControlInventory`; Flare's #347 feeds it through `.suiteControl` | Flare keeps `FlareControls.swift`; SH-5 is unchanged, and Flare's window must not apply `.suiteProbes()` |

**The gallery ships in release builds.** The review of #765 asked whether
to gate it behind `#if DEBUG`. The journeys launch the bundles
`scripts/bundle-apps` builds, and those are release builds
(`swift build -c release`), so a `DEBUG` gate would hide the gallery from
every SuiteUI journey. This packet keeps it as a test surface reachable only
by launch argument, with the flag parsed in one function
(`SuiteGallery.request(from:)`, SH-6) so a different gate later is a
one-line change. Recorded as an open captain call in `waves.md`.

## Journey steps

SuiteUI's own journeys run in the `SuiteJourneyTests` bundle this feature
adds, launching Library with `-SuiteGallery <page>`
(`Journey("Library", self, name: "suiteui", arguments: [...])`).

1. **SJ0** `SuiteJourneyTests.testGalleryOpensEveryPage`: launch with
   `-SuiteGallery index -SuitePerfProbe`; open each page from the index
   list; each page's root `suite.gallery.<page>` exists; `suite.controls`
   decodes as `ControlDocument`, lists every `suite.gallery.*` control on
   the page, and `violations()` of a `SuiteControlInventory` rebuilt from it
   is empty; launch with `-SuiteGallery nosuch`: an `EmptyStateView` reads
   "No gallery page named nosuch." The stub pages (owned by wave-2 and
   wave-3 features) each show one `EmptyStateView` "<Page> components land
   with <feature>." until their feature fills them.
2. **SJ25** `SuiteJourneyTests.testEveryControlMeetsHitSize`: on each page,
   every `suite.controls` entry's element is at least 20 × 20 pt, or at the
   smaller hit the token table names for it (QB-S20). A page with no
   controls passes with a count of 0.
3. **Smoke** `SuiteSmokeJourneys.testSecondFileRuns`
   (`UITests/SuiteJourneyTests+Smoke.swift`): launches the `index` page and
   takes one shot, proving the template compiles `UITests/<target>*.swift`.
4. **Goldens:** `GoldenImageTests` and `SnapshotHostTests` prove the compare
   and the host; no component golden is recorded here (each later feature
   records its own in `Golden/<area>/`).

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Gallery index (`index`) | none: it always lists every page | an unknown page: `EmptyStateView` "No gallery page named <name>." | none |
| A stub page | its `EmptyStateView` "<Page> components land with <feature>." | none | none |
| `suite.perf` | no samples: `latency` and `intervals` are `{}` and every summary `valid: false` | none (encoding a `ProbeDocument` cannot fail on finite values; a non-finite time is dropped when recorded) | a series under 60 samples reads `valid: false` |
| `suite.controls` | no controls: `{"controls":[]}` | `violations()` names each bad id; SJ0 fails on any | none |
| Golden compare | a missing baseline: the result fails with share 1 and the actual is written to `.build/snapshots/` | a size mismatch or malformed buffer: fails with share 1 | none |

## Contract slice

Landed by SH-1 verbatim from `docs/blueprints/suiteui/contracts/Contracts.swift`
(the 5.1 block and the 5.3 block):

```swift
// Contracts/ContractTypes.swift: PlanePoint, PlaneExtent, PlaneRect, KeyModifiers, GridArrow, EditRun
public struct EditRun: Equatable, Sendable {
    public mutating func change() -> Bool   // true when this change opened the run
    public mutating func end() -> Bool      // true exactly once per opened run
}
// Contracts/FrameProbeRecording.swift (UC17): ProbeSample, ProbeSummary, FrameIntervalSummary, ProbeMark, ProbeDocument
public protocol FrameProbeRecording: Sendable {
    mutating func record(_ sample: ProbeSample)
    mutating func drew(_ series: String, at time: Double)
    mutating func mark(_ name: String, series: String, at time: Double)
    func summary(of series: String, refreshInterval: Double) -> ProbeSummary
    func intervals(of series: String, refreshInterval: Double) -> FrameIntervalSummary
    func document(refreshInterval: Double) -> ProbeDocument
    func encoded(refreshInterval: Double) throws -> Data
}
// Contracts/ControlInventorying.swift (UC18): ControlEntry(id:enabled:reason:role:), ControlDocument
public protocol ControlInventorying: Sendable {
    mutating func register(_ entry: ControlEntry)
    mutating func unregister(_ id: String)
    func violations() -> [String]          // disabled with no reason, or an id registered twice
    func document() -> ControlDocument     // sorted by id
    func encoded() throws -> Data
}
// Contracts/GoldenComparing.swift (UC19): RGBAImage, GoldenTolerance (.standard = 2/255, 0.5 %), GoldenResult
public protocol GoldenComparing: Sendable {
    func compare(_ actual: RGBAImage, to baseline: RGBAImage, tolerance: GoldenTolerance) -> GoldenResult
}
```

New SuiteUI API (not contracts, but every later feature calls it):

```swift
public struct ToolbarAction { public var identifier: String? }        // SH-5, default nil
extension View {
    public func suiteControl(id: String, enabled: Bool, reason: String?, role: String? = nil) -> some View  // SH-5
    public func suiteProbes() -> some View   // SH-5: publishes suite.perf and suite.controls under -SuitePerfProbe
}
extension EnvironmentValues { public var suiteReduceMotion: Bool }    // SH-5, defaults to the system setting
public struct GalleryRequest { page: String; fakes: Bool; width: Double? }   // SH-6
public struct SuiteGallery: View { public init(_ request: GalleryRequest) }  // SH-6
```

`role:` answers the review of #765: `.suiteControl` needs it so
editor-chrome's Export can register `role: "primary"` (SJ3) without editing
`SuiteEnvironment.swift`, which no wave-2 feature owns.

`.suiteProbes()` is applied by `SuiteWindow` (SH-6) and by the gallery root, and editor-chrome applies it to `EditorShell`. Under `-SuiteGallery` those nest (the window's body is the gallery, and the `editor` page draws an `EditorShell`), so `.suiteProbes()` publishes only at the outermost one: it sets an environment flag, and an inner call whose flag is already set adds nothing. One `suite.controls` and one `suite.perf` element per window, always.
`EditorShell` applies it in editor-chrome (EC-3), the feature that owns
`EditorShell.swift` in wave 2; until then Design and Photo publish nothing,
which changes no journey today.

## Pseudocode

```
EditRun                                                          # SH-1
  change(): opened = !isOpen; isOpen = true; return opened
  end():    guard isOpen else false; isOpen = false; ends += 1; true

SuiteFrameProbe : FrameProbeRecording                            # SH-4
  record(s): guard s.eventTime, s.shownAt finite else drop; append
  framesLate(s, r) = max(0, Int(((s.shownAt - s.eventTime) / r).rounded(.up)) - 1)   # r > 0 guarded; r <= 0 -> summary invalid
  summary(series, r): lates = sorted framesLate; p50 = nearest-rank 50 %, p95 = nearest-rank 95 %; valid = count >= 60
  intervals(series, r): diffs of sorted drawn times; p95Refreshes = p95(diff / r);
                        dropped = sum(max(0, round(diff / r) - 1)); jitterP95 = p95(|diff - r|); valid = diffs >= 60
  published only under -SuitePerfProbe: hidden Text, identifier "suite.perf", label = JSON of document(r)
  r = the window's display refresh interval (apple-docs: NSScreen / CADisplayLink on macOS 26), 1/60 when unknown

SuiteControlInventory : ControlInventorying                      # SH-5
  register(e): if entries[e.id] exists and was registered by a different view: duplicates.insert(e.id); entries[e.id] = e
  violations(): duplicates ∪ { id | !enabled && reason empty }, sorted
  .suiteControl(id, enabled, reason, role): onAppear/onChange register; onDisappear unregister; also .accessibilityIdentifier(id)

SuiteGallery.request(from arguments) -> GalleryRequest?        # SH-6, pure, unit-tested
  page  = value after "-SuiteGallery", else nil (no gallery)
  fakes = "-SuiteGalleryFakes" present
  width = Double(value after "-SuiteGalleryWidth") if finite and > 0, else nil
SuiteWindow.body: if let request (read once, in init) { SuiteGallery(request) } else { today's split view }
SuiteWindow(galleryPage: ...) internal init: skips the argument check, so the `window` page's inner window never recurses
SuiteGallery.pages = GalleryIndex.pages + GalleryChrome.pages + GalleryInspector.pages + GalleryLists.pages
                   + GalleryCanvas.pages + GalleryTimeline.pages + GalleryGraph.pages
  each Gallery<Area>.swift declares `static let pages: [String: () -> AnyView]` in its own file, so a wave-2 feature
  adds a page (canvas-marks adds `surface`, `surface-empty`) without editing SuiteGallery.swift. The stubs start with
  the blueprint's 6.3 names: index; window; editor, editor-plain, empty; inspector, curves; layers, layers-300,
  grid, grid-2000; canvas, canvas-pt, marks; timeline, timeline-long; graph, graph-loop

GoldenImage : GoldenComparing                                    # SH-9
  guard sizes equal and bytes.count == w*h*4 else fail(share 1)
  differing = pixels where any channel |a - b| > tolerance.channel
  share = differing / (w*h); passes = share <= maxShare; diff = magenta over grey when differing > 0
  assertGolden(view, name, appearance, filePath: #filePath):
    baseline = <dir of filePath>/Golden/<area>/<name>-<appearance>.png
    missing  -> write actual to .build/snapshots/golden-new/; record a known issue (see Decisions); return
    mismatch -> write actual and diff to .build/snapshots/golden-diff/; fail

SnapshotHost(appearance, scale 2)                                # SH-10
  NSHostingView in an offscreen window whose appearance is one of
  .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua; bitmap at backing scale 2
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files,
label `fast-lane`, body lines `Belt-Lead:`, `Feature: suite-harness`,
`Fast-Check: pass`, `Head:`. SH-8 also carries `feature-done`. No task edits
`docs/c4/model.json` (the `suiteui-sources` path `Sources/SuiteUI/` already
owns every new file; suite-record #345 updates the description) or
`docs/design.md`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SH-1 | #773 | Shared contract types, `EditRun`, and the probe, inventory and golden contracts with their Fakes | `Sources/SuiteUI/Contracts/ContractTypes.swift`, `Sources/SuiteUI/Contracts/FrameProbeRecording.swift`, `Sources/SuiteUI/Contracts/ControlInventorying.swift`, `Sources/SuiteUI/Contracts/GoldenComparing.swift`, `Tests/SuiteUITests/EditRunTests.swift`, `Tests/SuiteUITests/HarnessFakeTests.swift` | – | ~330 lines, 6 files |
| SH-2 | #774 | The token sheet for waves 2 to 4 and their contrast pairs | `Sources/SuiteUI/Tokens.swift`, `Tests/SuiteUITests/TokensTests.swift` | – | ~90, 2 |
| SH-3 | #283 | Secondary text reaches 4.5:1 on light cards and panels | `Sources/SuiteUI/Tokens.swift`, `Tests/SuiteUITests/TokensTests.swift` | SH-2 | ~40, 2 |
| SH-4 | #330 | `SuiteFrameProbe`: frames late, intervals, marks, the `suite.perf` publisher | `Sources/SuiteUI/FrameProbe.swift`, `Tests/SuiteUITests/FrameProbeTests.swift` | SH-1 | ~330, 2 |
| SH-5 | #775 | `SuiteControlInventory`, `SuiteEnvironment` (`suiteReduceMotion`, `.suiteControl(…role:)`, `.suiteProbes()`), `ToolbarAction.identifier` applied and registered in the four views | `Sources/SuiteUI/ControlInventory.swift`, `Sources/SuiteUI/SuiteEnvironment.swift`, `Sources/SuiteUI/ToolbarGroup.swift`, `Sources/SuiteUI/EditorTopBar.swift`, `Sources/SuiteUI/InspectorAction.swift`, `Sources/SuiteUI/EmptyStateView.swift`, `Tests/SuiteUITests/ControlInventoryTests.swift` | SH-1, SH-4 | ~340, 7 |
| SH-6 | #776 | The gallery, its index, the six page stubs (each declaring its own page names), the `SuiteWindow` hook with the internal init that skips it, and toolbar identifiers | `Sources/SuiteUI/SuiteGallery.swift`, `Sources/SuiteUI/Gallery/GalleryIndex.swift`, `Sources/SuiteUI/Gallery/GalleryChrome.swift`, `Sources/SuiteUI/Gallery/GalleryInspector.swift`, `Sources/SuiteUI/Gallery/GalleryLists.swift`, `Sources/SuiteUI/Gallery/GalleryCanvas.swift`, `Sources/SuiteUI/Gallery/GalleryTimeline.swift`, `Sources/SuiteUI/Gallery/GalleryGraph.swift`, `Sources/SuiteUI/SuiteWindow.swift`, `Tests/SuiteUITests/SuiteGalleryTests.swift` | SH-5 | ~330, 10 |
| SH-7 | #333 | The template compiles `UITests/Journey*.swift`, `UITests/<target>*.swift` and the three journey-safe contract files; the `SuiteJourneyTests` bundle; `Journey(name:)`; input, velocity-drag and perf helpers; SJ0; the smoke file; the `suiteui` audit key at 0 | `project.yml`, `UITests/Journey.swift`, `UITests/Journey+Input.swift`, `UITests/SuiteJourneyTests.swift`, `UITests/SuiteJourneyTests+Smoke.swift`, `UITests/audit-baseline.json` | SH-6 | ~360, 6 |
| SH-8 | – | SJ25 and the journey gate constants (placeholders from section 7.1) | `UITests/SuiteJourneyTests.swift`, `UITests/SuiteJourneyTests+Budgets.swift` | SH-7 | ~150, 2 |
| SH-9 | #331 | `GoldenImage`: the compare, baselines by `#filePath`, actual and diff into `.build/snapshots/`, the recording rule | `Tests/AppSnapshotTests/GoldenImage.swift`, `Tests/AppSnapshotTests/GoldenImageTests.swift`, `Tests/AppSnapshotTests/Golden/README.md` | SH-1 | ~300, 3 |
| SH-10 | #332 | `SnapshotHost` at scale 2 in the four appearances; the glass stand-in at scale 2 | `Tests/AppSnapshotTests/SnapshotHost.swift`, `Tests/AppSnapshotTests/SnapshotHostTests.swift`, `Sources/SuiteUI/Glass.swift` | SH-9 | ~220, 3 |

Waves inside the feature: SH-1, SH-2 first; then SH-3, SH-4, SH-9; then
SH-5, SH-10; then SH-6; then SH-7; then SH-8. SH-2 and SH-3 share
`Tokens.swift` and `TokensTests.swift`, SH-7 and SH-8 share
`UITests/SuiteJourneyTests.swift`, so each pair is a chain, never parallel.

Hand-overs at the end of this feature (8.3): `ToolbarGroup.swift`,
`EditorTopBar.swift` and `EmptyStateView.swift` pass to editor-chrome,
`InspectorAction.swift` to inspector-controls, `SuiteWindow.swift` to
lists-and-layers, and each `Gallery/Gallery<Area>.swift` stub to its
feature. `Tokens.swift`, `SuiteEnvironment.swift`, `project.yml`,
`UITests/Journey*.swift` and `UITests/audit-baseline.json` stay with no
later SuiteUI feature: a later need goes to the supervisor as an issue.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| SH-1 | `EditRunTests`: `change()` true once then false; `end()` true once per run, false with no change; three drag-like runs give `ends == 3`. `HarnessFakeTests`: `FakeFrameProbe` reports 0 frames late and `valid` only at 60 samples; `FakeControlInventory` reports a disabled entry with no reason and *not* a duplicate (its deliberate gap); `FakeGoldenComparing` fails one changed byte with share 1 and no diff image | a run ends twice, an end with no change counts, or a Fake stops being wrong on purpose (the live tests below rely on the gap) |
| SH-2 | `TokensTests.geometry` lists the 14 new tokens with their values (section 6.2's 13 plus `iconButtonHit` 20, the Reset hit inspector-controls needs for #622, since no wave-2 feature may edit `Tokens.swift`); `TokensTests.contrast` checks the four QB-S32 pairs at `docs/design.md`'s ratios | a token is missing, renamed or a pair is under its ratio |
| SH-3 | `TokensTests.contrast`: `secondaryText` is redefined on palette values (today it is the system `.secondary`, which has no hex to test) and is at least 4.5:1 on `card`, on `panel` and on `surface` (the background `SurfaceCard` draws, where #283 measured the cards) in Light and Dark, through the palette's hex values as the existing contrast table does | any pair is under 4.5:1, or `secondaryText` is still a system color the test can't measure |
| SH-4 | `FrameProbeTests.referenceTable` (QB-S30): 100 synthetic samples at 60 Hz and at 120 Hz give the table's p50, p95 and dropped count; a non-finite time is dropped; a refresh interval of 0 gives `valid: false` and no division; the encoded JSON decodes to the same `ProbeDocument`; `FrameProbeTests.summaryWithinBudget` (QB-S16) | a percentile or a drop count is off, a NaN is kept, or the JSON round trip differs |
| SH-5 | `ControlInventoryTests`: `.suiteProbes()` nested inside `.suiteProbes()` publishes one `suite.controls` and one `suite.perf` element (a hosted view's accessibility tree); a duplicate id and a disabled entry with no reason are violations (the live type catches what the Fake misses); `document()` is sorted; JSON round trip; a `ToolbarAction` with `unavailableHelp` registers `enabled: false` with `reason == action.help`; one without an identifier registers nothing; `role: "primary"` survives the round trip | a duplicate passes, a reason differs from `.help`, an unnamed action registers, or nested probes publish twice |
| SH-6 | `SuiteGalleryTests`: the internal init builds a `SuiteWindow` that ignores `-SuiteGallery`; page names are unique across the area files and include the 18 listed in the pseudocode; `request(from:)` returns the page for `-SuiteGallery editor`, nil without the flag, `fakes` only with `-SuiteGalleryFakes`, width 240 for `-SuiteGalleryWidth 240` and nil for `abc`, `0` or `-5`; every name in `SuiteGallery.pages` resolves to exactly one page view and an unknown name to the empty state | a flag parses wrong, a page has no view, two areas declare one name, or the `window` page would recurse |
| SH-7 | The CI log lists `SuiteSmokeJourneys.testSecondFileRuns` from the second file and `SuiteJourneyTests.testGalleryOpensEveryPage` passes (SJ0); Flare, Design, Photo, Library and Halo journeys still run and their counts in `audit-baseline.json` are unchanged; the `suiteui` key is present at 0 for every check | the second file is not compiled, an app bundle stops building, or a gallery shot counts under `library` |
| SH-8 | `SuiteJourneyTests.testEveryControlMeetsHitSize` (SJ25) passes on every page; `SuiteJourneyTests+Budgets.swift` holds the section 7.1 placeholders as named constants that `Journey+Input`'s `perf()` reads | a listed control is under its hit size, or a constant is missing |
| SH-9 | `GoldenImageTests.reference` (QB-S31): identical 10 × 10 images pass with share 0; one pixel off by 3 (share 0.01) fails at `.standard` (`maxShare` 0.005) and passes at `maxShare` 0.01 and writes the actual and the diff; a size mismatch fails with share 1; a missing baseline writes the actual and records a known issue; `GoldenImageTests.compareWithinBudget` (QB-S15) | a tolerance is applied wrong, nothing is written, or a missing baseline passes silently |
| SH-10 | `SnapshotHostTests`: a 100 × 50 pt view renders 200 × 100 px; a 1 pt `hairline` is exactly 2 px wide (QB-S25); the high-contrast hosts resolve a dynamic token to its Increase Contrast value; `suiteGlass` in the host draws the stand-in at scale 2 | the scale, the hairline or the appearance is wrong |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-S15 golden compare of two 2,880 × 1,800 images | ≤ 150 ms median and p95 of 100 runs; debug gates the median ≤ 1.5 s and reports the p95 until ten green runs set its gate | `GoldenImageTests.compareWithinBudget` |
| QB-S16 probe summary over 10,000 samples | ≤ 2 ms (debug ≤ 20 ms) | `FrameProbeTests.summaryWithinBudget` |
| QB-S30 probe math equals a reference | exact p50, p95, dropped | `FrameProbeTests.referenceTable` |
| QB-S31 golden compare equals a reference | the three fixed images | `GoldenImageTests.reference` |
| QB-S25 hairline is 2 device px at 2× | exact | `SnapshotHostTests.hairline` |
| QB-S32 new token pairs meet their contrast | `docs/design.md` ratios | `TokensTests.contrast` |
| QB-S20 hit sizes | every `suite.controls` entry ≥ 20 × 20 pt or its token hit | SJ25 |
| QB-F1 no dead controls | `violations()` empty on every page | SJ0 |
| QB-F3 one gesture, one end | `EditRun` | `EditRunTests` |

Perf journey constants (section 7.1, QB-S1 to QB-S10) start as the
placeholders in `UITests/SuiteJourneyTests+Budgets.swift`; they are
report-only until ten green runs, and setting a gate is a later one-line PR.

## Decisions

- **Recording a new golden.** A golden test with no baseline must not turn
  `dev` red every time a feature adds a component, so `assertGolden` records
  a Swift Testing known issue (`withKnownIssue`) and writes the actual to
  `.build/snapshots/golden-new/`; the `snapshots` artifact carries it, and
  the feature's next PR commits it under `Golden/<area>/`. A baseline that
  exists and differs always fails. `Golden/README.md` (SH-9) writes this
  down. #331's "a missing baseline fails" holds for the compare itself:
  `GoldenResult.passes` is false.
- **Duplicate ids.** Two views registering one id is a violation only when
  both are on screen; `unregister` on disappear keeps a pushed page from
  counting twice.
- **Flare #347.** A note goes on #347 with this packet (Q9): feed
  `ControlInventory` through `.suiteControl`, publish no own `suite.controls`.

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR (SH-8) is green: SJ0, SJ25, the smoke test, and all five app journey
  bundles.
- **Audit zero new:** the `suiteui` key is 0 for every check; no app's count
  rises (SH-3 should lower `contrast` for flare, library and halo; the
  `Audit lower` job records that, nobody edits it by hand).
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue,
  with one line per gallery page shot (`suiteui-index-*`, one per stub) and
  the app shots SH-3 changed.
