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

**How the chain compiles.** `LiveScenes` is declared as a plain struct in
SN-1; SN-2, SN-3 and SN-4 add their methods in their own extension files, and
SN-5 adds `extension LiveScenes: SceneEditing {}` in its own file, so the
three middle tasks never touch one file.

**Matching the fake.** Live and fake agree on valid input, and on two edge
rules the fake already pins (`StageFakesEdgeTests`): `reorderScene` clamps
the index into range instead of throwing, and an empty name is not the
contract's to refuse (the workspace refuses it first with "Type a name for
the scene."). Undo names are the fake's ("Add Scene", "Delete Scene",
"Rename Scene", "Move Scene", "Set Canvas", "Move Guide"); where an LC-8
command's own label differs, the live call wraps it in
`engine.group(<fake's name>)`, which is still one entry.

**Counting commands.** The undo stack is internal to FlareCore, so "one
entry" is tested as one `undo()` restoring the document, and "one merged
command" as `MoveGuide`'s own `merge` returning true (LC-10).

## Journey steps

J2 (new from a preset), J14 (guides) and J16 (scenes) are the journeys;
their UI is F11b (#351), F3c (#375) and F11a (#350). This feature proves the
Model half on `LiveScenes`, in
`Tests/FlareModelTests/LiveScenesJourneyTests.swift` (SN-5):

1. New from "Vertical 9:16" (30 fps), then 60 fps: the scene is 1080 × 1920
   at 60 fps.
2. On `bounce`, add a scene: "Scene 2"; rename it "Outro"; set its
   background; reorder Outro above Scene 1; remove Outro. Each is one named
   entry and undoes exactly.
3. Removing the only scene throws "An animation needs at least one scene."
4. Add a horizontal guide at y 300; drag it to 320 in 20 coalesced steps:
   one "Undo Move Guide" (one `undo()` puts it back at 300); remove it.

## Screens and states

| Screen | Empty | Error | Loading |
|---|---|---|---|
| Layers tab, SCENES | never empty: a document has at least one scene | removing the last scene throws `FakeScenes.lastSceneMessage`; an unknown scene id throws `sceneNotFound` and changes nothing; an empty name is refused by the workspace first ("Type a name for the scene.", `FlareScenes.swift`); a reorder index out of range is clamped, as the fake does | none |
| SCENE section and New sheet | – | `SetSceneTiming` throws for fps ≤ 0 or a negative length, `SetSceneCanvas` (LC-8) for a zero or negative size; the workspace turns each into a plain sentence (`FlareLayerError`), never a case name | none |
| Guides | no guides: none drawn | a guide index out of range throws and changes nothing | – |

## Contract slice

No contract changes. `LiveScenes` conforms to `SceneEditing` in
`Sources/FlareModel/Contracts/SceneContracts.swift`:

```swift
public struct LiveScenes { public init() }   // : SceneEditing added in SN-5
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

renameScene(id, name): perform RenameScene(id, name), named "Rename Scene"            # SN-2
reorderScene(id, i):   i = min(max(i, 0), count - 1); perform ReorderScene(id, i), named "Move Scene"

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
| SN-2 | #362 (part) | `renameScene` and `reorderScene` on the LC-8 commands | `Sources/FlareModel/Live/LiveScenes+Order.swift`, `Tests/FlareModelTests/LiveScenesOrderTests.swift` | SN-1, creative-core#217 |
| SN-3 | #362 (part) | `setCanvas` (LC-8) and `setTiming` | `Sources/FlareModel/Live/LiveScenes+Canvas.swift`, `Tests/FlareModelTests/LiveScenesCanvasTests.swift` | SN-1, creative-core#217 |
| SN-4 | #362 (part) | Guides: add, remove, and a drag as one merged `MoveGuide` | `Sources/FlareModel/Live/LiveScenes+Guides.swift`, `Tests/FlareModelTests/LiveScenesGuidesTests.swift` | SN-1, creative-core#219 |
| SN-5 | #362 (closes) | The `SceneEditing` conformance, the model journey (steps 1–4) through `FlareWorkspace`, and live-equals-fake for every write on valid input | `Sources/FlareModel/Live/LiveScenes+SceneEditing.swift`, `Tests/FlareModelTests/LiveScenesJourneyTests.swift` | SN-2, SN-3, SN-4 |

SN-2, SN-3 and SN-4 can run side by side once SN-1 has merged; each owns its
own extension file. The issue lists one source and one test file; the packet
splits them so the three middle tasks own separate files, and the PRs say so. No file here is owned by another feature.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| SN-1 | `LiveScenesTests`: `newDocument(.vertical)` is 1080 × 1920 at 30 fps and equals the fake's; `addScene` on `bounce` returns "scene-2" named "Scene 2" in one "Undo Add Scene"; undo restores the document exactly; removing the only scene of `empty` throws `lastSceneMessage` and changes nothing | a name or id differs, undo is not exact, or the last scene goes |
| SN-2 | `LiveScenesOrderTests`: rename to "Outro" is one "Undo Rename Scene" and undoes exactly; reorder Outro to 0 puts it first in one "Undo Move Scene"; index -3 and 99 clamp to the ends, as `FakeScenes` does; an unknown id throws `sceneNotFound`; the document after each write equals the fake's | a name or order differs from the fake, an out-of-range index throws, or undo is not exact |
| SN-3 | `LiveScenesCanvasTests`: `setCanvas(1080, 1920, red)` changes size and background in one "Undo Set Canvas" and undoes exactly; width 0 throws and changes nothing; `setTiming(30, 150)` sets both; fps 0 and length -1 throw and change nothing | a zero size, fps 0 or a negative length lands, or the undo name differs from the fake |
| SN-4 | `LiveScenesGuidesTests`: add at y 300, then 20 `moveGuide` calls with one key end at 320 as one "Undo Move Guide" entry (one `undo()` puts it at 300); two `MoveGuide`s on one guide merge (`a.merge(b)` is true); a drag with a new key is a second entry; remove of index 5 on one guide throws; undo of each is exact | a drag leaves several entries, the commands don't merge, or a bad index lands |
| SN-5 | `LiveScenesJourneyTests.testNewAnimationFromPreset`, `.testScenesAddRenameReorderRemove`, `.testGuidesDragAsOneStep` walk steps 1–4 on a `FlareWorkspace` whose `services.scenes` is `LiveScenes()`; `.refusalsArePlainText` checks fps 0 and an empty name show sentences with no case names there; `liveEqualsFake` runs each valid write on `bounce` through both and compares documents and undo names | any step's values or undo names differ from J2, J14 and J16 |

## Quality tests

| quality row | budget | test |
|---|---|---|
| QB-F3 one gesture, one step | a guide drag is one entry and its commands merge; every scene write is one named entry | `LiveScenesGuidesTests.dragIsOneEntry`, `LiveScenesTests` (one `undo()` restores) |
| QB-L7 one drag step | ≤ 10 ms debug per `moveGuide` step on `bounce` | `LiveScenesGuidesTests.dragStepWithinBudget` (median of 50) |
| QB-F2 plain refusals | every refusal the person sees reads as a sentence, no type or case names | `LiveScenesJourneyTests.refusalsArePlainText` (through the workspace) |

## Done check

- **Journeys green:** the macOS run on `dev` triggered by the `feature-done`
  PR (SN-5) is green, `FlareJourneyTests` included.
- **Audit zero new:** no Flare count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue;
  no Flare screen changes (the live type is not wired until IN-4), and the
  comment says so.
