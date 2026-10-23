# shared-thumbnails lead record

Issue: #3719 · Packet: docs/blueprints/suiteui/features/shared-thumbnails.md
Run: act-1a16953ae34-05a4 (relaunch) · Started: 2026-10-23T15:30Z
Stage: 3 wave 1 (ST-a: ST-1 + ST-2)
Base: 721168a8f (origin/dev; brief main cb79cbb6 verified)
Next: ST-a builder on lead/shared-thumbnails-ST-a (off dev): test-first commit (ST-1), then contract, fake, stubs and the CoreAsset links (ST-2). Protected Package.swift and project.yml, so the PR goes to the supervisor, no fast-lane label.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| ST-a | SuiteShell and LibraryModel link CoreAsset; `ThumbnailPublishing.preview(for:)`; `FakeThumbnails`; `ThumbnailWriter` and `LiveThumbnailStoreAdapter` stubs; tests written, disabled | ST-1, ST-2 | MJ-ST | shared-codecs:SC-a (ST-2) | false | 0 | building | – | – |
| ST-u | home Recent cards show `preview(for:)` on the fake, app mark when nil, within the render budget | ST-3, ST-4 | HJ-ST | ST-a | true | 0 | planned | – | – |
| ST-m | writer stores and reads previews in `AfterGlow/Thumbnails/` within budget; Library reads disk before decoding | ST-5, ST-6 | MJ-ST | ST-a; adopt-kernel-autosave:AK-a (ST-5); library spine (ST-6) | false | 0 | planned | – | – |
| ST-z | slot live, Photo publishes on save, Library over the shared store, feature built | ST-7, ST-8 | HJ-ST, MJ-ST | ST-u, ST-m; adopt-kernel-autosave:AK-photo (ST-7) | true | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| ST-1 | ST-a | 1 | tests first, disabled; RJ-X47 job folder | Tests/AppSnapshotTests/ThumbnailWriterTests.swift, Tests/LibraryModelTests/LibraryThumbnailDiskTests.swift, Tests/RealJobs/library/relaunch-grid/relaunch-grid.jobs.json | (disabled) | – | building |
| ST-2 | ST-a | 1 | CoreAsset links; preview(for:); FakeThumbnails; writer and adapter stubs | Package.swift, project.yml, Sources/SuiteModel/Contracts/ThumbnailPublishing.swift, Sources/SuiteModel/Fakes/FakeThumbnails.swift, Sources/SuiteShell/ThumbnailWriter.swift, Sources/LibraryModel/Live/LiveThumbnailStoreAdapter.swift | FakeThumbnails test | – | building |
| ST-3 | ST-u | 2 | home previews on the fake | Sources/AfterGlowApp/HomeGrid.swift, Tests/AppSnapshotTests/HomeGridPreviewTests.swift | HomeGridPreviewTests | – | planned |
| ST-4 | ST-u | 3 | snapshots, render budget, journey skipped | Tests/AppSnapshotTests/HomePreviewSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHomePreviewTests.swift, UITests/AfterGlowJourneyTests+Previews.swift | RenderBudgetHomePreviewTests | – | planned |
| ST-5 | ST-m | 2 | ThumbnailWriter body | Sources/SuiteShell/ThumbnailWriter.swift, Tests/AppSnapshotTests/ThumbnailWriterTests.swift, Tests/mutations/SuiteShell.ThumbnailWriter.json | ThumbnailWriterTests | – | planned |
| ST-6 | ST-m | 2 | Library disk tier | see packet | LibraryThumbnailDiskTests | – | planned |
| ST-7 | ST-z | 4 | live wiring | see packet | PhotoPublishesPreviewTests | – | planned |
| ST-8 | ST-z | 5 | journey live, built, feature-done | see packet | journey | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-23T15:30Z Relaunch act-1a16953ae34-05a4. The supervisor unparked this feature under contract-first waits (#3719 15:12Z; lead.md rule 12, #4814). SC-a's SC-1 is on dev (#4020) but SC-2 is not, so ST-2 builds ahead of it with a Wire line. AK-a is done (run 39568091135), so ST-5's wait is met with real code.
- ST-1 and ST-2 ship as one slice PR (test-first commit, then ST-2): ST-1's tests name types only ST-2 declares.
- ST-2 edits protected Package.swift and project.yml. The supervisor said on #3719 (2026-10-21) that they will land it, so the ST-a PR carries no fast-lane label.
- PRs target `dev` (CLAUDE.md; the lane retargets PRs to main), not main.
- Earlier runs (act-1a15b69feea-et92) were all blocked on SC-a; their heartbeat log is in RECORD.prev.

## Wire
- [x] Wire: shared-codecs:SC-a (ST-2 built ahead; when SC-2 merges, merge dev into the ST-a branch, keeping both Package.swift/project.yml link changes)
- [ ] Wire: Library live services build LiveThumbnails with the disk store (folder + budget); then un-pend RealJobs relaunch-grid. Do in ST-z or a follow-up before close.

## Open
- –
- 2026-10-23T15:20:44Z: ST-a builder started (ST-1 test commit, ST-2) on lead/shared-thumbnails-ST-a; pinned core 7966e5a has CoreAsset/ThumbnailStore, so ST-2 links without a bump
- 2026-10-23T17:32Z: wave 2: ST-a is #4840 (touches Package.swift, so it needs a supervisor merge; no-fast-lane added). ST-u and ST-m builders started, stacked on ST-a, opened as drafts. Decision: ST-6 is built now (two-line call in spine's LiveThumbnails.swift, which spine hasn't edited in 12h; the lane integrates conflicts).
- 2026-10-23T19:15:35Z: SC-2 merged on dev; merged dev into ST-a (#4840) at 07c11358c, SuiteShell keeps CoreAsset + CoreRaster; scripts/ci --changed PASS (6039). Head line moved; asked supervisor to re-gate. Restacking ST-u/ST-m.
- 2026-10-23T19:36:47Z: ST-u (#4950) restacked on ST-a 07c11358c -> 5b8f875, CI --changed PASS, Head moved. ST-m gate running. #4840 still needs-fix pending supervisor re-gate.
- 2026-10-23T19:40:02Z: ST-m (#4951) restacked on ST-a 07c11358c -> 06dfc0e, CI --changed PASS, Head moved. Both drafts wait on #4840.
