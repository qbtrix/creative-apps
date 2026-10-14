# Feature packet: live-scenes

**Feature:** scenes and guides on real documents. New from a preset, add,
rename, reorder and remove scenes, set a scene's canvas, background, frame
rate and length, and add, drag and remove ruler guides, all as FlareCore
commands with exact undo.
**Line:** `line:flare` · **Wave:** 2 (`waves.md`) · **Lead branch:** `lead/live-scenes`

**Covers:** #362 (LM-9). It closes with SN-5.

**Depends on:** qbtrix/creative-core#217 (LC-8 `SetSceneCanvas`,
`RenameScene`, `ReorderScene`), qbtrix/creative-core#219 (LC-10 `MoveGuide`
merge). Neither had landed on creative-core `main` cfad97f (2026-10-14).
SN-1 uses commands that exist today (`AddScene`, `RemoveScene`,
`SetSceneTiming`, `AddGuide`, `RemoveGuide`) and can start at once.

Where it starts from: `FakeScenes` already runs add, remove, timing and
guides on FlareCore and swaps in a `FixtureEdit` for rename, reorder and
canvas. The live type replaces those three with the LC-8 commands and makes
a guide drag one merged command; it holds no `FixtureEdit` (live-stage's
ST-5 scan fails on it). The workspace rules on top (the last scene can't be
removed, a scene a machine uses can't be removed, a rename to the same name
adds no step) live in `FlareScenes.swift` and `FlareGuides.swift` and stay
as they are. Blueprint sections: 3.1 (Layers tab, SCENE section), 3.3 (New
Animation sheet), 6.2 (`SceneEditing`), 7.5 (LM-9).

## Journey steps

