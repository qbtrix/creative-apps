# export-pack (Library) lead record

Issue: #3478 · Packet: docs/blueprints/library/features/export-pack.md
Run: act-1a15e4969c2-pa6e (resumes act-1a15ac11868-4kb6) · Session: line lead (library: #1563, #3478) · Started: 2026-10-20T19:35Z
Stage: 3 wave 1
Base: origin/dev ded2ca5 (main verified at 0dd23d659f4dbd8a0120aa85a321259327518251)
Next: LX-1 and LX-3 are merged. LX-2 waits on XP-3 (ExportPick.metadata); LX-4 waits on XP-2 + XP-7. Record moved to lead/library-export-pack per Belt.

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

## Open
- XP-2 waits on shell-media SM-a; XP-3 waits on tone-controls TC-a and PL-a (SuiteUI lead's record).
- 2026-10-21T11:50:25Z (act-1a15e4969c2-pa6e): re-read dev ded2ca5. No MetadataCarrying (XP-2), no ExportPick.metadata (XP-3), no StillMetadata (XP-7). SuiteUI lead's last poll says SM-a is not on dev. LX-2, LX-4, LX-5/6 and LX-7/8 cannot start. No open findings carry Feature: export-pack.

- 2026-10-21T15:13:45Z check: Belt nudge; record moved to lead/library-export-pack. XP-2/3/7 still not on dev (no MetadataCarrying/StillMetadata/ExportPick.metadata); LX-2, LX-4 and dependents wait. 0 open findings.
- 2026-10-21T15:36:27Z check: XP-2/3/7 still not on dev; LX-2, LX-4 and dependents wait. 0 open findings.
- 2026-10-21T15:58:40Z check: XP-2/3/7 not on dev; LX-2, LX-4 wait. 0 open findings.
