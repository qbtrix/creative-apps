# Library features: waves

Waves 1 and 2 of the Library blueprint (`docs/blueprints/library.md`,
section 8; data in `docs/blueprints/library/waves.json`) as feature packets,
one feature-lead session each. A wave starts when everything it waits on has
merged. Two features in the same wave never own the same file. Each packet
lists its tasks, owned files, acceptance tests, quality bars and done check.
Waves 3 to 5 (develop, status-and-layout, crop, export, and the three not-v1
features) get their packets once wave 2 has landed.

| wave | feature | packet | covers | waits on | feature issue |
|---|---|---|---|---|---|
| 1 | Contracts, fakes, catalog state, undo, launch arguments, the app split | `spine.md` | #235 (and the fix for #156, see below) | nothing | filed after this PR merges |
| 2 | Import a folder | `import.md` | #210 | spine | file when ready |
| 2 | Real grid thumbnails | `thumbnails.md` | #33 | spine, #779 (S-L2), #333 | file when ready |
| 2 | Cull from the keyboard with undo and Auto Advance | `cull.md` | #211, #426, #724 (keys) | spine, #333 | file when ready |
| 2 | The catalog file | `persist.md` | #212 | spine, #333 | file when ready |
| 2 | The loupe on CanvasViewport | `loupe-viewport.md` | #724 (zoom, real size) | spine, #333 | file when ready |

## File when ready

Belt launches a lead the moment a feature issue exists, so no feature issue
is filed before its packet is on `dev`: the spine's is filed once this
packet PR has merged. The lead playbook (`docs/factory/lead.md`, stage 0)
also stops a lead whose `Depends on:` issue is still open, so the wave-2
issues are filed only when every issue in their line has merged or closed. Each issue gets the title "Feature:
<name> (<feature>)", labels `feature-lead`, `line:library` and `p1`, a link
to its packet, the issues it covers, one `Depends on:` line and the lead
contract below.

| feature | file when these have closed | its `Depends on:` line |
|---|---|---|
| import | the spine issue | `Depends on: #<spine issue>` |
| thumbnails | the spine issue, #779, #333 | `Depends on: #<spine issue>, #779, #333` |
| cull | the spine issue, #333 | `Depends on: #<spine issue>, #333` |
| persist | the spine issue, #333 | `Depends on: #<spine issue>, #333` |
| loupe-viewport | the spine issue, #333 | `Depends on: #<spine issue>, #333` |

If #333 is slow, the supervisor may file cull, persist and loupe-viewport
without it: every task but their journey task can land, and the journey task
then waits inside the lead (its row in the packet names #333). Import needs
no #333: it owns `UITests/LibraryJourneyTests.swift` in wave 2 (blueprint
4.1, one journey writer per wave before #333).

## What each feature waits on

- **creative-core: nothing.** Every CoreRaster call waves 1 and 2 use is on
  creative-core `main` cfad97f, which `Package.resolved` pins
  (`resized`, `rgba8`, `PixelBuffer`, the develop calls the stubs name). The
  blueprint checked its contracts on `dev` 4cac701, whose CoreRaster and
  CoreColor sources are the same (review note; the blueprint's labels are
  fixed in this PR).
- **SuiteUI, hard (in a `Depends on:` line):** #779 S-L2 `ThumbnailGrid`
  additions (thumbnails: visible cells, cell values, the reject and
  unreadable marks); #333 QH-4 journey files (the `+<Area>.swift` journey
  files of thumbnails, cull, persist, loupe-viewport).
- **SuiteUI, soft (placeholders until they land):** #780 S-L4
  `InlineNotice` (spine, import, persist), #781 S-L5 `ProgressRow` (import).
  Swapping a placeholder for the component is a one-file fix in the owning
  feature, or a `gap` issue once the feature has finished.
- **The spine's area hooks.** Wave-2 areas need lifecycle (import on
  launch, restore and save, loupe focus changes), per-area state and the
  model, all in `LibraryWindow.swift`, which no wave-2 feature owns. The
  spine's SA-4 gives each area a state class, no-op hook methods and the
  model in wave 1, and passes the model and `LibraryMenu` into the grid and
  the loupe, so each wave-2 feature edits only its own files (spine packet,
  Area hooks).
