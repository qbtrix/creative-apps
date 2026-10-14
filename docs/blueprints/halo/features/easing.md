# Feature packet: easing

**Feature:** Ease keys. Pick a key from the inspector's EASING rows or the
timeline, give it Linear, Ease In, Ease Out, Ease In and Out or Hold from
the Animation menu, the timeline's context menu or the EASING chips, or bend
its curve by hand. Each change is one "Keyframe Easing" undo step, sampled
by FlareCore's `Timeline.value(of:at:)` and saved with the project.
**Line:** `line:halo` · **Wave:** W2 (`waves.md`) · **Lead branch:** `lead/easing`

**Covers:** #428. It closes with EZ-8, the `feature-done` PR; EZ-1 to EZ-7
say "Part of #428".

**Depends on:** the layer-keys and history-files feature issues (keys to
ease, a live history whose Undo the journey reads and presses) and #333 (the
journey lives in `UITests/HaloJourneyTests+Easing.swift`, which
`project.yml` doesn't compile until QH-4 lands). The feature issue is filed
only once all three are closed, and its one `Depends on:` line names the one
that closed last. Only EZ-8 needs #333, but the issue waits for it anyway so
the lead can build every task. Not blocking: #771 (key shapes by easing and a
selected-keys set; plain diamonds meanwhile, the picked keys show in the
EASING rows) and #63 (keys from the keyboard; the EASING rows are buttons, so
keys are picked from the keyboard there). No creative-core issue: FlareCore
`Easing` and `Timeline.value` already ease (blueprint 8.4).

