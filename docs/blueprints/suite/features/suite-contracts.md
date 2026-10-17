# Feature packet: suite-contracts

**Feature:** the suite's shared values, the 18 contracts, a fake for each,
the store, the services and the live slots. After it, every later suite
feature (and each app's adoption task) builds against real types in
`SuiteModel`, the store reads and writes revisioned JSON safely from two
processes, and every process can assemble `SuiteServices.live`, with the
recents slot already live.
**Line:** `line:suite` · **Wave:** 1 (`waves.md`) · **Lead branch:** `lead/suite-contracts`
**Blueprint:** `docs/blueprints/suite.md` sections 2.3 (SuiteModel,
shell-live), 2.6 (the store), 5 (all of it; the Swift is in
`docs/blueprints/suite/contracts/`), 7.1 model budgets, 7.4 QB-SV8, 8.2 (F2).

**Covers:** #820, #821, #822, #823, #824, #825, #826,
#827, #828, #829, #830, #831, #832, #833, #834.
Each closes through its task PR.

**Depends on:** the targets feature (`targets.md`; BU-1a creates the
`SuiteModel` target and `SuiteIdentity.swift`). No creative-core issue: the
suite never imports an engine (D5).

**Where it starts from.** `docs/blueprints/suite/contracts/` compiles on
Linux with `check.sh` ("contracts: PASS"). This feature moves that Swift into
`Sources/SuiteModel/` one type family per file and one protocol and one fake
per file, applies the corrections below, and moves `main.swift`'s checks
into Swift Testing suites next to the code they check. The blueprint's SC-1
(Values, 654 lines), SC-2 (18 files), SC-3 (Fakes, 531 lines) and SC-5 (15
files plus a test) were each over the 400-line or 15-file cap (review), so
they are split here into 15 tasks.

## Corrections to the blueprint's contracts (review of #792)

1. **File names never hold a file id.** `fileID` is `"path:/a/b/Logo.design"`
   and has slashes, so it can't name a file. SC-1a adds
   `SuiteDocumentRef.fileKey(_ fileID: String) -> String`: FNV-1a 64-bit over
   the UTF-8 bytes, 16 lowercase hex digits. Thumbnails are
   `thumbnails/<fileKey>.png` everywhere: `FakeThumbnails`, the live
   `ThumbnailWriter` (wave 3), `RecentItem.thumbnail`'s comment and the
   `weekOfWork` fixture (which used `thumbnails/<file name>.png`, a third
   rule).
2. **Hand-off ids are UUIDs.** `HandOff.newID() -> String` is
   `UUID().uuidString.lowercased()`; the file is `handoffs/<id>.aghandoff`.
   `HandOffCodec.decode` refuses an id with anything but `a-z`, `0-9` and
   `-` (`SuiteError.damaged("the message from another app")`), so a hand-off file can never
   name a nested path. Callers that built ids from a file id or a
   one-second clock (`"open-<fileID>"`, `"new-<preset>-<seconds>"`) take an
   injected `makeID: @Sendable () -> String = HandOff.newID` instead (home's
   `HomeModel`, HM-1b).
3. **`FakePasteboard`'s file-URL branch uses the one identity rule:**
   `fileID: SuiteDocumentRef.fileID(forPath: path)`, not `fileID: path`
   (left over from blueprint critic round 2 #10). clipboard-drag's CD-1
   promotes this fake to the live type, so a dropped file now dedupes
   against its recents entry. `FakesExchangeTests` checks it.
4. **The registry names what the plists export but no app opens as a
   document.** SC-1a adds `SuiteTypeRegistry.declaredOnly: [SuiteTypeID]` =
   `[.handOff, .assetEnvelope, .designLayers, .flareLayers]`. The rule for
   the registry-vs-plist test (recents-open-in RO-1, wave 3):
   `CFBundleDocumentTypes` equal `standard`, and the exported types that
   are not document types equal `declaredOnly`.
5. **Fixture seeding has an owner.** The blueprint has the launcher seed the
   store from `-SuiteFixture <name>` but no file for it. SC-4c adds
   `FixtureSeeder.seed(_ name:, into:, documentsFrom:, documentsTo:, now:)`
   in `Store/`: it writes `SuiteFixtures.store(...)` with `FileStore`, copies
   the fixture documents into `<support>/Documents` (skipping `Cards.design`
   for `missing`, and skipping any source not yet exported by its app line,
   which then shows as Missing), and copies `<documentsFrom>/thumbnails/<file name>.png` to
   `thumbnails/<fileKey>.png`. Journeys pass the folder with a new flag,
   `-SuiteFixtureDocuments <path to UITests/Fixtures/suite>` (the app can't
   know the repo path). The launcher's call site is home's
   `LauncherRouter+Services.swift` (HM-2a).
6. **Not-connected reasons come from one table, and the views can read
   them.** `SuiteServices.slotFeatures: [String: String]` (each of the 15
   members, `sending` and `receiving` included, to the feature that
   connects it) and `SuiteIdentity.notConnected(_:)` (BU-1a) make every
   reason "<What> isn't available yet.", where <What> is the feature's plain
   phrase from `SuiteIdentity.featurePhrases` (a slug never reaches the UI;
   an unknown feature reads "This isn't available yet."). Throwing members that are not
   live yet hold their fake with `unavailable:`, so they throw that
   sentence. Pure members (`creating`, `routing`, `pasteboard`, `linking`,
   `onboarding`, `home`) have no throwing call, so their slot returns the
   reference fake, and the services carry
   `pending: [String: String]` (member to its reason) for every member not
   live yet. A view disables a control whose member is pending and shows
   that reason. `.fake` has `pending` empty.
8. **One slot signature.** `SuiteServices.live(support:app:arguments:)`
   builds a `SlotContext(store: FileStore, support: String, app: SuiteApp,
   arguments: [String])` once, and every slot is
   `func <member>Slot(_ c: SlotContext) -> any <Contract>`. Wave-2 features
   swap a slot's body (the `AppLauncher` needs `arguments`, `StoreHandOffs`
   needs `app`) without touching `SuiteServices+Live.swift`.
9. **Hand-off files are raw.** `FileStore` also has `readData(_:)` and
   `writeData(_:_:)`, atomic and under the lock but with no revision
   envelope, so a `.aghandoff` file is exactly `HandOffCodec`'s bytes.
10. **`SettingsPane`, `AssetKind`, `AssetLink` and `LinkStatus` move to
   SC-1a** (`Values/SuiteApp.swift` and `Values/Links.swift`), because
   `HandOff` (SC-1b) holds a `SettingsPane?` and an `AssetLink?`.
7. **`StoreRecents` is a SuiteModel type,** not SuiteShell code, so the live
   recents logic is tested on Linux: a `FileStore`-backed `RecentWork` with an
   `onWrite` hook. SuiteShell's `RecentsSlot` builds it; switching's SW-3a
   attaches the distributed-notification watcher to that hook in wave 2.

## Journey steps

No UI. The Model journey, in `Tests/SuiteModelTests/SuiteContractsJourneyTests.swift`
(SC-4b), walks one person's day on `SuiteServices.fake` and then on a
temporary `FileStore`:

1. Seed `weekOfWork`: the recents list has 8 items newest first, each with
   `thumbnails/<fileKey>.png`.
2. Note `Logo.design` opened now: it moves to the top, still 8 items.
3. Send an `.open` hand-off for it: the fake switching reports Design
   running; the sent hand-off's id is a UUID and decodes back equal.
4. Remove `Cards.design`: 7 items; `changes()` yielded once per write.
5. Two `FileStore` writers race on `recents.json` (one stale): the second
   gets `staleRevision`, re-reads, merges, and both items are present.

## Screens and states

No screen. The states every later screen reads from here:

| State | Where it comes from |
|---|---|
| Empty | `RecentsList()`, `AssetIndex()`, `SuitePreferences()` defaults; `FakeHome`'s "No recent work yet. Start something new above, or open a file." |
| Error | `SuiteError.message`, the one sentence each failure shows (17 cases, blueprint 5.4, with `readFailed`); a failed hand-off encode is `.ioFailed("the message from another app")`; a slot not connected yet throws `.notAvailable("<What> isn't available yet.")` with <What> from `SuiteIdentity.featurePhrases` |
| Loading | none in the Model; the views show progress from probe marks (home, switching) |

## Contract slice

The whole of blueprint section 5, as moved. File by file:

```
Sources/SuiteModel/
  Values/SuiteIdentity.swift   prefix, launcherBundleID, featurePhrases, notConnected (BU-1a; SC-1a keeps it)
  Values/SuiteApp.swift        SuiteApp: displayName, bundleID, bundlePath, switchDigit; SettingsPane
  Values/SuiteTypes.swift      SuiteTypeID, SuiteDocumentType, SuiteTypeRegistry (+ declaredOnly)
  Values/SuiteDocumentRef.swift  fileID(forPath:), fileKey(_:)                     (correction 1)
  Values/SuiteError.swift      the 17 cases (readFailed included) and their messages
  Values/Recents.swift         RecentEvent, RecentItem
  Values/NewDocumentPreset.swift
  Values/Switching.swift       AppRunState, SwitchReason, SwitchReceipt
  Values/HandOff.swift         HandOffVerb, HandOffState, HandOff (+ newID)       (correction 2)
  Values/RoundTrip.swift       RoundTripSource, RoundTripState, RoundTripSession
  Values/SuiteColor.swift      SuiteColorSpace, SuiteColorValue
  Values/Assets.swift          SuiteAsset, AssetDraft, AssetIndex
  Values/Links.swift           AssetKind, AssetLink, LinkStatus                  (SC-1a)
  Values/Clip.swift            TypedData, AssetEnvelope, SuiteClipItem
  Values/Preferences.swift     LengthUnit, SuitePreferences
  Values/Onboarding.swift      OnboardingFocus, OnboardingPage
  Values/Update.swift          SuiteVersion, UpdateOffer
  Values/AnimationSummary.swift
  Values/HomeValues.swift      NewTile, RecentCard, HomeState
  Recents/RecentsList.swift    (recents-open-in owns from wave 3)
  Recents/StoreRecents.swift   live RecentWork over FileStore                   (correction 7)
  HandOff/HandOffCodec.swift   (switching owns from wave 2)
  Home/HomeLayout.swift        (home owns from wave 2)
  Update/UpdateFeed.swift      (updater owns from wave 4)
  Contracts/<Protocol>.swift   ×18
  Fakes/ChangeFeed.swift, Fakes/Fake<Name>.swift ×17, Fakes/SuiteFixtures.swift
  Store/SuiteLocations.swift, Store/FileStore.swift, Store/FixtureSeeder.swift (correction 5)
  SuiteServices.swift          SuiteServices, .fake, with(animations:updates:), slotFeatures, pending
Sources/SuiteShell/
  SuiteServices+Live.swift     SlotContext; extension SuiteServices { public static func live(support:app:arguments:) -> SuiteServices }
  Live/<Member>Slot.swift ×14  one per member, `sending` and `receiving` sharing HandOffSlot: the live type, or the fake
```

New or changed signatures (everything else exactly as in the contracts folder):

```swift
extension SuiteDocumentRef { public static func fileKey(_ fileID: String) -> String }      // 16 hex, FNV-1a 64
extension SuiteTypeRegistry { public static let declaredOnly: [SuiteTypeID] }
extension HandOff { public static func newID() -> String }                                // lowercased UUID
public struct FileStore: Sendable {                                                         // SC-4a
    public init(folder: String)
    public func read<T: Codable & Sendable>(_ name: String, as: T.Type) throws(SuiteError) -> (value: T?, revision: Int)
    public func write<T: Codable & Sendable>(_ name: String, _ value: T, expecting revision: Int) throws(SuiteError) -> Int
    public func update<T: Codable & Sendable>(_ name: String, empty: T, merge: (T) -> T) throws(SuiteError) -> (value: T, revision: Int)
    public func readData(_ name: String) throws(SuiteError) -> Data?                       // raw, no envelope (hand-offs)
    public func writeData(_ name: String, _ data: Data) throws(SuiteError)                 // atomic, under the lock
}                                                   // update = lock, read, merge, write revision + 1, unlock
public enum SuiteLocations {                                                               // SC-4a
    public static func supportFolder(arguments: [String], home: String) -> String         // -SuiteSupportDir wins
}
public actor StoreRecents: RecentWork {                                                    // SC-5a
    public init(store: FileStore, onWrite: @escaping @Sendable (String) -> Void = { _ in })
    public func externalChange() async                                                       // the watcher calls it; re-reads, yields
}
extension SuiteServices {                                                                  // SC-4b
    public static let slotFeatures: [String: String]       // 15 members -> feature
    public var pending: [String: String]                   // member -> "<What> isn't available yet." (featurePhrases); empty for .fake
}
public struct SlotContext: Sendable { store: FileStore, support: String, app: SuiteApp, arguments: [String] }  // SC-5b, SuiteShell
public enum FixtureSeeder { public static func seed(_ name: String, into store: FileStore,
                            documentsFrom: String, documentsTo: String, now: Date) throws(SuiteError) }  // SC-4c
```

## Pseudocode

```
fileKey(id):  h = 0xcbf29ce484222325; for b in id.utf8 { h ^= b; h &*= 0x100000001b3 }; return hex16(h)

FileStore.update(name, empty, merge):                         # SC-4a, blueprint 2.6
  fd = open(folder/name.lock, O_CREAT); flock(fd, LOCK_EX); defer { flock(fd, LOCK_UN); close(fd) }
  (old, rev) = read(name)                                      # {"revision": n, "value": ...}; missing file: (nil, 0)
  new = merge(old ?? empty)
  write tmp file; rename over name (atomic)                    # revision rev + 1
  return (new, rev + 1)
FileStore.write(name, value, expecting r):  under the lock; if current revision != r throw .staleRevision
  (Glibc on Linux, Darwin on macOS: `#if canImport(Glibc)`; nothing else platform-specific)

StoreRecents.note(ref, event, date, thumbnail):               # SC-5a
  (list, rev) = store.update("recents.json", empty: RecentsList()) { var l = $0; keep thumbnail; l.note(item); l.revision += 1; return l }
  feed.send(rev); onWrite("recents.json")

FixtureSeeder.seed(name, store, from, to, now):               # SC-4c
  s = SuiteFixtures.store(name, documents: to, now: now) ?? throw .notAvailable("No fixture named <name>.")
  store.write recents.json, assets/index.json, preferences.json
  for (file, app, type) in weekOfWorkFiles where name in [weekOfWork, missing, roundTrip]:
    if name == missing and file == "Cards.design": skip
    if from/file is absent: skip it (the card shows Missing until its app line exports it)
    copy from/file -> to/file ; copy from/thumbnails/file.png -> thumbnails/<fileKey(fileID(to/file))>.png if present

SuiteServices+Live.live(support, app, arguments):             # SC-5b, SC-5c
  c = SlotContext(store: FileStore(folder: support), support, app, arguments)
  s = SuiteServices(switching: switchingSlot(c), recents: recentsSlot(c), ..., isPreview: false)
  s.pending = slotFeatures minus the members whose slot is live, each mapped to notConnected(feature)
  throwing member slot, not live: Fake<Name>(unavailable: notConnected(slotFeatures["<member>"]))
  pure member slot, not live: the reference fake (FakeRouting(), FakeHome(), ...)
  recentsSlot: StoreRecents(store: c.store)                    # live from SC-5b
  live-ness is one line per slot file: `let isLive = false`; `live(...)` builds `pending` from those flags
```

## Tasks

Every task is one PR to `dev`: at most 400 changed lines and 15 files, label
`fast-lane`, body lines `Belt-Lead:`, `Feature: suite-contracts`,
`Fast-Check: pass`, `Head:`. SC-5c carries `feature-done`.

| id | issue | what | owned files (under `Sources/SuiteModel/` unless a path says otherwise) | depends on |
|---|---|---|---|---|
| SC-1a | #820 | Identity, types, document refs (`fileKey`), errors; `declaredOnly` | `Values/SuiteIdentity.swift`, `Values/SuiteApp.swift` (with `SettingsPane`), `Values/SuiteTypes.swift`, `Values/SuiteDocumentRef.swift`, `Values/SuiteError.swift`, `Values/Links.swift` (`AssetKind`, `AssetLink`, `LinkStatus`), `Tests/SuiteModelTests/ValuesIdentityTests.swift` | BU-1a #810 |
| SC-1b | #821 | Recents values and `RecentsList`; presets; switching values; `HandOff` (`newID`) and `HandOffCodec` (id check) | `Values/Recents.swift`, `Values/NewDocumentPreset.swift`, `Values/Switching.swift`, `Values/HandOff.swift`, `Recents/RecentsList.swift`, `HandOff/HandOffCodec.swift`, `Tests/SuiteModelTests/ValuesRecentsTests.swift`, `Tests/SuiteModelTests/ValuesHandOffTests.swift` | SC-1a |
| SC-1c | #822 | Round-trip, colour, asset and clipboard values | `Values/RoundTrip.swift`, `Values/SuiteColor.swift`, `Values/Assets.swift`, `Values/Clip.swift`, `Tests/SuiteModelTests/ValuesExchangeTests.swift` | SC-1a |
| SC-1d | #823 | Preferences, onboarding, version and offer, `UpdateFeed`, `AnimationSummary`, home values and `HomeLayout` | `Values/Preferences.swift`, `Values/Onboarding.swift`, `Values/Update.swift`, `Values/AnimationSummary.swift`, `Values/HomeValues.swift`, `Update/UpdateFeed.swift`, `Home/HomeLayout.swift`, `Tests/SuiteModelTests/ValuesSettingsTests.swift`, `Tests/SuiteModelTests/ValuesHomeLayoutTests.swift` | SC-1b |
| SC-2a | #824 | The nine tier-1 contracts | `Contracts/AppSwitching.swift`, `RecentWork.swift`, `DocumentCreating.swift`, `DocumentRouting.swift`, `HandOffSending.swift`, `HandOffReceiving.swift`, `ThumbnailPublishing.swift`, `HomeBuilding.swift`, `SuiteDocumentHost.swift`, `Tests/SuiteModelTests/ContractShapeTests.swift` | SC-1b, SC-1d |
| SC-2b | #825 | The other nine contracts | `Contracts/RoundTripEditing.swift`, `PasteboardCoding.swift`, `AssetLibrary.swift`, `AssetLinking.swift`, `AnimationSourceReading.swift`, `PreferencesStoring.swift`, `SettingsRouting.swift`, `OnboardingFlowing.swift`, `UpdateChecking.swift`, `Tests/SuiteModelTests/ContractShapeMoreTests.swift` | SC-1c, SC-1d |
| SC-3a | #826 | `ChangeFeed` and the tier-1 fakes (thumbnails by `fileKey`) | `Fakes/ChangeFeed.swift`, `FakeSwitching.swift`, `FakeRecents.swift`, `FakeCreating.swift`, `FakeRouting.swift`, `FakeHandOffs.swift`, `FakeThumbnails.swift`, `FakeHome.swift`, `FakeDocumentHost.swift`, `Tests/SuiteModelTests/FakesTier1Tests.swift` | SC-2a |
| SC-3b | #827 | Round-trip, pasteboard (file-URL fix), asset and link fakes | `Fakes/FakeRoundTrips.swift`, `FakePasteboard.swift`, `FakeAssets.swift`, `FakeLinking.swift`, `Tests/SuiteModelTests/FakesExchangeTests.swift` | SC-2b, SC-3a |
| SC-3c | #828 | Animation, preferences, settings route, onboarding and update fakes; `SuiteFixtures` (all seven fixtures, thumbnails by `fileKey`) | `Fakes/FakeAnimationSource.swift`, `FakePreferences.swift`, `FakeSettingsRoute.swift`, `FakeOnboarding.swift`, `FakeUpdates.swift`, `SuiteFixtures.swift`, `Tests/SuiteModelTests/FakesSettingsTests.swift`, `Tests/SuiteModelTests/SuiteFixturesTests.swift` | SC-2b, SC-3a |
| SC-4a | #829 | `SuiteLocations` and `FileStore` (revision, atomic replace, lock file, merge; raw `readData`/`writeData`) | `Store/SuiteLocations.swift`, `Store/FileStore.swift`, `Tests/SuiteModelTests/StoreTests.swift` | SC-1a |
| SC-4b | #830 | `SuiteServices` (`.fake`, `with`, `isPreview`, `slotFeatures`, `pending`); the timing helper; QB-SM6 across two processes; QB-SV8; the Model journey | `SuiteServices.swift`, `Tests/SuiteModelTests/SuiteServicesTests.swift`, `Tests/SuiteModelTests/Budget.swift`, `Tests/SuiteModelTests/Budget+Store.swift`, `Tests/SuiteModelTests/StoreRoundTripTests.swift`, `Tests/SuiteModelTests/SuiteContractsJourneyTests.swift` | SC-3b, SC-3c, SC-4a |
| SC-4c | #831 | `FixtureSeeder` (store files, documents, thumbnails by `fileKey`, `missing`) | `Store/FixtureSeeder.swift`, `Tests/SuiteModelTests/FixtureSeederTests.swift` | SC-3c, SC-4a |
| SC-5a | #832 | `StoreRecents`, the live `RecentWork` | `Recents/StoreRecents.swift`, `Tests/SuiteModelTests/StoreRecentsTests.swift` | SC-2a, SC-3a (`ChangeFeed`), SC-4a |
| SC-5b | #833 | `SlotContext`, `SuiteServices.live(support:app:arguments:)` with `pending`, and the first seven slots (switching, recents (live), creating, routing, hand-off, thumbnails, home); the other seven members inline fakes for now | `Sources/SuiteShell/SuiteServices+Live.swift`, `Sources/SuiteShell/Live/SwitchingSlot.swift`, `RecentsSlot.swift`, `CreatingSlot.swift`, `RoutingSlot.swift`, `HandOffSlot.swift`, `ThumbnailsSlot.swift`, `HomeSlot.swift`, `Tests/AppSnapshotTests/SuiteLiveServicesTests.swift` | SC-4b, SC-5a |
| SC-5c | #834 | The other seven slots (round trips, pasteboard, assets, linking, preferences, settings, onboarding); `animations` and `updates` stay with `with(animations:updates:)` | `Sources/SuiteShell/SuiteServices+Live.swift`, `Sources/SuiteShell/Live/RoundTripSlot.swift`, `PasteboardSlot.swift`, `AssetsSlot.swift`, `LinkingSlot.swift`, `PreferencesSlot.swift`, `SettingsSlot.swift`, `OnboardingSlot.swift`, `Tests/AppSnapshotTests/SuiteLiveServicesTests.swift` | SC-5b |

Chains (same file, in order): `SuiteServices+Live.swift` and
`SuiteLiveServicesTests.swift` SC-5b → SC-5c. Everything else is disjoint.
Sizes, each under 400 lines: SC-1a ~330, SC-1b ~320, SC-1c ~260, SC-1d ~330,
SC-2a ~220 (10 files), SC-2b ~200 (10), SC-3a ~330 (10), SC-3b ~330, SC-3c
~330, SC-4a ~300, SC-4b ~380, SC-4c ~200, SC-5a ~220, SC-5b ~250 (9), SC-5c
~180 (9). Which tasks build side by side is in Build waves below.

**Ownership after this feature.** `Recents/` goes to recents-open-in
(wave 3), `HandOff/` to switching (wave 2), `Home/` to home (wave 2),
`Update/` to updater (wave 4). Slot files go to their features
(`HomeSlot`, `CreatingSlot`: home; `SwitchingSlot`, `HandOffSlot`,
`RecentsSlot` until wave 3: switching; the rest in their waves).
`SuiteServices+Live.swift` has no owner after SC-5c: features swap only
their own slot file. `Values/`, `Contracts/`, `Fakes/` and `Store/` have no
owner in wave 2; a later feature that needs a change there names it in its
packet.

## Build waves

No task edits a shared doc (`docs/c4/model.json`, `docs/design.md`, a
blueprint or a `waves.md`): every file is in `Sources/SuiteModel/`,
`Sources/SuiteShell/` or a test target, and each target's folder is already
its C4 component. So no docs task is added; SC-5c stays the final task.

- Wave 1: SC-1a. Independent in this wave: SC-1a alone.
- Wave 2: SC-1b, SC-1c, SC-4a. Independent in this wave: all three.
- Wave 3: SC-1d. Independent in this wave: SC-1d alone.
- Wave 4: SC-2a, SC-2b. Independent in this wave: both.
- Wave 5: SC-3a. Independent in this wave: SC-3a alone.
- Wave 6: SC-3b, SC-3c, SC-5a. Independent in this wave: all three.
- Wave 7: SC-4b, SC-4c. Independent in this wave: both.
- Wave 8: SC-5b. Independent in this wave: SC-5b alone.
- Wave 9: SC-5c (final, `feature-done`). Independent in this wave: SC-5c alone.

Longest chain: SC-1a → SC-1b → SC-1d → SC-2a → SC-3a → SC-3b → SC-4b → SC-5b → SC-5c (9).
Chain of 9: each link is a type the next task uses. SC-1b's `RecentItem`
and `HandOff` hold SC-1a's `SuiteDocumentRef`, `SettingsPane` and
`AssetLink`; SC-1d's `HomeValues.swift` holds SC-1b's `RecentItem` and
`NewDocumentPreset`; SC-2a's `HomeBuilding` returns SC-1d's `HomeState`;
SC-3a's fakes conform to SC-2a's contracts; SC-3b's `FakeAssets` streams
through SC-3a's `ChangeFeed`; SC-4b's `SuiteServices.fake` builds SC-3b's
fakes; SC-5b's `live` reads SC-4b's `slotFeatures` and `pending`; SC-5c's
slots take SC-5b's `SlotContext` and edit its `SuiteServices+Live.swift`.

## Acceptance test per task

| id | test | fails when |
|---|---|---|
| SC-1a | `ValuesIdentityTests`: bundle ids and `bundlePath` per app (`Contents/Helpers/Flare.app` and so on, written out in the test; recents-open-in RO-1 later checks them against bundle's `BundleLayout`); `defaultApp` for each registry type; `fileID(forPath: "/a/./b/../Logo.design")` == `"path:/a/Logo.design"`; `fileKey` is 16 hex digits, stable for a pinned input (`fileKey("path:/a/Logo.design")` equals the value written in the test), and differs for 200 distinct ids generated in the test (`path:/tmp/Doc <i>.flare`); `declaredOnly` has the four ids and none is in `standard`; every `SuiteError.message` equals blueprint 5.4's sentence | a sentence, an id, the identity rule or the key drifts, or two ids collide |
| SC-1b | `ValuesRecentsTests` (main.swift's recents checks): dedupe, newest first, cap 200, filter and search, `merging` keeps the newest per file; `ValuesHandOffTests`: encode → decode → encode is byte-equal; format 2 is refused with the "newer AfterGlow" sentence; an id with `/` is `damaged("the message from another app")`; a failed encode is `ioFailed("the message from another app")`; `newID()` is 36 lowercase characters and two calls differ; `isExpired` at 7 days + 1 s | the cap or order breaks, a nested id decodes, or a newer format is accepted |
| SC-1c | `ValuesExchangeTests`: `SuiteColorValue` hex for sRGB and Display P3 keeps its space; `AssetIndex` add/update bumps the revision; `AssetEnvelope` JSON round trip | a colour converts space, or a revision doesn't move |
| SC-1d | `ValuesSettingsTests`: `autosaveSeconds` clamps to 10…600; `SuiteVersion("1.2")` == 1.2.0 and "1.x" is nil; `UpdateFeed` parses the feed fixture (inline); `ValuesHomeLayoutTests`: the 7.3 table exactly at 880, 1000, 1280, 1728, and the sweep 880…2560 (columns ≥ 1, card 168–240 and a multiple of 4, the row fits) | a width row differs, a card leaves the grid, or a clamp fails |
| SC-2a, SC-2b | `ContractShapeTests`, `ContractShapeMoreTests`: one minimal in-test conformer per protocol calls every requirement once inside `do throws(SuiteError)` and checks the `changes()` streams of `RecentWork`, `AppSwitching`, `AssetLibrary`, `PreferencesStoring` yield | a requirement's signature drifts from blueprint 5.2 (the test stops compiling), or a stream never yields |
| SC-3a | `FakesTier1Tests`: `FakeSwitching` refuses a missing app with `appMissing`, `terminate` yields a change; `FakeRecents` keeps a thumbnail on re-note; `FakeRouting` routes all eight `weekOfWork` names and refuses `notes.txt` with the 5.4 sentence; `FakeHandOffs.send` switches the target; `FakeThumbnails` writes `thumbnails/<fileKey>.png`; `FakeHome` empty and no-match messages; `FakeDocumentHost` refuses an unknown verb | any behavior blueprint 5.5 states differs |
| SC-3b | `FakesExchangeTests`: a damaged envelope falls back to SVG then PNG; Flare refuses an image with "Flare can't paste images yet."; an empty pasteboard is `nothingToPaste`; a dropped `file://<path>/Logo.design` gives a ref whose `fileID == SuiteDocumentRef.fileID(forPath:)` and dedupes against a recents entry for the same path; `FakeRoundTrips` refuses a missing original with `originalMissing`; `FakeLinking` reports `updateAvailable` and `missing` | the file-URL branch keeps a raw path, or a fallback order changes |
| SC-3c | `FakesSettingsTests`: a stale preferences revision is refused; onboarding's "Photos" puts Library and Photo first in `homeOrder`; a forged update signature is `updateNotVerified`; a refusing app gives `updatePostponed`. `SuiteFixturesTests`: every name in `SuiteFixtures.names` builds (unknown is nil); `weekOfWork` has 8 items newest first with thumbnails `thumbnails/<fileKey>.png`; `crowd` 200; `assets` 6 colours (2 P3), 2 vectors with source `Cards.design`, 1 image, 1 animation | a fixture's contents drift from blueprint 4.1 |
| SC-4a | `StoreTests`: write then read returns the value and revision 1; a write expecting a stale revision throws `staleRevision` and leaves the file; `update` merges and bumps; a crash between temp write and rename leaves the old file readable; `writeData` then `readData` returns the same bytes with no envelope; `supportFolder` honours `-SuiteSupportDir` | a stale write lands, or a partial file is ever read |
| SC-4b | `SuiteServicesTests`: `.fake` has `isPreview` true; `with(animations:updates:)` swaps only those two; `slotFeatures` names a feature for each of the 15 members; `.fake`'s `pending` is empty. `Budget+Store` (QB-SM6): the test binary relaunched twice with `Process`, each noting 500 recents into one temp store, ends with recents.json at revision 1,000 holding the 200 newest of the 1,000 distinct notes, and a median write ≤ 50 ms (debug gate). `StoreRoundTripTests` (QB-SV8): recents, assets, preferences and a hand-off encode → decode → encode byte-equal. `SuiteContractsJourneyTests`: steps 1–5 above | an entry is lost across processes, a store file doesn't round trip, or a journey step differs |
| SC-4c | `FixtureSeederTests`: seeding `weekOfWork` from a temp source folder writes the three store files, copies 8 documents and their thumbnails to `thumbnails/<fileKey>.png`; `missing` skips `Cards.design`; with `Intro.halo` absent from the source the seed still succeeds and writes 7 documents; an unknown name throws "No fixture named …" | a thumbnail lands under a file name, `missing` copies the card, or an absent source fails the seed |
| SC-5a | `StoreRecentsTests`: note, remove, clear app go to `recents.json` with a new revision each; two `StoreRecents` on one folder see each other's writes after `externalChange()`; `onWrite` is called with `recents.json` once per write; `changes()` yields | a write is lost, or another instance's write is never seen |
| SC-5b | `SuiteLiveServicesTests` (macOS, AppSnapshotTests): `SuiteServices.live(support: <tmp>, app: .launcher, arguments: [])` has `isPreview` false; `recents` notes and lists through the temp folder and is absent from `pending`; every other member is in `pending` with "<What> isn't available yet." (its feature's `SuiteIdentity.featurePhrases` phrase); each throwing one (switching, sending, receiving, thumbnails and the SC-5c ones) throws `notAvailable` with that sentence; the macOS job builds `SuiteShell` | a slot is live too early, a reason is wrong, or recents isn't live |
| SC-5c | `SuiteLiveServicesTests` extended to all 15 members (14 slot files); `animations` and `updates` are the fakes until `with(animations:updates:)` is called | a member is missing or a reason is wrong |

## Quality tests

| quality row | budget (device target; debug gate ×10) | test |
|---|---|---|
| QB-SM6 store under the lock, two processes | recents.json ends at revision 1,000 and holds the 200 newest of the 1,000 distinct notes; each write ≤ 5 ms median (≤ 50 ms debug) | `Budget+Store.twoProcessesLoseNothing` |
| QB-SV8 store files round trip | byte-equal re-encoding | `StoreRoundTripTests` |
| QB-SM1 hook | `RecentsList.note` into 200 ≤ 0.2 ms (≤ 2 ms debug) | `ValuesRecentsTests.noteIntoFullList` (recents-open-in adds `Budget+Recents` in wave 3) |
| Reliability 7.6: an expired or newer-format hand-off never acts | refused with its sentence | `ValuesHandOffTests` |

## Done check

- **Journeys green:** the dev macOS run triggered by SC-5c (`feature-done`)
  is green: `SuiteShell` builds and `SuiteLiveServicesTests` passes; every
  app journey unchanged.
- **Audit zero new:** no app count over `UITests/audit-baseline.json`.
- **Contact sheet:** `Belt-Contact-Sheet: <run link>` on the feature issue;
  no screen changes in this feature, and the comment says so, with the
  Linux test count of `SuiteModelTests` and QB-SM6's measured median.
