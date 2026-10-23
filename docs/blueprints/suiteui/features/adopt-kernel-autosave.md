# Feature packet: adopt-kernel-autosave

**Feature:** every editor autosaves and recovers through one path: the
kernel's `AutosaveSchedule` (when to write), SuiteModel's `RecoveryFolder`
over `FileStore` (where and how), and SuiteUI's `.autosaveRecovery` modifier
(the tick and the offer at launch). Every app's support files live under one
root, `SuiteLocations.appFolder(<App>)` inside
`~/Library/Application Support/AfterGlow/`, so one `-SuiteSupportDir` reaches
every app's recovery copies and Library's catalog. Flare's own writer and
recovery file go; Photo's recovery folder and Library's catalog move under the
root, each moving what an earlier build left at the old place exactly once.
**Line:** `line:suiteui` · **Wave:** XK3 (`waves.md`, the canonical burn-down) · **Lead branch:** `lead/adopt-kernel-autosave`
**Beta:** captain, 2026-10-20 (canonical burn-down, audit rank 1: a crash loses work). Labels `beta` and `p0` when filed.

**Covers:** the canonical duplicates audit
(`paw-workspace/docs/design/drafts/2026-10-20-canonical-duplicates-audit.md`),
top-15 #1; feature map S12's Flare and Library adopter rows (this packet);
real job RJ-X44 (new). It also closes the Flare row of autosave-history's
"Adopted later", which the captain pulled into the beta.

**What other packets already do (this one does not repeat it):**
- **`.autosaveRecovery` finished:** suiteui autosave-history AH-8 (slice
  AH-z) fills the modifier's body. This packet waits on AH-z and owns no
  SuiteUI file.
- **Halo and Design gain recovery:** halo/autosave-history (HA) and
  design/autosave-history (DA), both beta, put the modifier on their windows.
  This packet's AK-9 journey proves all four editors recover from the one
  root once they land.
- **Photo's `PhotoAutosave` deleted:** photo/history-panel PH-6. AK-photo
  only moves Photo's folder under the root and drops `-PhotoRecoveryDir`.

**Depends on:** autosave-history (suiteui): AK-2 waits on AH-a (the C4 part
`suite-store.json`), AK-4 and AK-9 on AH-z. SuiteModel's `FileStore`,
`RecoveryFolder` (AH-7, merged) and `SuiteLocations` (built). No
creative-core issue.

**Hand-offs** (cross-line; the lead checks each before the slice starts):
- **AK-flare:** `FlareWindow.swift` is shared with svg-place's PF-u
  (planned): AK-4 rebases onto it.
- **AK-library:** `CatalogStore.swift` is library/spine's (building): AK-6
  starts after spine's feature-done.
- **AK-photo:** `LiveRecovery.swift` and `PhotoWindow+File.swift` are
  photo/history-panel PH-m's, and `PhotoWindow+File.swift` also photo/file-flow
  PF-m's: AK-8 starts after PH-z.
- **Design and Halo:** DA-m and HA-m build their `RecoveryFolder` on
  `FileStore(folder: SuiteLocations.appFolder("Design" | "Halo", …))`. AK-a
  is two small tasks, so it lands first; if one of them lands earlier, AK-9's
  journey catches a copy outside the root.

**Rule 20.** One autosave timing (`AutosaveSchedule`), one recovery store
(`RecoveryFolder`), one support root (`SuiteLocations`), one launch flag
(`-SuiteSupportDir`). A shrink-only ratchet holds the root:
`SupportFolderRatchetTests` fails on any `.applicationSupportDirectory` outside
`SuiteLocations.swift`, with today's three hits baselined until their slices
remove them.

**Why one folder per app, not one shared `Recovery/`:** `RecoveryFolder`
drops and deletes any pair it can't read with its own extension
(`leftBehind`). Two apps sharing one `Recovery/` folder would delete each
other's copies, the data loss this packet exists to stop. So every app's store
is `AfterGlow/<App>/`, and its recovery copies are in `AfterGlow/<App>/Recovery/`.

