# export-pack (Library) lead record

Issue: #3478 · Packet: docs/blueprints/library/features/export-pack.md
Run: act-1a170488aff-41nk (line lead, line:library) · resumed 2026-10-24T23:40Z (earlier act-1a16cc967d9-mcuv, act-1a16953af22-wvhu, act-1a15e4969c2-pa6e)
Stage: 3 wave 2; LX-2 #4960, LX-4 #4962, LX-u #5128 on the lane; LX-z: LX-7 #5242, LX-8 #5243 stacked; checked 2026-10-25T01:13:54Z
Base: origin/dev 830af22d
Next: lane merges #4960 then retarget LX-u #5128 to dev; #4962 on lane; LX-z (LX-7 live journey, LX-8 built) after LX-u and LX-m; Wire XP-7 swaps in when #5044 merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LX-a | options hold a metadata policy (default All but location); the sheet shows the shared Metadata row | LX-1, LX-2 | MX-LX | XP-a; export (built, #1554 closed) | no | 0 | LX-1 #3696 merged 7f3959c; LX-2 waits XP-3 | - | - |
| LX-u | snapshots, render budget, journey written | LX-5, LX-6 | LJ-X1 | LX-a | yes | 0 | waiting | - | - |
| LX-m | sidecar drops the policy's tags; writer carries metadata minus them | LX-3, LX-4 | MX-LX | LX-a; XP-6 (merged), XP-7 | yes | 0 | LX-3 merged f1e49054d; LX-4 waits XP-2 + XP-7 | - | - |
| LX-z | live services, journey on, feature-done | LX-7, LX-8 | LJ-X1 | LX-u, LX-m | no | 0 | waiting | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LX-1 | LX-a | 1 | ExportOptions.metadata (default noLocation, old files read it), sidecar xmp(for:metadata:) signature; LibraryExportMetadataTests written, disabled | LibraryContracts.swift, ExportSidecar.swift, LibraryExportMetadataTests.swift | old file reads noLocation | #3696 c6102dd | merged 7f3959c |
| LX-2 | LX-a | 2 | sheet Metadata row + ExportPick.metadata stub (SuiteUI) | LibraryExportSheet.swift, ExportSheet.swift | LibraryExportPackSnapshots.metadata | #4960 | open, fast-lane, Fast-Check efabeb8d |
| LX-3 | LX-m | 2 | sidecar policy; LiveExporter passes the policy; RJ-L16/RJ-X03 folder; tests on | ExportSidecar.swift, LiveExporter.swift, tests, mutation plans, Tests/RealJobs/library/no-location/ | LibraryExportMetadataTests; Mutate ExportSidecar 7/7, LiveExporter 6/6 | #3699 f1e49054d | merged |
| LX-4 | LX-m | 2 | JPEGWriter carries metadata via services.metadata (FakeMetadata) | JPEGWriter.swift, LibraryExportMetadataWriteTests.swift | macOS | #4962 | open, fast-lane |
| LX-5..LX-6 | LX-u | - | see packet | | | #5128 | open |
| LX-7 | LX-z | 4 | journey on | LibraryJourneyTests+ExportPack.swift | LJ-X1 | #5242 | open, stacked on #5128 |
| LX-8 | LX-z | 5 | status built | export-pack.wave.json | waves render | #5243 | open, feature-done, stacked on #5242 |

## Wires
- [ ] Wire: export-pack:XP-3 (LX-2 builds on a stub ExportPick.metadata in SuiteUI, supervisor 2026-10-23 18:46Z; XP-3 builds on that field)
- [ ] Wire: export-pack:XP-7 (LX-4 builds on FakeMetadata; swap in the live copy when XP-7 merges)

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

## Open
- XP-2 waits on shell-media SM-a; XP-3 waits on tone-controls TC-a and PL-a (SuiteUI lead's record).
- 2026-10-21T11:50:25Z (act-1a15e4969c2-pa6e): re-read dev ded2ca5. No MetadataCarrying (XP-2), no ExportPick.metadata (XP-3), no StillMetadata (XP-7). SuiteUI lead's last poll says SM-a is not on dev. LX-2, LX-4, LX-5/6 and LX-7/8 cannot start. No open findings carry Feature: export-pack.
- 2026-10-23T15:20:48Z: resumed by line lead act-1a16953af22-wvhu. Under contract-first waits (#4814), the XP-a waits are met once XP-a merges. XP-1 and XP-2 are on dev (MetadataCarrying, FakeMetadata), but XP-3 isn't, and no Belt-Slice-Done for XP-a is posted. So LX-2 waits, and LX-4 then builds on FakeMetadata with a Wire line for XP-7. Polling every 10 min.

- 2026-10-24T07:25Z: resumed by act-1a16cc967d9-mcuv. Supervisor ruling 2026-10-23 18:46Z: build LX-2 and LX-4 now; add ExportPick.metadata to SuiteUI with a neutral default (field + default, tested, no UI). Library's sheet draws its own Form (not SuiteExportSheet), so LX-2 adds a Metadata row of ChoiceChips over ExportMetadata.allCases with ExportMetadata.title, and maps options.metadata into ExportPick.metadata.

- 2026-10-24T07:48Z: the previous run had already opened #4960 (LX-2, with the stub) and #4962 (LX-4), which the record missed; this run's duplicate builders were stopped before pushing. SuiteUI XP-3 #5043 is stacked on #4960 and builds on its stub, per the ruling.

- 2026-10-24T09:18Z: LX-u (LX-5 render budget metadataPickInTwoBodies, LX-6 journey skipped "waits on LX-7") is PR #5128, head 039c3002, base feat/export-pack-lx2, 3 files +235/-1, Fast-Check pass (build only: no Linux test target covers these). The journey writes its own GPS JPEG because the gps-phone.jpg fixture is LX-3s. macOS-only guesses to watch: export names "gps-phone 2.jpg" and the chip .isSelected trait.

- 2026-10-24T23:43:08Z: resumed by act-1a170488aff-41nk. The brief says to rebase and force-push lead/export-pack; that branch is the SuiteUI export-pack lead's record (#3477) and holds its XP stack, so it is not touched. The Library record stays here on lead/export-pack-library. PRs keep targeting dev: scripts/fast-lane.sh merges only into dev.