Blueprint sections it builds on: 2 (one undo step, `edit`, where a
property's value lives, commands and availability, launch arguments, the
`keyed` and `reference` fixtures), 4 (H-J7 and its states row), 5
(`KeyEasing`, `FakeKeyEasing`, `HaloEasingPreset`, `HaloKeyRef`, the
`HaloKeySelection.swift` row of the workspace methods), 6 (EASING and
Timeline rows, the easing area of the command table), 7.1 (HB-7), 7.4
(HF-4), 8.3 (easing's owned files). Read the easing parts of
`docs/blueprints/flare/features/live-keys.md` and Flare's
`FlareEasingInspector.swift` first: they are the house shape. The packet wins
over the blueprint and over #428's body where they differ; see "Review notes
folded in".

**Building blind.** EZ-6 and EZ-7 are in `Sources/HaloApp/` and
`Tests/AppSnapshotTests/`, EZ-8 in `UITests/`; the Linux gate compiles none
of them. Copy the shape of `Sources/FlareApp/FlareEasingInspector.swift`
(which builds), check every SwiftUI and AppKit API with the `apple-docs` MCP
(say so in the PR), keep views dumb, and put every decision (which rows
exist, what a row reads, which chip is on, where the handles sit, what a
handle drag makes) in HaloModel, EZ-1 to EZ-5. `CurveEditor`, `ChoiceChips`
and `StudioScrubRow` are already in `Sources/SuiteUI/` (#343 is still open
for polish, not for the type), so no placeholder is needed.

**Shared-file rule.** This feature owns only the files in its task rows. It
never edits `Sources/SuiteUI/**`, `project.yml`, `UITests/Journey*.swift`,
`Tests/AppSnapshotTests/AppSnapshotTests.swift`, `docs/c4/model.json`,
`docs/design.md`, `HaloProject.swift`, `HaloCommand.swift`,
`HaloWindow.swift`, `HaloViewer.swift`, the menu files or
`HaloLayerInspector.swift` (W0 made the EASING slot there, layer-keys kept
it). The Animation menu's Keyframe Easing items already exist (FD-16) and
send their commands through `HaloWindow.perform` to `HaloWindow+Easing.swift`.

## Journey steps

**H-J7** `testEaseKeys` in `UITests/HaloJourneyTests+Easing.swift` (its own
`XCTestCase`), on `-HaloSample keyed`: EZ-1 lands the live type first, and
keys (layer-keys) and history (history-files) are live by then. No step reads
the viewer. One shot per step, named `halo-easing-<step>`.

1. Select Ball in LAYERS. EASING lists "Position X 0 → 24" and "Opacity
   0 → 12", none picked, and reads "Pick a key above.".
2. Open Animation > Keyframe Easing: all five items are disabled with help
   "Pick a key in the EASING list first.".
3. Click the row "Position X 0 → 24": it is selected; the chips, the curve
   (`halo.easing`) and X1, Y1, X2, Y2 appear; Linear is the chip that is on.
4. Click the chip "Ease In and Out": the row's value reads "Ease In and Out";
   the Edit menu's first item reads "Undo Keyframe Easing".
5. Scrub to 12: Position X reads "560.0 px" (the eased midpoint equals the
   linear one for this symmetric curve). Scrub to 6: Position X reads below
   "360.0 px" (parse the number, assert < 360).
6. Drag `halo.easing.handle1` 40 pt right: no chip has the selected trait;
   the row reads "Custom"; Edit still reads "Undo Keyframe Easing".
7. Right-click `halo.timeline`, choose Hold: the row reads "Hold"; at frame 6
   Position X reads "160.0 px". (EZ-7's context menu)
8. ⌘Z three times: the row reads "Custom", then "Ease In and Out", then
   "Linear"; at frame 6 Position X reads "360.0 px". The row stays picked:
   selection is not a step.

The Model half runs on Linux first: `HaloEasingTests.testEaseKeysJourney`
walks steps 1 to 8 on `.fake` and `.live`.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Inspector, EASING | no layer selected: no EASING group (the layer inspector shows "Select a layer to see its properties."); a layer with no property of two or more keys: "Key a property to shape its easing."; segments but none picked: the rows and "Pick a key above." | a refused edit (a picked key gone after an undo elsewhere: "That layer no longer exists.") shows in `SuiteFont.caption` under the group, control `halo.easing` | none |
| Timeline | plain diamonds as W0 draws them (#771); nothing picked: the context menu's five items disabled with "Pick a key in the EASING list first." | none | none |
| Animation > Keyframe Easing | the five items disabled with the reasons below | none | none |

## Contract slice

No contract changes: `KeyEasing`, `HaloKeyRef`, `HaloEasingPreset` and
`HaloEditError.noKeySelected` are as W0 copied them. What this feature adds:

```swift
// Live/HaloEasingRules.swift (EZ-1), internal: the one place both conformers read
enum HaloEasingRules {
    static func keys(of layerID: String, in c: HaloComposition) -> [HaloKeyRef]   // by HaloProperty.allCases, then frame
    static func easing(of key: HaloKeyRef, in c: HaloComposition) -> HaloEasing?
    static func setEasing(_ e: HaloEasing, on keys: Set<HaloKeyRef>, in c: inout HaloComposition) throws
}
public struct LiveKeyEasing: KeyEasing { /* unavailableHelp nil; calls HaloEasingRules */ }
public struct FakeKeyEasing: KeyEasing { /* thin wrapper over HaloEasingRules */ }

// HaloKeySelection.swift (EZ-2, EZ-3)
public struct HaloKeySegment: Identifiable, Sendable, Hashable {
    public var id: HaloKeyRef { key }
    public var key: HaloKeyRef          // the segment's first key
    public var endFrame: Int            // the next key on the same track
    public var easing: HaloEasing
    public var preset: HaloEasingPreset? { HaloEasingPreset(easing) }
    public var isPicked: Bool
    public var title: String            // "Position X 0 → 24"
    public var easingTitle: String      // preset?.title ?? "Custom"
}
public enum HaloEasingHandle: Sendable { case first, second }
extension HaloProject {
    public var keySegments: [HaloKeySegment] { get }          // selected layer, property order then frame
    public var pickedSegment: HaloKeySegment? { get }         // the first picked: the curve shows it
    public var pickedPreset: HaloEasingPreset? { get }        // the preset every picked key shares, else nil
    public var easingHandles: (first: HaloPoint, second: HaloPoint)? { get }
    public func easingCurve(count: Int) -> [HaloPoint]        // Easing.value(at:) of pickedSegment
    public mutating func selectKey(_ key: HaloKeyRef, extending: Bool)
    public mutating func selectLaneKeys(layerID: String, frame: Int, extending: Bool)  // timeline diamond
    public mutating func clearKeySelection()
    public mutating func setEasing(_ preset: HaloEasingPreset)                   // "Keyframe Easing"
    public mutating func setCustomEasing(_ easing: HaloEasing, coalesceKey: String?)
    public mutating func moveEasingHandle(_ handle: HaloEasingHandle, to point: HaloPoint)
}
```

`selectedKeys` is W0's stored property; only `HaloKeySelection.swift` writes
it. `selectLaneKeys` exists because `TimelineStrip.onSelectKeyframe` gives a
lane and a frame, not a property; it is the timeline's form of `selectKey`.
The undo name is "Keyframe Easing" (blueprint section 2), not Flare's "Set
Keyframe Easing".

## Pseudocode

```
HaloEasingRules.setEasing(e, keys, &c):                       # EZ-1
  guard !keys.isEmpty else throw .noKeySelected
  if case .cubicBezier(x1, y1, x2, y2) = e: guard all finite else throw .notANumber(first key's property)
                                            e = .cubicBezier(clamp(x1, 0...1), y1, clamp(x2, 0...1), y2)
  var copy = c; for key in keys { find layer and key or throw .unknownLayer(key.layerID); set easing }
  c = copy                                                     # a throw changes nothing

keySegments:                                                   # EZ-2
  guard let layer = selectedLayer else []
  for p in HaloProperty.allCases, track = layer.tracks[p] where track.count >= 2:
    for (k, next) in zip(track, track.dropFirst()):
      HaloKeySegment(key: (layer.id, p, k.frame), endFrame: next.frame, easing: k.easing,
                     isPicked: selectedKeys.contains(key))
pickedKeys = Set(keySegments.filter(\.isPicked).map(\.key))    # stale or other-layer keys drop out

selectKey(key, extending):                                     # not an edit, never a step
  guard keySegments contains key else return
  selectedKeys = extending ? pickedKeys.symmetricDifference([key]) : [key]
selectLaneKeys(layerID, frame, extending):
  if layerID != selectedLayerID { selectLayer(layerID); extending = false }
  starts = keySegments.filter { $0.key.frame == frame }.map(\.key)
  selectedKeys = extending ? pickedKeys ∪ starts : Set(starts)

setEasing(preset):                                             # EZ-3
  let keys = pickedKeys, easing = services.easing              # copy first: edit is mutating
  edit("Keyframe Easing", control: "halo.easing") { doc in
    try easing.setEasing(preset.easing, on: keys, in: &doc.<selected composition>) }
  # same preset again: the copy equals the document, so no step (edit's guard)

moveEasingHandle(h, point):
  guard let seg = pickedSegment, point finite else return
  (a, b) = handles of seg.easing                               # linear and hold: (0,0), (1,1)
  replace h with (clamp(point.x, 0...1), point.y)
  setCustomEasing(.cubicBezier(a, b), coalesceKey: "\(seg.key.layerID).easing")
# the view calls endCoalescing() (W0) from CurveEditor.onEnd and StudioScrubRow.onEnd

unavailableHelp(easing command):                               # EZ-5
  no composition -> "Create a composition first."; no layer -> "Select a layer first."
  services.easing.unavailableHelp ?? (pickedKeys.isEmpty ? "Pick a key in the EASING list first." : nil)
```

Write the handle math as `HaloEasing` helpers in `HaloKeySelection.swift`,
not a copy of FlareModel's `EasingCurve` (another line's file, and the
duplicate gate counts it). If jscpd still flags it, file `needs-core` on
creative-core for `Easing.handles` and `Easing.movingHandle` and keep going.

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: easing`, `Fast-Check: pass`,
`Head:`. EZ-8 also carries `feature-done`.

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| EZ-1 | #428 (part) | `LiveKeyEasing` over FlareCore `Easing` through the shared `HaloEasingRules` (finite check, handle x clamped to 0...1); `FakeKeyEasing` becomes a thin wrapper; the contract suite runs `[fake, live]` | `Sources/HaloModel/Live/HaloEasingRules.swift`, `Sources/HaloModel/Live/LiveKeyEasing.swift`, `Sources/HaloModel/Fakes/FakeKeyEasing.swift`, `Tests/HaloModelTests/KeyEasingContractTests.swift` | – | ~200 |
| EZ-2 | #428 (part) | `HaloKeySegment`, `HaloEasingHandle`, `keySegments`, `pickedSegment`, `pickedPreset`, `selectKey(_:extending:)`, `selectLaneKeys`, `clearKeySelection()`; none records a step | `Sources/HaloModel/HaloKeySelection.swift`, `Tests/HaloModelTests/HaloKeySelectionTests.swift` | EZ-1 | ~240 |
| EZ-3 | #428 (part) | `setEasing(_:)` as one "Keyframe Easing" step; `setCustomEasing(_:coalesceKey:)`, `moveEasingHandle`, `easingHandles`, `easingCurve(count:)`; HF-4; the Model journey | `Sources/HaloModel/HaloKeySelection.swift`, `Tests/HaloModelTests/HaloEasingTests.swift` | EZ-2 | ~320 |
| EZ-4 | #428 (part) | HB-7 | `Tests/HaloModelTests/HaloEasingBudgetTests.swift` | EZ-3 | ~70 |
| EZ-5 | #428 (part) | `HaloAvailability+Easing.swift` turns on the five Keyframe Easing commands when a key is picked | `Sources/HaloModel/Availability/HaloAvailability+Easing.swift`, `Tests/HaloModelTests/HaloEasingAvailabilityTests.swift` | EZ-3 | ~110 |
| EZ-6 | #428 (part) | App: the EASING group (segment rows with their easing as value, `ChoiceChips` for the five presets, `CurveEditor` id `halo.easing`, X1 Y1 X2 Y2 `StudioScrubRow`s, the two empty texts, the refusal caption), every control through `.haloControl`; `HaloWindow+Easing.swift` routes the five commands to `setEasing` and gives the group its closures | `Sources/HaloApp/HaloEasingInspector.swift`, `Sources/HaloApp/HaloWindow+Easing.swift`, `Tests/AppSnapshotTests/HaloEasingSnapshots.swift` | EZ-5 | ~330 |
| EZ-7 | #428 (part) | App: a diamond click calls `selectLaneKeys` (Shift from `NSEvent.modifierFlags` extends); the strip's context menu holds the five presets for the picked keys, each disabled with `unavailableHelp(for:)` as help; plain diamonds until #771; everything the view does today kept | `Sources/HaloApp/HaloTimelineView.swift` | EZ-6 | ~140 |
| EZ-8 | #428 (closes; `feature-done`) | H-J7 `testEaseKeys`, steps 1 to 8, on `-HaloSample keyed` | `UITests/HaloJourneyTests+Easing.swift` | EZ-6, EZ-7, #333 | ~190 |

The Model chain is EZ-1 → EZ-2 → EZ-3 → (EZ-4 ∥ EZ-5); the app chain is
EZ-6 → EZ-7 → EZ-8. EZ-2 and EZ-3 share `HaloKeySelection.swift` and chain;
EZ-6 needs EZ-5 so its chips and menu read real availability. The 8.3 list's
`HaloEasingTests` stays the HF-4 and journey file; the selection tests and
the availability tests get their own new files so no task passes 400 lines.

**Inspector slot.** W0 (FD-15) gives every slot view one initializer,
`init(model: HaloProject, perform: @escaping (HaloCommand) -> Void)`, and
`HaloCommand` (FD-11) carries payload cases such as `.setEasing(preset)` and
`.selectKey(ref, extending:)`. EZ-6 replaces the body of
`HaloEasingInspector` and routes those commands in `HaloWindow+Easing.swift`;
it never edits `HaloLayerInspector.swift`. If a command it needs has no case
yet, that is a one-case addition to W0's `HaloCommand.swift`, which no W2
feature owns: comment on the feature issue and the supervisor adds it.

**The W0 stub check.** FD-7's `HaloServicesTests` checks an invariant (a
live service either has nil help or throws `.notBuilt` with help), so
`LiveKeyEasing` turning on doesn't touch that file; the "still a stub"
assert lives in `KeyEasingContractTests`, which EZ-1 rewrites.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| EZ-1 | `KeyEasingContractTests` over `[fake, live]` on `keyed`: `keys(of: "Ball")` is x 0, x 24, opacity 0, opacity 12 in that order; `setEasing(.easeIn)` on x 0 makes `easing(of:)` `.easeIn` and Position X at 12 below 560; an empty set throws `.noKeySelected`; a key at x 7 throws `.unknownLayer("Ball")` and the composition is unchanged; `.cubicBezier(1.4, 0, 0.58, 1)` is stored with x1 1.0; `.cubicBezier(.nan, …)` throws and changes nothing; `LiveKeyEasing().unavailableHelp == nil` | the live type misses a key, eases the wrong key, lands a partial or non-finite change, or still says it isn't built |
| EZ-2 | `HaloKeySelectionTests` on `keyed` (`.fake`): Ball's `keySegments` titles are "Position X 0 → 24" and "Opacity 0 → 12", both "Linear"; Floor's are empty; `selectKey(x 0)` picks one, Shift on opacity 0 picks two, Shift on x 0 again leaves opacity 0; a key at x 24 (a track's last) changes nothing; `selectLaneKeys("Ball", 0)` picks x 0 and opacity 0, at 12 picks none; selecting Floor empties `pickedSegment`; `history` is unchanged after every call | a row is missing, a last key can be picked, Shift doesn't toggle, or a pick records a step |
| EZ-3 | `HaloEasingTests` on `keyed` over `[.fake, .live]`: HF-4 (below); with x 0 picked, Ease In gives x at 12 below 560, Ease Out above, Linear exactly 560, Hold 160 at 23 and 960 at 24; Ease In on two picked keys (x 0, opacity 0) is one step titled "Undo Keyframe Easing" and one `undo()` restores both to Linear; Ease In twice is one step; 30 `moveEasingHandle` calls are one step and after `endCoalescing()` the next is a new one; after a handle move `pickedPreset` is nil and the row reads "Custom"; the easing survives `fileData()` then `services.files.decode` and `finishOpen`; `testEaseKeysJourney` walks steps 1 to 8 | an easing samples wrong, a gesture is zero or two steps, or easing is lost on save |
| EZ-4 | `HaloEasingBudgetTests.easingStep` (below) | over budget |
| EZ-5 | `HaloEasingAvailabilityTests` on `keyed` over `[.fake, .live]`: with Ball selected and nothing picked, each of the five commands reads "Pick a key in the EASING list first."; after `selectKey(x 0)` all five are nil; with no layer "Select a layer first."; on `empty` with no composition "Create a composition first."; W0's `HaloCommandTests` invariant still holds | an item turns on with nothing picked, stays off with a pick, or has no help |
| EZ-6 | Snapshots in `HaloEasingSnapshots` (macOS), `.fake` on `keyed` with Ball: `halo-easing-light/dark.png` (x 0 picked with Ease In and Out: the rows, the chip on, the curve, the four numbers), `halo-easing-unpicked-light/dark.png` ("Pick a key above."), `halo-easing-empty-light/dark.png` (Floor: "Key a property to shape its easing."); the macOS build on `dev` | the group is blank, a chip or the curve doesn't match the picked easing, or an empty text is missing |
| EZ-7 | The macOS build on `dev` and H-J7 step 7 (EZ-8); `selectLaneKeys` is covered by EZ-2; `halo-timeline-keys-*` (FD-15) unchanged | a diamond click stops scrubbing or selecting the layer, I or O stop working, or the menu acts with nothing picked |
| EZ-8 | H-J7 on the `dev` CI run | any step's assert |

## Quality tests

| quality row | budget | test |
|---|---|---|
| HB-7 easing chip | `setEasing` on two keys plus `keySegments` on `reference` (first layer, two picked keys): ≤ 1 ms device, ≤ 10 ms debug CI, median over 200 | `HaloEasingBudgetTests.easingStep` (EZ-4), with W0's `HaloBudget.swift` |
| HF-4 easing fidelity | Position X of Ball at frames 6, 12, 18 for each of the five presets on x 0 equals `160 + 800 × preset.easing.value(at: f / 24)`, exact; Hold equals 160 at 6, 12, 18 and 23 | `HaloEasingTests.positionFollowsEachPreset` (EZ-3), `.fake` and `.live` |
| QB-F1 no dead controls | the five commands, the context menu and the chips act or say why | `HaloEasingAvailabilityTests` (EZ-5), H-J7 step 2, H-J13 |
| QB-F2 immediate feedback | the row's value and the inspector's Position X change with the chip; the diamond shape waits on #771 | H-J7 steps 4, 5 |
| QB-F3 one gesture, one step | a chip, a menu item and a whole handle drag are one "Keyframe Easing" step each; picking keys is none | `HaloEasingTests`, `HaloKeySelectionTests`, H-J7 step 8 |
| QB-F4 keyboard parity | rows are buttons and the curve nudges with arrows (SuiteUI) | H-J13 sweep; #63 for the diamonds |
| Audit | no `halo` count up; each new control has a `halo.easing.*` identifier | `audit-halo-*.json` on the `feature-done` run |

If HF-4's exact compare fails only in the last bit (FlareCore may lerp as
`a + (b − a) × t` or `a × (1 − t) + b × t`), compute the reference the same
way FlareCore does and keep "exact"; record it in RECORD.md.

## Done check

- **Journeys green:** the macOS run on `dev` triggered by EZ-8's
  `feature-done` PR is green, with H-J7 passing and every other Halo journey
  (H-J0 to H-J13 that exist by then) unchanged.
- **Audit zero new:** no `halo` count over `UITests/audit-baseline.json`;
  the PR bodies of EZ-6 and EZ-7 state the counts they expect.
- **Contact sheet:** the lead comments on the feature issue with
  `Belt-Contact-Sheet: <run link>`, one line per H-J7 step and the audit
  counts. Expected new shots: `halo-easing-*` (eight steps) and the
  EASING group in the controls sweep; the timeline shows plain diamonds.

## Review notes folded in

From the review of the blueprint PR (#767) and #428's body, where they
change this feature:

- **Files.** #428 names `HaloKeyEasingMenu.swift`, edits to
  `HaloCommands.swift` and a journey in `UITests/HaloJourneyTests.swift`.
  The packet wins: the menu items exist since FD-16 and route to
  `HaloWindow+Easing.swift`, the context menu lives in
  `HaloTimelineView.swift`, and the journey has its own file (#333).
- **Test numbers.** #428's `HaloEasingTests` uses keys at 0 (x 0) and 30
  (x 100). The packet uses the `keyed` fixture instead (Ball x 160 at 0, 960
  at 24) so the Model test, HF-4 and H-J7 read one set of numbers; every
  check #428 asks for (below and above the midpoint, Hold, Linear, two keys
  in one step, Undo restores Linear, the file round trip) is kept.
- **Diamond shapes.** #428 asks for shapes by easing and a snapshot of
  three shaped keys. `TimelineStrip` can't draw them yet: #771 (filed). Plain
  diamonds meanwhile; `halo-easing-*.png` shows the EASING group instead,
  and the shape snapshot moves to the PR that adopts #771.
- **Per-key context menu.** `TimelineStrip` reports a diamond click but has
  no per-key context menu, so the strip's menu acts on the picked keys. #771
  can add a per-key form.
- **⌘Z is allowed here.** W1 journeys other than history-files' may only
  read the Undo title; easing is W2 and filed after history-files, so H-J7
  presses ⌘Z.
- **No shared docs.** The `halo-keying` C4 description already names
  selected keys and "Keyframe Easing"; this feature edits neither
  `docs/c4/model.json` nor `docs/design.md`.