**Deleted app-local files:** `Sources/FlareApp/FlareAutosave.swift` and
`Sources/FlareApp/FlareRecovery.swift` (AK-10), with their macOS tests
`Tests/AppSnapshotTests/AutosaveTests.swift` and `AutosaveRecoveryTests.swift`
(the kernel's and AH-8's tests cover the rules now). AK-10 runs
`scripts/check-dup-logic --update-baseline` in the same PR, so
`Tests/canonical-baseline.txt` drops their lines. `-FlareRecoveryFile` and
`-PhotoRecoveryDir` are gone; `-LibraryCatalogDir` stays as a narrower
override the Library journeys use (one follow-up can move them to
`-SuiteSupportDir`).

**C4:** `suite-model/suite-store.json` names `appFolder` and the legacy move
(AK-2).

**Clean-room.** The rules come from Photo's, Flare's and Library's own tests.

Blueprint sections: suite.md 2.6 (the store); flare.md (recovery); photo.md
4.2 (recovery); library.md (the catalog file).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| AK-a | SuiteLocations gives each app its folder under the one support root and moves an old folder's files once without overwriting, and a ratchet fails any new Application Support path outside SuiteLocations. | AK-1, AK-2 | MJ-AK-root | autosave-history:AH-a (AK-2, merged) |
| AK-flare | Flare's window autosaves and offers recovery through `.autosaveRecovery` with Flare's hooks into `AfterGlow/Flare/Recovery/`, and an old `Recovery.flare` is offered once. | AK-3, AK-4 | MJ-AK-flare, FJ-AK | AK-a; autosave-history:AH-z (AK-4) |
| AK-library | Library's catalog lives at `AfterGlow/Library/catalog.json`, `-SuiteSupportDir` reaches it, and a catalog at the old place moves there once and never over a newer one. | AK-5, AK-6 | MJ-AK-library, LJ-AK | AK-a; library spine (AK-6, cross-line hand-off) |
| AK-photo | Photo's recovery copies live in `AfterGlow/Photo/Recovery/`, `-SuiteSupportDir` replaces `-PhotoRecoveryDir`, and copies at the old place are offered once. | AK-7, AK-8 | MJ-AK-photo, PJ-AK | AK-a; photo/history-panel PH-z (AK-8, cross-line hand-off) |
| AK-z | Four editors killed mid-edit under one `-SuiteSupportDir` each offer their own edit back, Flare's copy is deleted with the baseline shrunk, the ratchet runs with no baseline, and the feature is built. | AK-9, AK-10, AK-11 | SJ-AK, FJ-AK, PJ-AK | AK-flare, AK-library, AK-photo; autosave-history:AH-z (AK-10, also `canonical-baseline.txt`); cross-line DA-z and HA-z before AK-9's journey turns on |

There is no new screen (`"ui_slice": "none"`). AK-flare, AK-library,
AK-photo and AK-z edit `Sources/*App/` or `UITests/`, so they are `"ui": true`
and take the feel gate; their budget rows are the windows' existing ones.

**Shared-file chain (checker rule, not code):** `Tests/canonical-baseline.txt`
is owned by one delete task per burn-down packet: autosave-history AH-a, then
AK-10, then shared-codecs SC-z, adopt-kernel-unsaved-prompt UP-z,
adopt-kernel-eyedropper-photo EP-z and suite-imaging IM-photo's IM-8d. Only those single
tasks wait on each other.

## Journey steps

1. `MJ-AK-root` (AK-1, Linux): `SuiteLocationsAppFolderTests` and
   `SupportFolderRatchetTests` in `SuiteModelTests`.
2. `MJ-AK-flare` (AK-3): `FlareRecoveryKernelTests` (Linux): an edit, a
   schedule ticket, a write under `<support>/Flare/Recovery/`, a launch that
   restores the same document.
3. `FJ-AK` (`FlareRecoveryJourneys.testSaveFailureAndRecovery`, existing,
   moved to `-SuiteSupportDir` by AK-10): New Layer, quit without saving,
   relaunch: Restore brings the layer back.
4. `MJ-AK-library` and `LJ-AK` (AK-5): `LibraryCatalogLocationTests`
   (Linux); the existing Library journeys stay green on `-LibraryCatalogDir`.
