# metadata-more lead record

Issue: #1555 · Packet: docs/blueprints/library/features/metadata-more.md
Run: act-1a15749e510-0ox5 · Session: line lead (library: #1555, #1563) · Started: 2026-10-20T03:00Z
Stage: 3 wave 3
Base: 233aff5cae4aac6b2b273fc39c1ed3b06e967b3f
Next: fixer merges dev into #3460 (MD-1 merged) and un-drafts it; then #3465, #3473, #3492 as their parents merge (each needs dev merged in); then MD-9, MD-14, MD-19 checks, MD-6

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
| MD-2 | MD-a | 2 | sidecar contract, FakeSidecars, services.sidecars | see packet | LibrarySidecarContractTests | #3460 | open, draft until #3422 merges (stacked) |
| MD-3 | MD-a | 3 | cameras fixture; the decoder and importer carry camera details; MD-MJ1 | see packet | LibraryCamerasFixtureTests | #3465 | open, draft until #3460 merges (stacked) |
| MD-4 | MD-a | 3 | inert slots: LibraryKeywords, MetadataEditing title/caption, XMPSidecar, PhotoSearch | see packet | LibraryMetadataSlotsTests | #3473 | open, draft until #3460 merges (stacked) |
| MD-5 | MD-b | 4 | check-first for MD-b: camera rows, decode, snapshots, MD-J1, all disabled | LibraryCameraRowsTests, LibraryCameraDecodeTests, LibraryCameraSnapshots, LibraryJourneyTests+Camera | compiles, disabled | #3492 | draft, stacked on #3465 |
| MD-6 .. MD-22 | MD-b..MD-e | 5+ | see packet Build waves | see packet | see packet | - | planned |

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

## Open
- S-L9 #3413 (InspectorTokenRow) and S-L10 #3414 (InspectorTextRow) are soft waits for MD-13. Until they land, those rows use plain SwiftUI placeholders.
- Open line:library findings checked 2026-10-20T04:42:28Z: none in this feature's files. dev-red #3386 (macOS, range main..1b33afbb) predates these PRs; not ours.
