# metadata-more lead record

Issue: #1555 · Packet: docs/blueprints/library/features/metadata-more.md
Run: act-1a15749e510-0ox5 · Session: line lead (library: #1555, #1563) · Started: 2026-10-20T03:00Z
Stage: 3 wave 2
Base: 233aff5cae4aac6b2b273fc39c1ed3b06e967b3f
Next: the wave 2 builder (MD-2, stacked on MD-1) opens its PR; then MD-3 and MD-4 in wave 3

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
| MD-1 | MD-a | 1 | CameraDetails with its cleaning init, CameraField, CameraRow stubs, selectedPhotos, selectedCameraRows; PhotoItem keywords/title/caption/camera; ImportCandidate.camera | Sources/LibraryModel/Contracts/PhotoDetails.swift, Sources/LibraryModel/PhotoItem.swift, Sources/LibraryModel/Contracts/LibraryValues.swift, Tests/LibraryModelTests/LibraryPhotoDetailsTests.swift, Tests/mutations/LibraryModel.PhotoDetails.json, Tests/mutations/LibraryModel.PhotoItem.json | LibraryPhotoDetailsTests | #3422 | open, macOS build queued |
| MD-2 | MD-a | 2 | sidecar contract, FakeSidecars, services.sidecars | see packet | LibrarySidecarContractTests | - | building (stacked on feat/library-md1-photo-details) |
| MD-3 | MD-a | 3 | cameras fixture; the decoder and importer carry camera details; MD-MJ1 | see packet | LibraryCamerasFixtureTests | - | planned |
| MD-4 | MD-a | 3 | inert slots: LibraryKeywords, MetadataEditing title/caption, XMPSidecar, PhotoSearch | see packet | LibraryMetadataSlotsTests | - | planned |
| MD-5 .. MD-22 | MD-b..MD-e | 4+ | see packet Build waves | see packet | see packet | - | planned |

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

## Open
- S-L9 #3413 (InspectorTokenRow) and S-L10 #3414 (InspectorTextRow) are soft waits for MD-13. Until they land, those rows use plain SwiftUI placeholders.
- Open line:library findings: 4, none in this feature's files.
