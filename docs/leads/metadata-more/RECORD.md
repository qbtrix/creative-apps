# metadata-more lead record

Issue: #1555 · Packet: docs/blueprints/library/features/metadata-more.md
Run: act-1a15749e510-0ox5 · Session: line lead (library: #1555, #1563) · Started: 2026-10-20T03:00Z
Stage: 3 wave 3
Base: 233aff5cae4aac6b2b273fc39c1ed3b06e967b3f
Next: #3465 (head 00f26ebb) and #3473 (head 7e6638e9, dev merged in) ready for the lane; when #3465 merges, merge dev into MD-5 #3492 and un-draft; when #3473 merges, the same for MD-9 #3533, MD-14 #3544, MD-19 #3545 (the second of #3465/#3473 to merge likely gets needs-rebase on the library-model-sources C4 part: keep both clauses); MD-6 #3547, MD-7 #3548, MD-8 #3550 drafts; MD-12 #3569 (draft on MD-9 #3533); MD-11 #3570 (draft on MD-9 #3533); MD-10 #3581 (draft on MD-9 #3533); MD-15 #3574 (draft on MD-14 #3544); MD-16 #3582 (draft on MD-15 #3574); MD-20 #3575 (draft on MD-19 #3545); MD-17 #3579 (draft on MD-15 #3574); MD-21 waits on filters-collections (packet)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| MD-a | contract: keywords, title, caption, camera fields, sidecar fake, cameras fixture, slots | MD-1, MD-2, MD-3, MD-4 | MD-MJ1 | cull (built) | no | 0 | building | - | - |
| MD-b | Info tab camera details | MD-5, MD-6, MD-7, MD-8 | MD-J1 | MD-a; status-and-layout (built) | yes | 0 | planned | - | - |
| MD-c | keyword/title/caption edits with undo, persisted | MD-9 .. MD-13 | MD-J2 | MD-a; MD-b; filters-collections (MD-13) | yes | 0 | planned | - | - |
| MD-d | XMP sidecar writes, originals untouched | MD-14 .. MD-18 | MD-J3 | MD-a; MD-c; filters-collections (MD-18) | yes | 0 | planned | - | - |
| MD-e | search by keyword, title, caption, camera | MD-19 .. MD-22 | MD-J4 | MD-a; filters-collections (MD-21, MD-22); MD-d | yes | 0 | planned | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| MD-1 | MD-a | 1 | CameraDetails with its cleaning init, CameraField, CameraRow stubs, selectedPhotos, selectedCameraRows; PhotoItem keywords/title/caption/camera; ImportCandidate.camera | Sources/LibraryModel/Contracts/PhotoDetails.swift, Sources/LibraryModel/PhotoItem.swift, Sources/LibraryModel/Contracts/LibraryValues.swift, Tests/LibraryModelTests/LibraryPhotoDetailsTests.swift, Tests/mutations/LibraryModel.PhotoDetails.json, Tests/mutations/LibraryModel.PhotoItem.json | LibraryPhotoDetailsTests | #3422 | merged 05:30Z |
| MD-2 | MD-a | 2 | sidecar contract, FakeSidecars, services.sidecars | see packet | LibrarySidecarContractTests | #3460 | merged 07:29Z |
| MD-3 | MD-a | 3 | cameras fixture; the decoder and importer carry camera details; MD-MJ1 | see packet | LibraryCamerasFixtureTests | #3465 | ready (dev merged, head 00f26ebb) |
| MD-4 | MD-a | 3 | inert slots: LibraryKeywords, MetadataEditing title/caption, XMPSidecar, PhotoSearch | see packet | LibraryMetadataSlotsTests | #3473 | ready (dev merged, head 1d8c098d) |
| MD-5 | MD-b | 4 | check-first for MD-b: camera rows, decode, snapshots, MD-J1, all disabled | LibraryCameraRowsTests, LibraryCameraDecodeTests, LibraryCameraSnapshots, LibraryJourneyTests+Camera | compiles, disabled | #3492 | draft, stacked on #3465 |
| MD-9 | MD-c | 4 | check-first for MD-c: keywords, caption, catalog file, keyword budgets, snapshots, MD-J2, all disabled | see packet | compiles, disabled | #3533 | draft, stacked on #3473 |
| MD-14 | MD-d | 5 | XMP/sidecar checks, disabled | LibraryXMPTests, LibrarySidecarPlanTests, LibrarySidecarWriterTests, LibrarySidecarSnapshots, LibraryJourneyTests+Sidecars | compiles, disabled | #3544 | draft, stacked on #3473 |
| MD-19 | MD-e | 4 | check-first for MD-e: search parsing, order, budget, MD-J4, all disabled | LibrarySearchTests, LibrarySearchOrderTests, LibrarySearchBudgetTests, LibraryJourneyTests+Search | compiles, disabled | #3545 | draft on #3473 + #3465 |
| MD-6 | MD-b | 5 | CameraDetails(exif:tiff:), display texts, CameraRow.rows(for:) ranges and counts; enables LibraryCameraRowsTests | PhotoDetails.swift, LibraryCameraRowsTests, plan LibraryModel.PhotoDetails.json | LibraryCameraRowsTests | #3547 | draft on #3492 |
| MD-7 | MD-b | 6 | ImageIODecoder reads Exif/TIFF into CameraDetails; LibraryCameraDecodeTests on | LA/Platform/ImageIODecoder.swift, AT/LibraryCameraDecodeTests.swift | LibraryCameraDecodeTests (macOS) | #3548 | draft, stacked on #3547 |
| MD-8 | MD-b | 7 | Info tab Camera section (InspectorSection/InspectorRow/InspectorNote), MD-J1 on | LA/LibraryInspector.swift, AT/LibraryCameraSnapshots.swift, UITests/LibraryJourneyTests+Camera.swift | LibraryCameraSnapshots, MD-J1 | #3550 | draft, stacked on #3548 |
| MD-10 .. MD-22 | MD-c..MD-e | 5+ | see packet Build waves | see packet | see packet | - | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| - | - | - | - | - | - |

## Decisions
- This run (act-1a15749e510-0ox5) resumes the record. Nothing of metadata-more is on dev yet.
- Base is origin/dev, and PRs target dev, per CLAUDE.md. The lane retargets main.
- One combined wave plan with filters-collections. MD-1's files are disjoint from FC-2b's and FC-3's, so all three run in wave 1.
- I removed the attribution footer from #3422's body after the lane flagged it. Builder prompts now say: no footer.
- Canonical first (rule 20): MD-2 checks ExportSidecar (export's XMP sidecar) before it writes new XMP code, and MD-15 reuses it or extracts from it.

- Stacked PRs stay draft until their parent merges, so the lane does not drop fast-lane for size.
- MD-2 (#3460) also updated LibraryServicesTests and LibraryLaunchTests for the new sidecars reason, and created the LibraryModel.LibraryServices plan.
- MD-3 (#3465): a fixture whose name ends `-unimported` launches empty (one line in LibraryLaunch.swift); the C4 part names the cameras fixture.
- MD-4 (#3473): title and caption read real values; set* stay inert for MD-11. Identifiers it chose: library.metadata.keyword.<name>, .removeKeyword.<name>, .keywords, .title, .caption, .sidecar, library.search. No plan, as the packet says.
- Budget tests can fail under a loaded machine (load ~21 on 4 cores). Builders rerun them alone before calling a gate red.
- MD-9 (#3533): 6 test files +397. The journey uses MD-4's real ids (library.metadata.keywords, library.metadata.removeKeyword.<name>), not the packet's. Step 7 reads catalog.json on disk (no library.catalog readout). Photos selected by Command-click. Journey launches -LibraryFixture cameras (MD-3); fine once MD-3 merges, journey skipped until MD-13.
- MD-14 (#3544): 5 files +398. Model tests use the shoot fixture (cameras not on its base); the journey launches cameras. Writer tests go through any SidecarWriting with UnconnectedSidecars, so MD-17 swaps in XMPSidecarWriter. The snapshot test checks the Model's sidecarStatus text until MD-18 gives LibraryInspector a status input. ImageIO metadata APIs checked with apple-docs.
- MD-19 (#3545, head 0221a66a): 4 test files, +343, all disabled (MD-20/MD-21/MD-22). Adds a no-op @_disfavoredOverload setSearch(_:) stand-in in LibrarySearchOrderTests that MD-21 must delete. Keyword edits in the order tests use internal recordEdit until MD-10.
- MD-6 (#3547, head d98a6dcb): own diff 3 files +130/-26, Mutate 8/8 LibraryModel.PhotoDetails. CameraRow.rows(for:) returns no rows (not even Taken) when no photo has camera details, for MD-1's test and MD-J1 step 3. A range whose ends format alike shows one value; 1/n shutter skipped when n is not finite or > 1e6. GitHub shows a conflict with dev until #3492 merges; recheck then.
- Disk hit 95%: build caches of finished builder worktrees deleted (branches all pushed).

## Open
- S-L9 #3413 (InspectorTokenRow) and S-L10 #3414 (InspectorTextRow) are soft waits for MD-13. Until they land, those rows use plain SwiftUI placeholders.
- Open line:library findings checked 2026-10-20T04:42:28Z: none in this feature's files. dev-red #3386 (macOS, range main..1b33afbb) predates these PRs; not ours.
- 06:04Z: the lane's macOS build-only runs are still queued (#3423 run 39366083753 and #3424 run 39366318428 since 03:47Z; #3460 run 39377907664 since 06:00Z). This is runner backlog, not these PRs. Building continues on stacked drafts.
- #3520 asks the supervisor to list the keyword/search budget suites (and the load-flaky Catalog/Grid ones) in Tests/perf-suites.txt. Open.
- 06:26Z check-in: #3423, #3424, #3460 unmerged; their lane macOS build-only runs (39366083753, 39366318428, 39377907664) still queued. Open line:library findings: only #3453 (export fidelity, not this feature's files). Building ahead on stacked drafts.
- 06:48Z check-in: #3423, #3424, #3460 still unmerged; lane macOS builds still queued (39366083753 for 3h). No new findings since 06:20Z. Builders: FC-9, MD-19, MD-6.

- 07:07Z: #3460 lane macOS build 39377907664 succeeded; waiting on the lane merge.
- 07:15Z check-in: #3423 and #3460 macOS builds green, not yet merged by the lane; #3424 build 39366318428 still queued (since 03:49Z). No new line:library findings in these features' files. Builders: MD-7, MD-10, FC-12; FC-10 blocked on S-L9 #3411.
- MD-7 (#3548, head ad6ca8dc): 2 files +18/-9 over MD-6; tag reading stays in the Model (decoder hands bridged Exif/TIFF dictionaries to CameraDetails). Decode tests run on macOS only, so the Linux gate proved compile and lints. No mutation plan (App target, per packet).
- 07:29Z: MD-2 #3460 merged. MD-3 #3465 and MD-4 #3473 now wait only on a dev merge; queued for a fixer once a builder slot frees (MD-8, MD-10, FC-12 running).
- 07:37Z check-in: #3423 and #3460 merged (07:29Z); #3424 lane macOS build 39366318428 still queued since 03:49Z (runner backlog). No new line:library findings. Builders: MD-8, MD-10, FC-12 in their gates; MD-7 #3548 drafted. Fixer for #3465/#3473 dev merge waits for a free slot.
- MD-8 (#3550, head e57f5481): 3 files +59/-11 over MD-7. Taken date is formatted in the view with Date.FormatStyle (the Model helper is internal), so snapshot text follows the CI Mac locale; critics should check. Adds identifier library.metadata.camera.none. PNGs: library-camera{,-mixed,-none}-{light,dark}.png. MD-b slice code complete once the stack merges.
- 07:59Z check-in: #3424 still open, mergeable clean; lane macOS build 39366318428 still queued (4h10m, runner backlog). No new line:library findings. Running: MD-10 (gate), MD-11 (building on MD-9), fixer for #3465/#3473. Drafts recorded: MD-8 #3550, FC-12 #3551.
- 08:05Z: fixer merged dev into #3465 (CI: PASS on 2nd run) and #3473 (only LibraryCatalogBudgetTests/LibraryGridBudgetTests failed under load; both pass alone, so Fast-Check: pass kept, noted in the body); both un-drafted. Both edit the same C4 description in library-model-sources.json. MD-12 builder launched (feat/library-md12-metadata-persist on MD-9).
- MD-12 (#3569, head 7875f7da): 3 files, +74/-5. Mutate 4/4 on LibraryModel.LiveCatalogCoding. Private optional-field Camera record in LiveCatalogCoding (CameraDetails stays non-Codable); nil keys omitted, golden catalog-v1 byte-equal. Gate PASS (grid budget flaked under load, passes alone).
- 08:21Z check-in: #3424 still open (clean; lane macOS build 39366318428 still queued). #3465 and #3473 ready, clean, waiting on their lane macOS builds. New line:library CI findings #3560-#3565 from dev run 39349878829 (develop, export, export presets, inspector-develop unlabeled button): other features' journeys, none in this feature's files. Running: MD-10, MD-11, MD-15.

- MD-11 (#3570, head edf114d0): 4 files, +68/-14. Mutate 5/5 on LibraryModel.MetadataEditing. Trims with CameraDetails.text(_:); edits cullTargets via recordEdit ("Set Title"/"Set Caption"). Also edits LibraryMetadataSlotsTests (drops the setTitle/setCaption inert checks; MD-10 will drop the keyword ones). Unchanged-guard mutation targets LibraryUndoAdapter.swift. Gate PASS on the 5th of 6 runs: only budget tests failed under load (same on the bare MD-9 head). MD-20 builder launched.
- MD-15 (#3574, head ea22073c): 4 files, +119/-23. Mutate 6/6 on LibraryModel.XMPSidecar. Rule 20: reuses XMLText.escaped; moved the shared xmpmeta/rdf head and the Library namespace into XMPSidecar.head/libraryNamespace, ExportSidecar uses them (byte-identical, its tests pass). Gate PASS (grid budget flaked under load, passes alone). MD-16 builder launched.
- MD-20 (#3575, head 7d6665f0): 4 files, +251/-22. Mutate 8/8 on LibraryModel.PhotoSearch (new plan). Gate PASS. Fixed MD-19 test query keyword:sun -> keyword:su (IMG_0020 has Summer); dropped the inert searchSuggestions line from LibraryMetadataSlotsTests; camera text built from make+model until MD-6. Rule 20: no existing query parser. MD-17 builder launched in the freed slot.
- Check-in 2026-10-20T08:43Z: #3424, #3465, #3473 still open (clean, fast-lane); #3424 lane macOS build 39366318428 still queued since 03:49Z (macOS runner backlog). No merges to cascade. No new line:library findings since 08:15Z. Running builders: MD-10, MD-16, MD-17.
- MD-17 (#3579, head d6667360): 3 files, +74/-9 vs MD-15. App target, no mutation plan (packet). XMPSidecarWriter: name guard as FakeSidecars, refuses a foreign .xmp (isWrittenByLibrary), Data.write .atomic as CatalogStore. Gate: lints and build pass; grid budget 6.4ms under load, 2.0ms alone. Writer is macOS-only, first compiled by the lane build. No slot candidate now: MD-13 waits on MD-10, MD-21 on filters-collections, FC-14 on three FC drafts.
- Check-in 2026-10-20T09:05Z: no dev merges since 08:40Z; #3424 macOS build 39366318428 still queued (5h15m). #3424, #3465, #3473 open and clean. No new line:library findings. Running: MD-10, MD-16. MD-17 drafted (#3579).
- MD-10 (#3581, head 0850e8b1): 5 files, +271/-34 vs MD-9. Mutate 9/9 on LibraryModel.LibraryKeywords. Gate PASS. Dropped the inert keyword checks from LibraryMetadataSlotsTests. Budget pressure under load led to three speed-ups in LibraryKeywords (index reads, byte table, small hash count); no budget changed; add-to-1000 is 11 ms alone, 19.3 ms in the loaded gate against 20 ms, so it may flake in a lane batch. MD-13 (needs MD-8, MD-10, MD-11, MD-12 on four branches) waits until at least two of those parents merge.
- MD-16 (#3582, head 68addecb): 4 files, +107/-12 vs MD-15. Mutate 12/12 on LibraryModel.XMPSidecar (6 new). Gate PASS, planWithinBudget inside the gate. Reuses SidecarFields, XMPSidecar.encode/path; compares inline (45 ms -> 5-6 ms, budget 10 ms unchanged). Slot test now expects the no-file status. No builder running; no task launchable until parents merge (MD-13, MD-18, MD-21, MD-22, FC-10, FC-14, FC-16 all wait).
- 09:28Z check-in: #3465 MD-3 merged to dev (c4204d5bf). Fixer merging dev into MD-5 #3492 and un-drafting. #3473 MD-4 got needs-rebase (dirty after MD-3): fixer merging dev in, keeping both C4 clauses. No new line:library findings.
- 09:45Z: MD-5 #3492 un-drafted, dev merged in, head 212171a9 (diff vs dev: 4 test files +398); gate pass with LibraryGridBudgetTests rerun alone. MD-4 #3473 fixer still running.
- 09:50Z: MD-4 #3473 dev merged in (C4 library-model-sources kept both clauses), head 7e6638e9, gate pass; needs-rebase dropped by the lane. Waiting on its lane macOS build; then cascade MD-9 #3533, MD-14 #3544, MD-19 #3545.
- 09:51Z check-in: #3473 MD-4 waits on its lane macOS build for 7e6638e9; MD-5 #3492 ready. No new line:library findings in this feature's files (open ones are export journeys and #3565, not ours).
- 10:13Z check-in: MD-4 #3473 and MD-5 #3492 still open, waiting on lane macOS builds. #3580 moved the library timed budget tests to the perf list, so the gate no longer runs them. No new line:library findings.
- 10:36Z check-in: nothing merged; #3461/#3473/#3492 waiting on lane macOS builds (#3473 run 39405314225); no new findings.
- 10:57Z check-in: nothing merged; #3461/#3473/#3492 still waiting on lane macOS builds; no new line:library findings.
- 11:20Z check-in: nothing merged yet; #3473 macOS build green (run 39405314225, 11:03Z), awaiting lane sweep; #3461/#3492 still on their builds; no new findings.
- 11:38Z: MD-5 #3492 merged (ebe7e010b). Fixer started on MD-6 #3547: merge dev in, scripts/ci --changed, Head:, un-draft. #3473 MD-4 build green, awaiting lane merge.
- 11:50Z: MD-6 #3547 un-drafted, dev merged in (head 5b7a0a2d, 3 files +130/-26, CI: PASS, mutate 8/8); waits on lane macOS build. Next when MD-6 merges: MD-7 #3548, then MD-8 #3550.
- 12:01Z check-in: no new merges (dev unchanged since MD-5); #3473 clean with green macOS build, awaiting lane sweep; #3461 and #3547 on their builds; no new findings.
- 12:24Z check-in: no dev merges since 11:20Z; lane runs active (batching); #3473 clean+green awaits merge; #3461, #3547 on builds; no new findings.
- 12:47Z MD-4 #3473 merged (92976e6ac); MD-a PRs all on dev, Belt-Slice-Done waits on a green library run containing it. Fixers started: MD-9 #3533, MD-14 #3544, MD-19 #3545 (merge dev in, CI, un-draft). MD-6 #3547 waits on lane macOS build.
- 13:08Z MD-9 #3533 un-drafted, head aee295fb, 6 files +397 tests only, CI PASS (no mutate plan; tests only). Next on MD-9 merge: MD-12 #3569, MD-11 #3570, MD-10 #3581.
- 13:09Z MD-14 #3544 un-drafted, head dbe65695, 5 files +398 tests only, CI PASS. Next on MD-14 merge: MD-15 #3574.
- 13:10Z MD-19 #3545 un-drafted, head 3675867a, 4 files +343 tests only, CI PASS. Next on MD-19 merge: MD-20 #3575. Ready, waiting on lane: MD-6 #3547, MD-9 #3533, MD-14 #3544, MD-19 #3545.
- 13:12Z MD-6 #3547 merged (0b28402fd). Fixer started for MD-7 #3548 (conflicting; merge dev in, un-draft). Ready on lane: MD-9 #3533, MD-14 #3544, MD-19 #3545. No library-scoped CI run on dev yet since MD-4 (dev runs queued); MD-a Belt-Slice-Done waits. No new line:library findings.
- 13:20Z MD-7 #3548 un-drafted, head 6234b33c, 2 files +18/-9, CI PASS (app code; macOS build is first compile). Next on MD-7 merge: MD-8 #3550.
- 13:32Z check-in: no new Library merges (dev f729e9061); MD-7 #3548, MD-9 #3533, MD-14 #3544, MD-19 #3545 ready, waiting on the lane's macOS build. Scoped library run 39424958645 (on 897ccbb2, contains 92976e6ac) still queued, so MD-a not done yet. No new line:library findings. No agents running.
- 13:55Z check-in: no new Library merges. MD-7/9/14/19 waiting on the lane's macOS builds (runs 39430376509, 39428773309, 39428823658, 39428854906). Scoped library run 39424958645 still queued; MD-a not done yet. No new findings.
- 14:25Z MD-9 #3533 merged (56e73319f). Fixers started for its stack: MD-10 #3581, MD-11 #3570, MD-12 #3569 (merge dev, CI --changed, un-draft). MD-7 #3548, MD-14 #3544, MD-19 #3545 still waiting on their macOS builds. Scoped library run 39424958645 (contains MD-4 92976e6ac) still queued since 12:46Z, so MD-a is not done yet. No new findings from this feature.
- 14:42Z MD-14 #3544 merged (9f880c85c). MD-15 #3574 fixer prompt ready, held until a slot frees (MD-10/11/12 fixers still running ci --changed; they have not pushed yet). MD-7 #3548 and MD-19 #3545 still waiting on macOS builds; scoped library run 39424958645 still queued (the macOS runners are backed up). No new findings.
- 14:50Z MD-12 #3569 fixer done: dev merged in, head 605109a5, 3 files +74/-5, CI --changed PASS (737), Mutate LiveCatalogCoding 4/4, now ready (not draft). MD-15 #3574 fixer started in the freed slot.
- 14:52Z MD-11 #3570 fixer done: dev merged in, head d0f67329, 4 files +68/-14, CI --changed PASS (738), Mutate MetadataEditing 5/5, now ready (not draft). Still running: MD-10 #3581 and MD-15 #3574 fixers.
- 14:58Z MD-10 #3581 fixer: dev merged in, head 09c9d63e (5 files +271/-34), but the gate failed 3/3 only on the keyword budget tests (suggestWithinBudget, addToThousandWithinBudget; 20 ms budget, pass alone at 16.7/12.6 ms). Stays draft with Head on the old sha. Blocked on the supervisor adding LibraryKeywordBudgetTests to Tests/perf-suites.txt (asked on #3520 again). Once that is on dev: rerun the gate, move Head, un-draft. Running: MD-15 #3574 fixer.
- 15:00Z MD-15 #3574 fixer done: dev merged in, head db8c6c3a, 4 files +119/-23, CI --changed PASS (737), Mutate XMPSidecar 6/6, now ready (not draft). No fixers running.
- 15:08Z check-in: MD-7 #3548 macOS build 39430376509 green, PR clean; it merges on the next lane sweep, then MD-8 #3550 un-drafts. Lane builds dispatched for MD-11 (39444181939), MD-12 (39444148786) and MD-15 (39444216232). MD-19 build 39428854906 still queued. MD-10 #3581 still waits on #3520 (no budget lines on dev yet). Scoped library run 39424958645 still queued, so MD-a is not done. Open library findings: none from this feature. No fixers running.
- 15:28Z check-in: MD-7 #3548 merged to dev as 7e36d64db. Started the MD-8 #3550 fixer (merge dev, gate, un-draft). Builds for MD-11/12/15/19 not finished; no needs-fix comments. MD-10 still waits on #3520 (no keyword budget line on dev). Scoped library run 39424958645 still queued; MD-a not done.
- 15:37Z MD-8 #3550 fixer done: merged dev, head 23ae41b3, 3 files +59/-11, scripts/ci --changed PASS, PR ready (not draft). Waits on its lane macOS build; MD-b closes after it merges and a green library run. Worktree removed; no fixers running.
- 15:50Z check-in: no new library merges since MD-7 7e36d64db. No needs-fix or needs-rebase labels on this run's PRs. MD-8 #3550: the lane dispatched macOS build 39450013937. Scoped run 39424958645 still queued, so MD-a is not done. perf-suites.txt has no keyword or filter lines yet (#3520), so MD-10 #3581 stays draft. The supervisor's UI review filed findings #3631-#3640. #3637's Camera half maps to MD-8 #3550 (commented). No fixers running.
- 16:14Z check-in: no library merges (dev gained only #3642 and #3630). No needs-fix or needs-rebase labels. Lane macOS builds are still queued (MD-8 39450013937; earlier builds for #3545, #3461, #3570, #3569 and #3574). Scoped run 39424958645 is still queued, so MD-a is not done. perf-suites.txt has no lines for #3520 yet, so MD-10 #3581 stays draft. No fixers running.