J2 (new from a preset), J14 (guides) and J16 (scenes) are the journeys;
their UI is F11b (#351), F3c (#375) and F11a (#350). This feature proves the
Model half on `LiveScenes`, in
`Tests/FlareModelTests/LiveScenesJourneyTests.swift` (SN-5):

1. New from "Vertical 9:16", then 30 fps: the scene is 1080 × 1920 at 30 fps.
2. On `bounce`, add a scene: "Scene 2"; rename it "Outro"; set its
   background; reorder Outro above Scene 1; remove Outro. Each is one named
   entry and undoes exactly.
3. Removing the only scene throws "An animation needs at least one scene."
4. Add a horizontal guide at y 300; drag it to 320 in 20 coalesced steps:
   one "Undo Move Guide" holding one command; remove it.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Layers tab, SCENES | never empty: a document has at least one scene | removing the last scene throws `FakeScenes.lastSceneMessage`; an unknown scene id throws and changes nothing; an empty name is refused by the workspace first ("Type a name for the scene.", `FlareScenes.swift`), and `RenameScene` (LC-8) throws on one too | none |
| SCENE section and New sheet | – | zero or negative size, fps outside 1...120 or a length under 1 throws with plain text (LC-8 and `SetSceneTiming` validation) | none |
| Guides | no guides: none drawn | a guide index out of range throws and changes nothing | – |

## Contract slice

No contract changes. `LiveScenes` conforms to `SceneEditing` in
`Sources/FlareModel/Contracts/SceneContracts.swift`:

```swift
public struct LiveScenes: SceneEditing { public init() }
//   newDocument(_:)                                   pure
//   addScene(_:in:) -> String                         single "Add Scene"
//   renameScene(_:to:in:)                             single "Rename Scene"  (RenameScene, LC-8)
//   removeScene(_:in:)                                single "Delete Scene"
//   reorderScene(_:to:in:)                            single "Move Scene"    (ReorderScene, LC-8)
//   setCanvas(_:width:height:background:in:)          single                 (SetSceneCanvas, LC-8)
//   setTiming(_:fps:durationFrames:in:)               single                 (SetSceneTiming)
//   addGuide / removeGuide                            single
//   moveGuide(at:to:sceneID:coalesceKey:in:)          coalescible, one merged MoveGuide (LC-10)
```

Undo names match `FakeScenes` exactly, so the journeys read the same Edit
menu on fake and live.

## Pseudocode

```
newDocument(preset): Document(scenes: [scene("scene-1", "Scene 1", preset)])          # SN-1, same as the fake
addScene(preset):    id = next free "scene-n"; perform AddScene(scene(id, "Scene n", preset)); return id
removeScene(id):     guard doc.scenes.count > 1 else throw lastSceneMessage; perform RemoveScene(id)

renameScene(id, name): perform RenameScene(id, name)  # LC-8 validates; the workspace trims  # SN-2
reorderScene(id, i):   guard 0 <= i < count; perform ReorderScene(id, i)

setCanvas(id, w, h, bg): perform SetSceneCanvas(id, w, h, bg)                         # SN-3
setTiming(id, fps, n):   perform SetSceneTiming(id, fps, n)

addGuide(axis, pos, scene):     perform AddGuide                                       # SN-4
moveGuide(i, pos, scene, key):  engine.perform(MoveGuide(...), coalesceKey: key)      # top level; LC-10 merges
removeGuide(i, scene):          perform RemoveGuide
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: live-scenes`, `Fast-Check:
pass`, `Head:`. SN-5 also carries `feature-done`.

| id | issue | what | owned files | depends on |
|---|---|---|---|---|
| SN-1 | #362 (part) | `LiveScenes`: `newDocument`, `addScene`, `removeScene` (never the last) | `Sources/FlareModel/Live/LiveScenes.swift`, `Tests/FlareModelTests/LiveScenesTests.swift` | – |
| SN-2 | #362 (part) | `renameScene` and `reorderScene` on the LC-8 commands | `Sources/FlareModel/Live/LiveScenes.swift`, `Tests/FlareModelTests/LiveScenesOrderTests.swift` | SN-1, creative-core#217 |
| SN-3 | #362 (part) | `setCanvas` (LC-8) and `setTiming` | `Sources/FlareModel/Live/LiveScenes+Canvas.swift`, `Tests/FlareModelTests/LiveScenesCanvasTests.swift` | SN-1, creative-core#217 |
| SN-4 | #362 (part) | Guides: add, remove, and a drag as one merged `MoveGuide` | `Sources/FlareModel/Live/LiveScenes+Guides.swift`, `Tests/FlareModelTests/LiveScenesGuidesTests.swift` | SN-1, creative-core#219 |
| SN-5 | #362 (closes) | The model journey (steps 1–4) and live-equals-fake for every write | `Tests/FlareModelTests/LiveScenesJourneyTests.swift` | SN-2, SN-3, SN-4 |

SN-2, SN-3 and SN-4 can run side by side once SN-1 has merged; SN-2 stacks
on SN-1 because both edit `LiveScenes.swift`. The issue lists one source and
one test file; the packet splits them so the three middle tasks own separate
files, and the PRs say so. No file here is owned by another feature.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| SN-1 | `LiveScenesTests`: `newDocument(.vertical)` is 1080 × 1920 at 30 fps and equals the fake's; `addScene` on `bounce` returns "scene-2" named "Scene 2" in one "Undo Add Scene"; undo restores the document exactly; removing the only scene of `empty` throws `lastSceneMessage` and changes nothing | a name or id differs, undo is not exact, or the last scene goes |
| SN-2 | `LiveScenesOrderTests`: rename to "Outro" is one "Undo Rename Scene" and undoes exactly; an empty name throws (`RenameScene` validation); reorder Outro to 0 puts it first in one "Undo Move Scene"; index -1 and `count` throw; the document after each write equals the fake's | an empty name lands, an out-of-range move lands, or live and fake differ |
| SN-3 | `LiveScenesCanvasTests`: `setCanvas(1080, 1920, red)` changes size and background in one entry and undoes exactly; width 0 throws; `setTiming(30, 150)` sets both; fps 0 throws with plain text (no type names) | a zero size lands, or a refusal shows debug text |
| SN-4 | `LiveScenesGuidesTests`: add at y 300, then 20 `moveGuide` calls with one key end at 320 as one "Undo Move Guide" entry holding one command; a drag with a new key is a second entry; remove of index 5 on one guide throws; undo of each is exact | a drag leaves several entries or commands, or a bad index lands |
| SN-5 | `LiveScenesJourneyTests.testNewAnimationFromPreset`, `.testScenesAddRenameReorderRemove`, `.testGuidesDragAsOneStep` walk steps 1–4; `liveEqualsFake` runs each write on `bounce` through both and compares documents and undo names | any step's values or undo names differ from J2, J14 and J16 |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-F3 one gesture, one step | a guide drag is one entry holding one command; every scene write is one named entry | `LiveScenesGuidesTests.dragIsOneCommand`, `LiveScenesTests` (undo counts) |
| QB-L7 one drag step | ≤ 10 ms debug per `moveGuide` step on `bounce` | `LiveScenesGuidesTests.dragStepWithinBudget` (median of 50) |
| QB-F2 plain refusals | every throw reads as a sentence, no type or case names | `LiveScenesCanvasTests.refusalsArePlainText` |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR (SN-5) is green, `FlareJourneyTests` included.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue;
  no Flare screen changes (the live type is not wired until IN-4), and the
  comment says so.