5. `MJ-AK-photo` (AK-7): `PhotoRecoveryRootTests` (Linux). `PJ-AK`
   (`PhotoRecoveryJourneyTests.testRestoreAfterCrash`, existing, on
   `-SuiteSupportDir` after AK-8).
6. `SJ-AK` (AK-9, `SuiteRecoveryJourneyTests.testFourEditorsRecoverFromOneRoot`):
   one temp `-SuiteSupportDir`; Photo, Flare, Design and Halo each make one
   edit and are killed; each relaunches and offers its own edit, Restore
   brings it back; the folder holds `Photo/`, `Flare/`, `Design/` and `Halo/`
   and nothing at its top level.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X44 | adds, closes with `suiteui/adopt-kernel-autosave` | J | `SuiteRecoveryJourneyTests.testFourEditorsRecoverFromOneRoot` (AK-9) | one temp support folder, a new document per app |

Trap: one app's launch deletes another app's recovery copy (a shared
`Recovery/` folder read with the wrong extension), or an app ignores
`-SuiteSupportDir` and writes to the real Application Support. Assertion:
after all four relaunch, each offers exactly its own document's name, the
other three apps' files are still on disk, and nothing was written outside
the temp folder (the journey lists the real `AfterGlow` folder's modification
time before and after). It runs as a journey because the outcome is the
relaunch offer a person sees; RJ-X24 (kill -9, S12) stays autosave-history's.

## Screens and states

None new. Flare's recovery offer becomes autosave-history's
`suiteui-recovery-alert` (already snapshotted by AH-z); the Mac finisher
checks Flare's `flare-recovery-*` shot against it.

## Contract slice

```swift
// Sources/SuiteModel/Store/SuiteLocations.swift (AK-1 stub, AK-2 body). Linux-safe, pure strings.
extension SuiteLocations {
    /// `<supportFolder>/<app>`: one folder per app under the suite root ("Photo", "Flare", "Library", ...).
    public static func appFolder(_ app: String, arguments: [String], home: String) -> String
    /// Where an earlier build kept this app's files: `<home>/Library/Application Support/<legacy>`.
    public static func legacyFolder(_ legacy: String, home: String) -> String
}
// Sources/SuiteModel/Store/LegacySupport.swift (AK-1 stub, AK-2 body). Linux-safe.
public enum LegacySupport {
    public enum Step: Hashable, Sendable { case move(from: String, to: String), keepBoth(old: String), nothing }
    /// What to do with one old file: move it when the new place is empty; when both exist, keep both and touch
    /// neither (the newer place wins, the old file is left for the person); nothing when there is no old file.
    public static func plan(old: String, new: String, exists: (String) -> Bool) -> Step
}
// Sources/FlareModel/FlareRecovery+Kernel.swift (AK-3 stub, AK-4 body). Linux-safe.
extension FlareWorkspace {
    public var recoveryWindow: String { get }                       // the window's id
    public func recoveryEncoder() -> (@Sendable () throws -> Data)? // nil when clean
    public mutating func restoreRecovery(_ data: Data) throws
    public static let recoveryExtension = "flare"
}
// Sources/LibraryModel/LibrarySupport+Suite.swift (AK-5 stub, AK-6 body). Linux-safe.
public enum LibrarySupport {
    /// `-LibraryCatalogDir` when given, else `appFolder("Library")`.
    public static func catalogFolder(arguments: [String], home: String) -> String
    public static let legacyCatalog = "Library/catalog.json"
}
```

`SupportFolderRatchetTests` (AK-1): every `.swift` under `Sources/` but
`Sources/SuiteModel/Store/SuiteLocations.swift` that names
`applicationSupportDirectory` must be listed in `Tests/support-dir-baseline.txt`;
a listed file with no hit is fine (the slices shrink it without editing the
list), and AK-11 deletes the list so any hit fails.

## Pseudocode

- **appFolder.** `supportFolder(arguments:home:)` + "/" + app. App names are
  the suite's ids, so no escaping.
