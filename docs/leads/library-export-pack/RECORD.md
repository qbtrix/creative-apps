# export-pack (Library) lead record

Issue: #3478 · Packet: docs/blueprints/library/features/export-pack.md
Run: act-1a16953af22-wvhu (line lead, line:library) · resumed 2026-10-23 (earlier act-1a15e4969c2-pa6e)
Stage: 3 wave 2 (LX-2 and LX-4 building on the supervisor's stub ruling, #3478 comment 6372282767; started 2026-10-23T18:54:02Z at dev 0d4645bf)
Base: origin/dev 0d4645bf
Next: LX-2 (slice LX-a, with the SuiteUI ExportPick.metadata stub) and LX-4 (slice LX-m, on FakeMetadata) are with builders; then LX-a and LX-m PRs on the lane.
- [ ] Wire: export-pack:XP-3
- [ ] Wire: export-pack:XP-7

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LX-a | options hold a metadata policy (default All but location); the sheet shows the shared Metadata row | LX-1, LX-2 | MX-LX | XP-a; export (built, #1554 closed) | no | 0 | LX-1 #3696 merged 7f3959c; LX-2 #4960 head efabeb8d on the lane | - | - |
| LX-u | snapshots, render budget, journey written | LX-5, LX-6 | LJ-X1 | LX-a | yes | 0 | waiting | - | - |
| LX-m | sidecar drops the policy's tags; writer carries metadata minus them | LX-3, LX-4 | MX-LX | LX-a; XP-6 (merged), XP-7 | yes | 0 | LX-3 merged f1e49054d; LX-4 waits XP-2 + XP-7 | - | - |
| LX-z | live services, journey on, feature-done | LX-7, LX-8 | LJ-X1 | LX-u, LX-m | no | 0 | waiting | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LX-1 | LX-a | 1 | ExportOptions.metadata (default noLocation, old files read it), sidecar xmp(for:metadata:) signature; LibraryExportMetadataTests written, disabled | LibraryContracts.swift, ExportSidecar.swift, LibraryExportMetadataTests.swift | old file reads noLocation | #3696 c6102dd | merged 7f3959c |
| LX-2 | LX-a | - | sheet Metadata row via ExportPick.metadata | LibraryExportSheet.swift | LibraryExportPackSnapshots.metadata | - | waits XP-3 |
| LX-3 | LX-m | 2 | sidecar policy; LiveExporter passes the policy; RJ-L16/RJ-X03 folder; tests on | ExportSidecar.swift, LiveExporter.swift, tests, mutation plans, Tests/RealJobs/library/no-location/ | LibraryExportMetadataTests; Mutate ExportSidecar 7/7, LiveExporter 6/6 | #3699 f1e49054d | merged |
| LX-4 | LX-m | - | JPEGWriter carries metadata via services.metadata | JPEGWriter.swift, LibraryExportMetadataWriteTests.swift | macOS | - | waits XP-2, XP-7 |
| LX-5..LX-8 | | - | see packet | | | - | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- The record lives on lead/export-pack-library at docs/leads/export-pack-library/. lead/export-pack already holds the SuiteUI export-pack lead's record (#3477), and pushing there would overwrite it.
- PRs target dev (CLAUDE.md). main was verified at b3011ab9.
- The `export` wait is met. Library export #1554 is closed and built (#3387 blueprint prose); its wave.json still reads planned.
- LX-1 starts on XP-1 + XP-6 (both merged). It needs only ExportMetadata and ExportRules.dropped. Photo's PX-1 #3678 does the same. LX-2 waits on XP-3's ExportPick.metadata.
- #3638 (finding: move Library's export to the shared sheet) touches LibraryExportSheet.swift, LX-2's file. LX-2 adds the row through the shared ExportPick either way.
- LX-1 widened the contract so LX-3's tests compile: ExportPlan.Item.dropping (default empty) and a JPEG-writer write(source:dropping:) whose default forwards to today's write, so LibraryApp's JPEGWriter waits for LX-4.
- Under None, LX-3 follows ExportRules.dropped(.none).xmp (rule 20), which lists xmp:Rating and xmp:Label, so None drops them. The packet's 'rating and label always stay' holds only for library: fields. Flagged in #3699.
- Photos carry no GPS or serial fields, so the GPS drop is tested on ExportSidecar.kept(_:metadata:) with a tag list.
- Tests/RealJobs/library/no-location/ is deferred until XP-7's input/gps-phone.jpg is on dev (it goes with LX-4).
- Gap: export presets don't store the policy, so applying one resets it to noLocation (noted in #3696). This is a gap for LX-2's follow-up.

- 2026-10-23T18:54:02Z: supervisor (#3478 comment 6372282767): build LX-2 and LX-4 now. The stub goes in SuiteUI, not Library (rule 12: the contract's own module; rule 20: one copy): ExportPick.metadata: ExportMetadata? = nil, field plus default, no UI, tested in SuiteUITests. The LX-2 PR body says XP-3 builds on the stub field. LX-4 builds on FakeMetadata with Wire: export-pack:XP-7; its macOS write tests stay disabled until XP-7.

- 2026-10-23T19:12:34Z: LX-2 (#4960) keeps a Library-drawn Metadata row (SuiteUI ChoiceChips, titles from ExportMetadata, through the sheet's setOptions). Library's sheet is its own Form and never mounts SuiteExportSheet, so XP-4's shared row would never show there and the policy would have no control. When #3638 moves Library to the shared sheet, this row gives way to XP-4's.

## Open
- XP-2 waits on shell-media SM-a; XP-3 waits on tone-controls TC-a and PL-a (SuiteUI lead's record).
- 2026-10-21T11:50:25Z (act-1a15e4969c2-pa6e): re-read dev ded2ca5. No MetadataCarrying (XP-2), no ExportPick.metadata (XP-3), no StillMetadata (XP-7). SuiteUI lead's last poll says SM-a is not on dev. LX-2, LX-4, LX-5/6 and LX-7/8 cannot start. No open findings carry Feature: export-pack.
- 2026-10-23T15:20:48Z: resumed by line lead act-1a16953af22-wvhu. Under contract-first waits (#4814), the XP-a waits are met once XP-a merges. XP-1 and XP-2 are on dev (MetadataCarrying, FakeMetadata), but XP-3 isn't, and no Belt-Slice-Done for XP-a is posted. So LX-2 waits, and LX-4 then builds on FakeMetadata with a Wire line for XP-7. Polling every 10 min.
- 2026-10-23T16:33:31Z: records moved to lead/library-export-pack (docs/leads/library-export-pack/), the branch Belt watches; lead/export-pack-library is retired.
- 2026-10-23T17:32:35Z: poll 3 of 3 identical (XP-a not on dev 35a0b5e7). Per rule 23 asked the supervisor (#3478 comment 6370841659) whether to build on a stub with a Wire line or park.