- **Inside wave 2:** every (L) journey step imports written files through
  the live importer, so the (L) task of thumbnails (TH-8), cull (CU-7's L
  run), persist (PE-6) and loupe-viewport (LV-10) waits for import's IM-6 to
  merge. Every (L) launch passes a fresh `-LibraryCatalogDir` from the
  spine's `LibraryFiles.freshCatalogDir()`. `check_waves.py` forbids same-wave feature dependencies, so this is
  a task order, not a feature dependency. The same holds for persist's J8
  (cull's CU-5 for the rating keys, loupe-viewport's LV-7 for the loupe
  help) and loupe-viewport's slow `preview` step (thumbnails' TH-6).

## Perf tasks

Each feature's perf journey (P1, P2, P4, P6, P7; IM-9, TH-9, CU-8, PE-7,
LV-11) needs SuiteUI's `FrameProbe` (#330), its named marks (#782, S-L8) and
#333's helpers. They ship report-only (blueprint 7). A perf task runs when
all three have merged. If any is still open when the feature's other tasks
are done, the lead files the perf task as a `gap` issue on `line:library`
(labels `gap`, `line:library`, `p3`) naming the packet row and the open
issues, and finishes the feature without it: the done check counts the
journeys, the audit and the contact sheet, not the perf rows. This keeps a
`p3` harness issue out of every `Depends on:` line.

## Owned files

The owned files of `waves.json`, with these changes the packets make. In
each wave no two features own the same file, and no feature owns a shared
file (next section).