- **Legacy move (data-loss guard).** At launch, before the first read: for
  each old file `LegacySupport.plan`; `.move` uses `FileManager.moveItem`
  (same volume, atomic); `.keepBoth` logs once and leaves both. It never
  deletes. A moved recovery pair is then offered like any other; Library's
  catalog loads from the new place.
- **Flare.** `.autosaveRecovery(hooks, folder:, delay: 30, edits:)` with
  `hooks.encoder = model.recoveryEncoder`, `restore = model.restoreRecovery`,
  `isDirty = model.isDirty`, and the folder
  `RecoveryFolder(store: FileStore(folder: appFolder("Flare")), ext: "flare")`;
  `nil` folder with `-ApplePersistenceIgnoreState` (journeys), as the
  modifier documents. The old `Recovery.flare` is moved to
  `Flare/Recovery/<window>.flare` with a JSON beside it so `leftBehind`
  offers it.
- **Photo.** `LiveRecovery`'s `FileStore` folder becomes `appFolder("Photo")`;
  the old `Photo/Recovery/*.ora` files move with the same rule.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| AK-1 | – | **Tests first.** `SupportFolderRatchetTests` live with today's three hits in `Tests/support-dir-baseline.txt`; `SuiteLocationsAppFolderTests` written, disabled (`waits on AK-2`); `appFolder`, `legacyFolder` and `LegacySupport.plan` as stubs | `Sources/SuiteModel/Store/SuiteLocations.swift`, `Sources/SuiteModel/Store/LegacySupport.swift`, `Tests/SuiteModelTests/SuiteLocationsAppFolderTests.swift`, `Tests/SuiteModelTests/SupportFolderRatchetTests.swift`, `Tests/support-dir-baseline.txt` | – | ~200, 5 |
