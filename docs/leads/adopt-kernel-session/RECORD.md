# adopt-kernel-session lead record

Issue: #1940 · Packet: docs/blueprints/suiteui/features/adopt-kernel-session.md
Run: act-1a15749e569-ngtj (slice AD-library; AD-flare, AD-design, AD-photo, AD-halo done in earlier runs)
Stage: 3 wave B
Base: 25a8d9a2 (origin/dev); lead branch rebased on main b3011ab9
Next: #3396 (AD-l1 + AD-l2 folded, feature-done, head 630145fc) waits the lane's macOS build and merge; then a green ci.yml run on dev containing it gives Belt-Slice-Done: AD-library and Belt-Contact-Sheet. Open findings: 0

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AD-flare | Flare runs its session on DocumentSession, SaveStatus, RecoveryOffer and VersionedJSON behind its existing API; its copy deleted | AD-f1, AD-f2 | MJ-AD-flare | editor-kernel:EK-doc | no | 0 | building | – | – |
| AD-photo | Photo runs its session on DocumentSession, SaveStatus, RecoveryOffer and VersionedJSON behind its existing API; its copy deleted | AD-p1, AD-p2 | MJ-AD-photo | editor-kernel:EK-doc | no | 0 | done (AD-p1 #2826, AD-p2 #3253; Belt-Slice-Done issuecomment-6281081759) | 39349878829 (Linux job 118395364026 green) | – |
| AD-halo | Halo runs its session on DocumentSession, SaveStatus, RecoveryOffer and VersionedJSON behind its existing API; its copy deleted | AD-h1, AD-h2 | MJ-AD-halo | editor-kernel:EK-doc | no | 0 | done (AD-h1 #2827, AD-h2 #3252; Belt-Slice-Done issuecomment-6281082031) | 39349878829 (Linux job 118395364026 green) | – |
| AD-design | Design runs its session on DocumentSession, SaveStatus, RecoveryOffer and VersionedJSON behind its existing API; its copy deleted | AD-d1, AD-d2 | MJ-AD-design | editor-kernel:EK-doc | no | 0 | ready (FH-1, FH-2 merged) | – | – |
| AD-library | Library runs its session on DocumentSession, SaveStatus, RecoveryOffer and VersionedJSON behind its existing API; its copy deleted | AD-l1, AD-l2 | MJ-AD-library | editor-kernel:EK-doc, adopt-kernel-undo:AU-library | no | 0 | building (#3396, lane) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AD-f1 | AD-flare | 1 | Flare adapter | `Sources/FlareModel/FlareFiles.swift`, `Sources/FlareApp/FlareAutosave.swift`, `Tests/FlareModelTests/FlareFilesTests.swift`, `Tests/FlareModelTests/FlareAutosaveDueTests.swift`, `Tests/FlareModelTests/FlareRecoveryRestoreTests.swift`, `Tests/mutations/FlareModel.KernelSessionAdapter.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | #2979 | open (lane mac build) |
| AD-f2 | AD-flare | 2 | Flare delete | `Sources/FlareModel/FlareFiles.swift`, `Sources/FlareApp/FlareAutosave.swift`, `Tests/mutations/FlareModel.FlareFiles.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | – | waits AD-f1 |
| AD-p1 | AD-photo | 1 | Photo adapter | `Sources/PhotoModel/PhotoRecovery.swift`, `Sources/PhotoModel/Live/LiveArchive.swift`, `Sources/PhotoModel/PhotoSaveStatusHelp.swift`, `Tests/PhotoModelTests/PhotoRecoveryTests.swift`, `Tests/PhotoModelTests/LiveRecoveryTests.swift`, `Tests/PhotoModelTests/PhotoDocumentFileTests.swift`, `Tests/PhotoModelTests/PhotoSaveStatusHelpTests.swift`, `Tests/mutations/PhotoModel.KernelSessionAdapter.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | #2826 | merged |
| AD-p2 | AD-photo | 2 | Photo delete | `Sources/PhotoModel/PhotoRecovery.swift`, `Sources/PhotoModel/Live/LiveArchive.swift`, `Sources/PhotoModel/PhotoSaveStatusHelp.swift`, `Tests/mutations/PhotoModel.PhotoRecovery.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | #3253 | merged 17:15Z (head 60db298f; 2 files +12/−14; mutate 4/4) |
| AD-h1 | AD-halo | 1 | Halo adapter | `Sources/HaloModel/HaloFiles.swift`, `Sources/HaloModel/Live/HaloFileEnvelope.swift`, `Sources/HaloModel/Live/HaloFileValidation.swift`, `Tests/HaloModelTests/HaloFileTests.swift`, `Tests/HaloModelTests/HaloFileValidationTests.swift`, `Tests/HaloModelTests/ProjectFilesContractTests.swift`, `Tests/mutations/HaloModel.KernelSessionAdapter.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | #2827 | merged |
| AD-h2 | AD-halo | 2 | Halo delete | `Sources/HaloModel/HaloFiles.swift`, `Sources/HaloModel/Live/HaloFileEnvelope.swift`, `Sources/HaloModel/Live/HaloFileValidation.swift`, `Tests/mutations/HaloModel.HaloFiles.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | #3252 | merged 17:15Z (head 5eb72fac; 2 files +29/−12; mutate 4/4 + HaloFiles 3/3) |
| AD-d1 | AD-design | 1 | Design adapter | `Sources/DesignModel/DesignFile.swift`, `Sources/DesignModel/Live/LiveFiling.swift`, `Tests/DesignModelTests/DesignFileTests.swift`, `Tests/DesignModelTests/DesignDocumentTests.swift`, `Tests/mutations/DesignModel.KernelSessionAdapter.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | #3010 | open (lane mac build) |
| AD-d2 | AD-design | 2 | Design delete | `Sources/DesignModel/DesignFile.swift`, `Sources/DesignModel/Live/LiveFiling.swift`, `Tests/mutations/DesignModel.LiveFiling.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | – | waits AD-d1 |
| AD-l1 | AD-library | 1 | Library adapter | `Sources/LibraryModel/LibraryReadouts.swift`, `Sources/LibraryModel/Live/LiveCatalogCoding.swift`, `Tests/LibraryModelTests/LibraryCatalogTests.swift`, `Tests/LibraryModelTests/LibraryReadoutsTests.swift`, `Tests/mutations/LibraryModel.KernelSessionAdapter.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | #3396 | dev merged in (C4 part resolved), gate PASS, head 630145fc |
| AD-l2 | AD-library | 2 | Library delete | `Sources/LibraryModel/LibraryReadouts.swift`, `Sources/LibraryModel/Live/LiveCatalogCoding.swift`, `Tests/mutations/LibraryModel.LibraryReadouts.json` | app tests unchanged + mutate KernelSessionAdapter plan (x1) / --validate (x2) | #3396 | folded into #3396 (feature-done): 3 inline dirty compares now read catalogSession.isDirty; wave built |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Fresh start (no origin/lead/adopt-kernel-session). Status branch sits on main 0965457 as Belt asked; PRs base `dev` (CLAUDE.md, fast-lane.sh).
- Every slice is Model-first; an x1 that touches `Sources/*App/` is `ui: true` and also waits on editor-kernel:EK-u (packet, Slices).
- 2026-10-18 relaunch act-1a14f91ff8b-nq4v: EK-doc is done (Belt), so the Flare, Photo and Halo adapters start.
- AD-design held: design files-history is `planned` and its FH-1 (codec into LiveFiling) and FH-2 (didSave) edit DesignFile.swift and LiveFiling.swift, unmerged (branch lead/files-history-FH-2 open); the packet's hand-off says start after its slice on them.

- 2026-10-18 relaunch act-1a1509b245f-653k: brief scopes this run to AD-flare, AD-design, AD-library (AD-photo, AD-halo already handled). The captain's 2026-10-17 note (out of the beta cut) predates this brief; Belt's brief names these slices, so they build.
- AD-library stays blocked: adopt-kernel-undo (AU-library) is `planned` with no feature issue; LibraryReadouts.swift is shared with it and that slice goes first.
- AD-d1 builders read finding #2938 (design line: DesignHistory reimplements kernel saved-state tracking): the adapter's DocumentSession is where that dirty tracking belongs.

## Open
- 2026-10-20T03:11Z relaunch act-1a15749e569-ngtj: brief names AD-library only; lead branch rebased onto main b3011ab9. PRs still base dev (lane BASE_BRANCH; main trails dev by 1646 commits). #3396 AD-l1 needs-rebase.
- AD-l2 folded into #3396 (<50 lines, +32/-10): saveRevision/savedRevision stay as token storage (import without step, monotonic save acks, LibraryWindow watches saveRevision), so the packet's "remove" holds only for the inline compares.
- 2026-10-19T13:15Z relaunch act-1a1540ed5f3-c3x9: brief adds AD-photo and AD-halo; AD-p2 and AD-h2 start (AD-p1/AD-h1 merged, no other PR on their files). PRs base dev (lane BASE_BRANCH is dev; brief says main).
- 2026-10-19T14:10Z AD-p2/AD-h2 deletions came out small: AD-p1/AD-h1 already removed most of the copies. Kept on purpose (live callers or different wording/semantics): Halo `HaloFileState.unsaved`, envelope `format` header and error words, Halo recents not moved to RecentsList (kernel keeps last per id, Halo keeps first per path); Photo autosaveDue NaN guard and Photo RecoveryOffer words. `PhotoModel.PhotoRecovery.json` does not exist; no plan find moved.
- AD-design waits design:files-history FH-1/FH-2 on DesignFile.swift and LiveFiling.swift.
- AD-library waits adopt-kernel-undo:AU-library (blocked on filters-collections).
- 2026-10-18 AD-f1 #2979: tokens from saved-document compare (FlareCore has no undo step number; needs-core issue could not be filed, creative-core 403); save now ends an in-progress scrub (tested).
- 2026-10-18 AD-d1 #3010: adapter DesignSession+Kernel.swift; also drops the DesignHistory plan entry on markSaved's endRun (now dead, moved into the new plan). #2938 (files-history finding) stays open: DesignHistory.swift still owns isDirty, outside AD-d1's files; AD-d2 deletes the dead markSaved and DesignFileHeader.
- 2026-10-18T21:38:11Z check: dev 8640f00f; #2979 AD-f1 and #3010 AD-d1 wait on lane mac build; 0 findings
- 2026-10-18T22:16:45Z check: #2979 AD-f1 mac build failed in PhotoZoomSweepTests (not ours, fixed on dev by #2990): merged dev, gate PASS, head 9e35dd3d; #3010 AD-d1 needs-rebase on design-model-sources C4 part: merged dev, kept both descriptions, gate PASS, head 7a9e3a2c
- 22:36Z dev 349578b8; #2973/#2979/#3010/#3011 wait on lane mac builds of their new heads; 0 findings
- 22:56Z #3010 AD-d1 merged; AD-d2 builder started; #2979 mac build in progress
- 23:04Z AD-d2 #3024 opened (head 8ac2053e, Mutate 4/4 KernelSessionAdapter; LiveFiling 7/7): DesignFileHeader and markSaved deleted; waits on lane mac build
- 23:16Z #2979 AD-f1 merged (626404ce); AD-f2 builder started; #3024 AD-d2 mac build queued
- 23:24Z AD-f2 #3034 opened (head 51c324dc, Mutate 4/4 KernelSessionAdapter): app RecoveryOffer.date dropped for the kernel offer's savedAt; AD-f1 had already replaced dirty/due in place; waits on lane mac build
- 23:36Z #3034 AD-f2 and #3024 AD-d2 wait on lane mac builds
- 2026-10-18T23:56Z #3024 AD-d2 and #3034 AD-f2 clean, lane macOS builds 39175673182 / 39176703183 queued (runner backlog). AD-library still blocked on AU-library.
- 2026-10-19T00:16Z #3024, #3034 clean; lane macOS builds 39175673182 / 39176703183 still queued. AD-library blocked on AU-library.
- 2026-10-19T00:36Z AD-d2 #3024 merged (f6418684): AD-design's last PR. #3034 AD-f2 mac build 39176703183 still queued. AD-library blocked on AU-library.
- 2026-10-19T00:56Z #3034 AD-f2 mac build 39176703183 in progress. AD-design (#3024 f6418684) waits on a suiteui/full run past 7ccb643d. AD-library blocked on AU-library.
- 2026-10-19T01:16Z AD-f2 #3034 merged (b15dd305), AD-flare's last PR. AD-design f6418684 is in full CI 39184285016 (124fe38c, pending); AD-flare needs a later run. AD-library blocked on AU-library.
- 2026-10-19T01:36Z waiting: full CI 39185202220 at 036f8d0a contains AD-design, AD-flare; AD-library blocked on AU-library
- 2026-10-19T01:56Z waiting: full CI 39185202220 cancelled; need a green suiteui/full run containing f6418684 (AD-design), b15dd305 (AD-flare); suiteui 39187049656 / CI 39186699154 at ed0fed9e queued; AD-library blocked on AU-library
- 2026-10-19T02:16Z waiting: scoped suiteui 39187049656 at ed0fed9e in progress (contains AD-design, AD-flare); full CI 39186699154 cancelled; AD-library blocked on AU-library
- 2026-10-19T02:35Z waiting: scoped suiteui 39187049656 at ed0fed9e still in progress (contains AD-design, AD-flare); full CI 39188162085 at 17dc84c7 pending; AD-library blocked on AU-library
- 2026-10-19T02:55Z waiting: scoped suiteui 39187049656 at ed0fed9e still in progress (contains AD-design, AD-flare); full CI 39188162085 pending; AD-library blocked on AU-library
- 2026-10-19T03:17Z AD-design, AD-flare done via scoped suiteui 39187049656 (ed0fed9e); AD-library blocked on adopt-kernel-undo:AU-library
- 2026-10-19T03:36Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open)
- 2026-10-19T03:55Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open)
- 2026-10-19T04:15Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open)
- 2026-10-19T04:36Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open)
- 2026-10-19T04:55Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open)
- 2026-10-19T05:15Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev; only AU-halo #3139 open)
- 2026-10-19T05:34Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev; only AU-halo #3139 open)
- 2026-10-19T05:54Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev; only AU-halo #3139 open)
- 2026-10-19T06:22Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev; only AU-halo #3139 open)
- 2026-10-19T06:42Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev; only AU-halo #3139 open)
- 2026-10-19T07:03Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev; only AU-halo #3139 open)
- 2026-10-19T07:25Z AD-library still blocked on adopt-kernel-undo:AU-library (AU-halo #3139 merged; #3184 Halo open; no AU-library)
- 2026-10-19T07:45Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T08:05Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T08:24Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T08:44Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T09:04Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T09:24Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T09:43Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T10:04Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T10:23Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T10:42Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; #3184 Halo open)
- 2026-10-19T11:04Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open; Halo #3184 merged)
- 2026-10-19T11:24Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open)
- 2026-10-19T11:44Z AD-library still blocked on adopt-kernel-undo:AU-library (none on dev or open)