| feature | adds (new files, not in `waves.json`) | drops or renames |
|---|---|---|
| spine | `Sources/LibraryModel/LibraryReadouts.swift`, `Sources/LibraryModel/LibraryKeys.swift`, `Sources/LibraryModel/Fakes/FakeRendering.swift` (under its `Fakes/`), `Tests/LibraryModelTests/LibraryValuesTests.swift`, `LibraryPhotoItemTests.swift`, `LibraryContractsTests.swift`, `LibraryFakesTests.swift`, `LibraryFakeRenderingTests.swift`, `LibraryCollectionSwitchTests.swift`, `LibraryReadoutsTests.swift`, `LibraryKeysTests.swift`, `UITests/LibraryJourneyTests+Files.swift` | `UITests/Journey+Library.swift` becomes `UITests/LibraryJourneyTests+Files.swift`: `UITests/Journey*.swift` is SuiteUI's |
| import | `Tests/LibraryModelTests/LibraryLiveImporterTests.swift`; takes `UITests/LibraryJourneyTests+Files.swift` in wave 2 (to move the helpers there if #333 merges mid-wave) | – |
| thumbnails | `Tests/LibraryModelTests/LibraryThumbnailResultTests.swift`, `LibraryLiveThumbnailsTests.swift` | `Sources/LibraryApp/DisplayImage+Image.swift` stays the spine's: SA-1 lands `Image(display:)` there, since the loupe draws with it in the same wave |
| cull | – | – |
| persist | `Tests/LibraryModelTests/LibraryCatalogCodingTests.swift`, `LibraryPersistGolden.swift`, `Tests/AppSnapshotTests/LibraryCatalogStoreTests.swift` | `Tests/LibraryModelTests/Golden/catalog-v1.json` is not created (review note: no resource in the protected `Package.swift`; the golden is a Swift string literal) |
| loupe-viewport | `Tests/LibraryModelTests/LibraryLiveLoupeTests.swift` | – |

`waves.json` is left as merged; `check_waves.py` still passes on it. A later
packet writer who regenerates section 8 folds these rows in.

## Shared files

All apps build in parallel, so only SuiteUI features change
`Sources/SuiteUI/**`, `project.yml`, `UITests/Journey*.swift`,
`UITests/Journey+Input.swift`, `Tests/AppSnapshotTests/AppSnapshotTests.swift`
and the shared test infrastructure those touch. A Library feature that needs
one of those changes names the SuiteUI issue that makes it in its `Depends
on:` line (#779, #333 above). Each Library feature owns only
`Sources/Library*/`, `Tests/LibraryModelTests/`, new `Library`-prefixed
files in `Tests/AppSnapshotTests/` (the shared snapshot target already holds
four: `LibraryEmptyCollectionSnapshots`, `LibraryGridSnapshots`,
`LibraryLoupeSnapshots`, `LibraryMetadataSnapshots`; nobody else edits
them), `UITests/LibraryJourneyTests*.swift` and its own docs.

- **No feature edits `docs/c4/model.json`, `docs/design.md` or
  `docs/review-rubric.md`** (review note on unowned shared docs). The
  supervisor folds the planned C4 descriptions (`c4-planned.json`), the
  "Catalog apps (Library)" look rules (blueprint 6.1) and the `QB-LIB` ids
  into them later. Every new source file sits in `Sources/LibraryModel/` or
  `Sources/LibraryApp/`, which `model.json`'s target components already own,
  so the C4 ownership check passes without an edit.
- **`AppSnapshotTests.swift` keeps compiling unchanged.** It calls
  `LibraryBrowser(model: LibraryCatalog())`; the spine keeps that call valid
  (`init(services: = .fake())`, defaulted browser parameters).
- `UITests/Journey+Budgets.swift` (the perf gates after ten green runs) is
  SuiteUI's; no wave-1 or wave-2 task edits it.

## Review notes folded in (PR #769, approve with notes)

| note | where it went |
|---|---|
| Unowned shared docs (`model.json`, `design.md`, `review-rubric.md`) collide in wave 2 | No feature edits them; the supervisor folds them in (above) |
| The pin is creative-core `dev` 4cac701, not `main` | Blueprint labels and `check.sh` comment fixed (one line each); packets name `main` cfad97f as what `Package.resolved` pins |
| J1 step 6 can't pass on the fakes | Spine: `FakeImporter` reports progress before its wait and paces files in `.slow`; the `shoot-unimported` fixture seeds only the fakes (spine contract slice, SP-4, SP-12; import J1 step 6) |
| Key routing would need `LibraryWindow.swift` in waves 2 to 4 | Spine routes every single key (0–5, P, X, U, R, G, Return, Home, End) through `LibraryKey` to its area's `LibraryMenu` sub-struct in wave 1 (spine SA-4) |
| S-L1 should reuse `ToneCurveEditor`'s histogram drawing | Wave 3 (develop); recorded below for the SuiteUI filing |
| `CropGeometry.initial` "as large as fits" overstates | The spine lands the contract comment saying it is conservative (about 4% under the largest upright square at 1:1, 5°) |
| The golden JSON is not a declared resource | Persist inlines it as a Swift string literal (`LibraryPersistGolden.swift`) |
| `loupeArtboard` removal sits with the spine but its files are loupe-viewport's | Loupe-viewport removes it (LV-7); blueprint 5.5 says so (one-line fix) |
| `check.sh`'s scratch manifest has no platforms | `platforms: [.macOS("26.0")]` added (one line) |
| #156 and open PR #217 | #156 was closed by #769's merge, but #217 is still open and the bug is on `dev`. Spine SP-9 lands the fix only if #217 hasn't merged first, with `Refs #156`; whichever lands second rebases |

## Critic round

One critic agent tried to refute the six packets against the blueprint, the
code and these rules. It confirmed that wave 2's owned files are disjoint,
that no packet touches a shared file, and that every covered issue is open.
It found 4 blocking, 14 major and 9 minor problems, all fixed in the packets:

- **Compile order.** SP-7 stored a `CatalogHistory` before SP-11 declared
  it. SP-11 is now the value type, landing before SP-7; SP-14 adds the
  catalog methods.
- **Redeclaration.** SP-13 redeclared the contract's `cullSummary` and
  contradicted its text. SP-13 now uses the contract's version, and its
  help is `availability.help`.
- **Hidden edits.** Wave-2 areas needed lifecycle, state and the model in
  `LibraryWindow.swift`, and the grid and loupe were built in import's
  `LibraryBrowser.swift`. The spine now provides the area hooks and passes
  `model` and `menu` down.
- **A test that couldn't pass.** TH-1's memory test held 240 MB of visible
  images under a 128 MB cap. It now uses 512 px images, never evicts a
  visible image, and an empty visible list evicts nothing.
- **Undeclared state.** Import kept a pending folder no file declared; the
  folder is now a parameter. Cull counted order rebuilds with nothing to
  count; that test now checks behavior.
- **Journeys that would hang or race:**
  - J1 step 6 would stop at the open panel; it now passes
    `-LibraryImportFolder`.
  - J1 step 2 asserted a racy `loading` state; it now checks the cell count.
  - An import on launch could race the restore; `beginImport` now waits for
    the catalog to load.
  - The loupe's canvas would have swallowed the arrow keys; it now passes
    `onKey`.
  - J2 clicked a menu title that doesn't exist in the grid; it now uses
    Larger Thumbnails.
  - J2 asserted fixed pixel sizes; it now compares them.
- **Missing task orders inside wave 2:**
  - J8 needs cull's keys and the loupe's help.
  - The slow `preview` step needs thumbnails' area.
- **Tasks with no test of their own.** IM-4 now carries the decode tests.
  PE-4 gets `LibraryCatalogStoreTests`.
- **Persist details:**
  - The golden needs `.withoutEscapingSlashes` and must be pasted from the
    encoder's actual output.
  - The flush on quit uses a synchronous `writeNow`.
- **Smaller fixes:**
  - SP-8 depends on SP-12.
  - The fail-mode wording in cull's tests is corrected.
  - Inspector edits never auto-advance.
  - The (L) launches use `freshCatalogDir()` from SJ-2.
  - The `Closes #724` task comments on how J3 and J4 cover #724's
    acceptance.
  - The spine's issue number is filled in after merge.

## SuiteUI coordination

Filed for waves 1 and 2: #779 (S-L2), #780 (S-L4), #781 (S-L5), #782 (S-L8,
after #330). Not filed yet, for waves 3 and 4: S-L1 `HistogramView`
(develop), S-L3 `CropHandles` (crop), S-L6 row reset (develop), S-L7
optional status pills (status-and-layout). When S-L1 is filed: SuiteUI's
`ToneCurveEditor.swift` already draws a histogram, so S-L1 extracts that
drawing into `HistogramView` and `ToneCurveEditor` reuses it (no second
copy); Photo is likely to want the same part, so it is a cross-app item for
the SuiteUI lead.

## Issue lines

- **#724** is split: cull's CU-5 lands the keys, loupe-viewport's LV-8 the
  zoom and real size. Whichever merges first says `Part of #724`; the second
  says `Closes #724`.
- **#210, #211, #212** still carry the old chain in their `Depends on`
  lines; with the spine in place they all depend on the spine only
  (blueprint 8.1, decision D5). The captain edits those lines; the packets
  already plan that way.
- **#423 and #425**: their catalog-file parts are done by persist; the
  issues close with develop (wave 3) and crop (wave 4).

## The lead contract

Every feature lead and every task below codes against this. It is handed
verbatim to every session, and each feature issue carries it.

1. **Feature issue.** One GitHub issue per feature, labels `feature-lead` and `line:<app>`. Body links the packet `docs/blueprints/<app>/features/<feature>.md` and has one `Depends on:` line.
2. **Run.** Belt runs one cloud session per feature issue (a lead), from the trusted launch folder, with the repo's Auto settings (creative-apps#733, creative-core#263). A lead holds one in-flight slot however many PRs it opens.
3. **Status channel.** The lead pushes `docs/leads/<feature>/RECORD.md` and `timeline.tsv` to branch `lead/<feature>` after every stage. Belt reads the branch's last commit time; nothing else is polled besides PRs and issue comments.
4. **Swarm PRs.** Base `dev`, label `fast-lane`, at most 400 lines and 15 files. Body lines: `Belt-Lead: <run id>`, `Feature: <feature>`, then `Fast-Check: pass` and `Head: <full sha>` after `scripts/ci` passes. The lane merges them. Nobody merges into dev by hand or by an agent.
5. **Review policy (decision for the captain).** `Belt-Lead:` PRs do not need the `belt/review` status. The lead's own critic panel is the review. Only `Belt-Run:` and `Belt-Test:` PRs keep it.
6. **Done.** All three: a `Belt-Lead:` PR labelled `feature-done` has merged; the CI run it triggered on dev is green; the lead commented on the feature issue with a line starting `Belt-Contact-Sheet:` and the run link.
7. **Stall.** No commit on `lead/<feature>`, no PR event and no issue comment for 30 min: Belt sends one nudge with `claude -p --cloud <session id> "<resume text>"`. A second stall: relaunch with a resume brief that says "read RECORD.md, continue from the last stage". A third: label the issue `needs-human` and stop.
8. **Timeouts.** Lead runs: 8 h wall clock, no 1 h no-PR rule. Task runs keep today's 4 h and 1 h.
9. **Brief rules.** Step one checks out the integration branch and verifies the base SHA. Set the repo-local identity "Prakash Dalai" / `86671543+prakashUXtech@users.noreply.github.com`. No attribution line anywhere, comments included. Fixers run the full harness before handing back. The Anatomy loop stops after 2 clean rounds or 4 rounds total; once a round is clean, add no new critics. One critic lens is first-use clarity: "what does each number and label mean to someone new?". Agents never treat a chat message as a reason to stop or skip a merge; questions go to the supervisor.