| AK-2 | – | `appFolder`, `legacyFolder` and `LegacySupport.plan` bodies; turns on `SuiteLocationsAppFolderTests`; the C4 part | `Sources/SuiteModel/Store/SuiteLocations.swift`, `Sources/SuiteModel/Store/LegacySupport.swift`, `Tests/SuiteModelTests/SuiteLocationsAppFolderTests.swift`, `Tests/mutations/SuiteModel.SuiteLocations.json`, `docs/c4/parts/creative-apps/suite-model/suite-store.json` | AK-1 | ~180, 5 |
| AK-3 | – | **Flare, test first.** `FlareRecoveryKernelTests`, disabled (`waits on AK-4`); `FlareRecovery+Kernel.swift` as stubs | `Sources/FlareModel/FlareRecovery+Kernel.swift`, `Tests/FlareModelTests/FlareRecoveryKernelTests.swift` | AK-2 | ~180, 2 |
| AK-4 | – | **Flare on the shared path.** The adapter's bodies; `FlareWindow` puts `.autosaveRecovery` on the document with Flare's hooks and folder, and moves an old `Recovery.flare` once; `FlareAutosave`'s tick is no longer called; turns on `FlareRecoveryKernelTests` | `Sources/FlareModel/FlareRecovery+Kernel.swift`, `Sources/FlareApp/FlareWindow.swift`, `Tests/FlareModelTests/FlareRecoveryKernelTests.swift`, `Tests/mutations/FlareModel.FlareRecovery+Kernel.json` | AK-3, autosave-history AH-8 | ~300, 4 |
| AK-5 | – | **Library, test first.** `LibraryCatalogLocationTests`, disabled (`waits on AK-6`); `LibrarySupport+Suite.swift` as stubs | `Sources/LibraryModel/LibrarySupport+Suite.swift`, `Tests/LibraryModelTests/LibraryCatalogLocationTests.swift` | AK-2 | ~160, 2 |
| AK-6 | – | **Library's catalog under the root.** `catalogFolder` body; `CatalogStore` takes its folder from it (no `.applicationSupportDirectory`) and moves an old catalog once before the first load; turns on the tests | `Sources/LibraryModel/LibrarySupport+Suite.swift`, `Sources/LibraryApp/Platform/CatalogStore.swift`, `Tests/LibraryModelTests/LibraryCatalogLocationTests.swift`, `Tests/mutations/LibraryModel.LibrarySupport+Suite.json` | AK-5 | ~220, 4 |
| AK-7 | – | **Photo, test first.** `PhotoRecoveryRootTests`, disabled (`waits on AK-8`): the folder is `<support>/Photo/Recovery`, `-SuiteSupportDir` reaches it, old `.ora` copies are offered once | `Tests/PhotoModelTests/PhotoRecoveryRootTests.swift` | AK-2 | ~160, 1 |
| AK-8 | – | **Photo under the root.** `LiveRecovery`'s store on `appFolder("Photo")` (no `.applicationSupportDirectory`), the old folder moved once; `-PhotoRecoveryDir` removed from `PhotoWindow+File`; the journey fixtures pass `-SuiteSupportDir`; turns on `PhotoRecoveryRootTests` | `Sources/PhotoModel/Live/LiveRecovery.swift`, `Sources/PhotoApp/PhotoWindow+File.swift`, `UITests/PhotoJourneyTests+Fixtures.swift`, `UITests/PhotoJourneyTests+Recovery.swift`, `Tests/PhotoModelTests/PhotoRecoveryRootTests.swift`, `Tests/mutations/PhotoModel.LiveRecovery.json` | AK-7 | ~260, 6 |
| AK-9 | – | **The four-editor journey (RJ-X44's check).** `SuiteRecoveryJourneyTests.testFourEditorsRecoverFromOneRoot`; skipped per app (`XCTSkip("waits on DA-z")`, `"waits on HA-z"`) until Design's and Halo's adopts land | `UITests/SuiteJourneyTests+Recovery.swift` | AK-4, AK-6, AK-8, design DA-z, halo HA-z | ~220, 1 |
| AK-10 | – | **Flare delete.** Removes `FlareAutosave.swift`, `FlareRecovery.swift` and their tests `AutosaveTests.swift`, `AutosaveRecoveryTests.swift`; `-FlareRecoveryFile` and `TestDefaults`' recovery default go; Flare's journey moves to `-SuiteSupportDir`; the command-path baseline drops the two old buttons; `scripts/check-dup-logic --update-baseline` drops the deleted files' lines | `Sources/FlareApp/FlareAutosave.swift`, `Sources/FlareApp/FlareRecovery.swift`, `Tests/AppSnapshotTests/AutosaveTests.swift`, `Tests/AppSnapshotTests/AutosaveRecoveryTests.swift`, `Tests/AppSnapshotTests/TestDefaults.swift`, `UITests/FlareJourneyTests+Recovery.swift`, `Tests/command-path-baseline/flare.txt`, `Tests/canonical-baseline.txt` | AK-4, autosave-history AH-10 | ~250, 8 |
| AK-11 | – | The ratchet runs with no baseline (`Tests/support-dir-baseline.txt` deleted, every hit outside `SuiteLocations.swift` fails); the C4 part names the four adopters; `status: built`; `feature-done` | `Tests/support-dir-baseline.txt`, `Tests/SuiteModelTests/SupportFolderRatchetTests.swift`, `docs/c4/parts/creative-apps/suite-model/suite-store.json`, `docs/blueprints/suiteui/features/adopt-kernel-autosave.wave.json` | AK-6, AK-8, AK-9 | ~60, 4 |

AK-10 waits on AK-4 only for code (Flare's window must stop calling the old
writer first); its slice's wait on AH-z orders it on the baseline chain.

## Build waves

- Wave 1: AK-1. Independent in this wave: AK-1 alone.
- Wave 2: AK-2. Independent in this wave: AK-2 alone.
- Wave 3: AK-3, AK-5, AK-7. Independent in this wave: all.
- Wave 4: AK-4, AK-6, AK-8. Independent in this wave: all.
- Wave 5: AK-9, AK-10. Independent in this wave: both.
- Wave 6: AK-11. Independent in this wave: AK-11 alone.

Longest chain: AK-1 → AK-2 → AK-3 → AK-4 → AK-9 → AK-11 (6). Chain of 6: the stubs before the folder rule, the folder rule before Flare's stubs and body, every app on the root before the four-editor journey, and the strict ratchet after it.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| AK-1 | `SupportFolderRatchetTests`: a fixture file naming `.applicationSupportDirectory` in `Sources/HaloModel/` fails; the real tree passes with the baseline; `SuiteLocationsAppFolderTests` disabled by name | a fourth Application Support path passes | – (stubs; the ratchet is a test) |
| AK-2 | `SuiteLocationsAppFolderTests`: `-SuiteSupportDir /t` gives `/t/Photo`; no flag gives `<home>/Library/Application Support/AfterGlow/Photo`; old only → `.move`; both → `.keepBoth`; neither → `.nothing` | two apps share a folder, the flag is ignored, or a move would overwrite | `SuiteModel.SuiteLocations`: `appFolder` returns the root with no app segment → `.appFolderHasAppSegment`; `plan` moves when both exist → `.neverOverwrites`; flag ignored → `.flagReachesApp` |
| AK-3 | compiles, disabled by name | – | – (stubs) |
| AK-4 | `FlareRecoveryKernelTests`: encode then restore gives the same document; a clean workspace has no encoder; an old `Recovery.flare` is offered once; Flare's existing Model tests unchanged | a recovered document differs, a clean one writes, or an old copy is lost | `FlareModel.FlareRecovery+Kernel`: encoder returned while clean → `.cleanWritesNothing`; restore not recording history → `.restoreIsOneStep` |
| AK-5 | compiles, disabled by name | – | – (stubs) |
| AK-6 | `LibraryCatalogLocationTests`: `-SuiteSupportDir /t` gives `/t/Library`; `-LibraryCatalogDir /c` wins; an old catalog moves once; an old and a new catalog are both kept; the Library journeys unchanged | a catalog is overwritten, lost, or read from two places | `LibraryModel.LibrarySupport+Suite`: the override ignored → `.catalogDirWins`; root used without the app segment → `.libraryFolder` |
| AK-7 | compiles, disabled by name | – | – (test only) |
| AK-8 | `PhotoRecoveryRootTests`; `PJ-AK` on `-SuiteSupportDir`; Photo's existing recovery tests unchanged | Photo writes outside the root, or an old copy is lost | `PhotoModel.LiveRecovery`: legacy copies skipped → `.oldCopiesOffered`; store built on the root, not the app folder → `.photoFolder` |
| AK-9 | `SJ-AK` on the scoped run: each editor offers only its own edit; every app's files survive; nothing written outside the temp folder | an app's copy is deleted by another app, or an app ignores the flag | – (UI) |
| AK-10 | `FJ-AK`; Flare's Model tests; `scripts/check-dup-logic` (baseline shrank); `scripts/mutate --validate` | a deleted symbol is referenced, or a baseline line names a gone file | – (deletion) |
| AK-11 | `SupportFolderRatchetTests` strict; `scripts/waves render --dry-run` | any Application Support path outside SuiteLocations, or status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| no data loss | an old file is moved, never overwritten or deleted; a shared root never deletes another app's copy | `SuiteLocationsAppFolderTests.neverOverwrites`, `SJ-AK` |
| autosave off the main actor | encode and write in a detached task (AH-8's rule, unchanged for Flare) | `AutosaveDriverTests.encodesOffMain` (autosave-history) |
| render: Flare edit while autosave ticks | ≤ 3 window bodies per 120-sample drag (Flare's existing budget, unchanged) | `RenderBudgetFlareStageTests` (existing) |
| one root | no `.applicationSupportDirectory` outside `SuiteLocations.swift` | `SupportFolderRatchetTests` (strict after AK-11) |
| one launch flag | `-SuiteSupportDir` reaches every editor's recovery and Library's catalog | `SJ-AK`, `LibraryCatalogLocationTests` |

## Done check

Per slice (rules 6, 15, 17, 21): AK-a green on the Linux job with `Mutate:`
clean; AK-flare, AK-library and AK-photo with their Model walks green,
the apps' journeys green on the scoped run and the feel gate's `Mac-Finish:`
line; AK-z with RJ-X44's journey green for all four editors (Design and Halo
once DA-z and HA-z land) and the strict ratchet. Then `Belt-Contact-Sheet:`
with the recovery offer in each app.
