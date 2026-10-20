# command-catalog lead record

Issue: #2996 · Packet: docs/blueprints/suiteui/features/command-catalog.md
Run: act-1a157b2050f-ovpu (resumed from act-1a1543c764c-0mz9) · Session: claude/feature-lead-suiteui-run-336pic · Started: 2026-10-20T05:08Z
Stage: CC-a, CC-schema, CC-run, CC-lint built; CC-z merged-done (CC-13 a4814ea3), CC-14 waits on CC-u; CC-u open in #3484
Base: b3011ab9dc5579023722e79f83254e6e2520e612 (main); dev 18464f26
Next: #3484 (CC-u: CC-9, CC-10) merges through the lane after its macOS build; then CC-14 with the shared prose; Belt-Slice-Done for CC-u and CC-z on a ci.yml app=suiteui or full run that contains their merges.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| CC-a | `SuiteKernel/Commands` stubs, fake headless document, five `<X>Headless` stubs | CC-1, CC-2 | CJ0 | – | false | 0 | done | 39203617095 | – |
| CC-schema | `ParamSchema` validate and document; `SchemaProbe` | CC-3, CC-4, CC-5 | CJ1 | CC-a | false | 0 | done | 39203617095 | – |
| CC-run | `CommandCatalog` run, batch, ledger, conformance | CC-6, CC-7, CC-8 | CJ2 | CC-a, CC-schema | false | 0 | done | 39221576463 | – |
| CC-u | gallery `command-catalog` page of spec-built menu items | CC-9, CC-10 | SuiteJourneyTests.testCommandCatalogGallery | CC-a, editor-kernel:EK-u | true | 0 | open #3484 (FP-a wait unchained 2026-10-20) | – | – |
| CC-lint | `CommandPathTests` with shrinking baselines | CC-11, CC-12 | CJ3 | CC-a | false | 0 | done | 39203617095 | – |
| CC-z | full Linux walk, shared prose, `status: built` | CC-13, CC-14 | CJ4 | CC-schema, CC-run, CC-u, CC-lint, editor-kernel:EK-z | false | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CC-1 | CC-a | 1 | contract stubs; JSONValue and ParamSchema builders real; C4 part | Sources/SuiteKernel/Commands/*.swift (8), Tests/SuiteKernelTests/CommandShapeTests.swift, docs/c4/parts/creative-apps/suite-kernel/kernel-commands.json | CommandShapeTests | #3056 | merged 252e0c53 |
| CC-2 | CC-a | 2 | FakeCanvasDocument and five Headless stubs | Sources/SuiteKernel/Fakes/FakeCanvasDocument.swift, Sources/*Model/<X>Headless.swift, Tests/SuiteKernelTests/CommandFakeTests.swift | CommandFakeTests | #3074 | merged 20b1c143 |
| CC-3 | CC-schema | 2 | ParamSchemaTests, SchemaProbeTests disabled | Tests/SuiteKernelTests/ParamSchemaTests.swift, Tests/SuiteKernelTests/SchemaProbeTests.swift | ParamSchemaTests, SchemaProbeTests (disabled) | #3072 | merged 17dc84c7 |
| CC-4 | CC-schema | 3 | ParamSchema validate/document bodies, plan | Sources/SuiteKernel/Commands/ParamSchema.swift, Tests/mutations/SuiteKernel.ParamSchema.json | ParamSchemaTests | #3092 | merged 7ea351ba |
| CC-5 | CC-schema | 3 | SchemaProbe recording decoder, plan | Sources/SuiteKernel/Commands/SchemaProbe.swift, Tests/mutations/SuiteKernel.SchemaProbe.json | SchemaProbeTests | #3093 | merged 918abfc6 |
| CC-6 | CC-run | 3 | four catalog test files disabled | Tests/SuiteKernelTests/Command{Catalog,Batch,IDLedger}Tests.swift, CatalogConformanceTests.swift | – | #3101 | merged 9f098e23 |
| CC-7 | CC-run | 4 | CommandCatalog, typed, envelope, batch bodies | Sources/SuiteKernel/Commands/CommandCatalog.swift, CommandSpec.swift, Tests/mutations/SuiteKernel.CommandCatalog.json | CommandCatalogTests, CommandBatchTests | #3120 | merged 9b33f116 |
| CC-8 | CC-run | 4 | ledger and conformance bodies | Sources/SuiteKernel/Commands/CommandIDLedger.swift, CatalogConformance.swift, Tests/mutations/SuiteKernel.CatalogConformance.json | CommandIDLedgerTests, CatalogConformanceTests | #3156 | merged 671c98e7 |
| CC-9 | CC-u | 3+ | MenuCommand(spec:on:), gallery page, snapshots | Sources/SuiteUI/MenuCommand+Catalog.swift, Sources/SuiteUI/Gallery/GalleryCommandCatalog.swift, Sources/SuiteUI/SuiteGallery.swift | MenuCommandCatalogTests | #3484 | open |
| CC-10 | CC-u | 4+ | render budget, journey on | Tests/AppSnapshotTests/RenderBudgetCommandCatalogTests.swift, UITests/SuiteJourneyTests+CommandCatalog.swift | RenderBudgetCommandCatalogTests | #3484 | open (folded into CC-9, 48 lines) |
| CC-11 | CC-lint | 2 | CommandPathTests and baselines | Tests/SuiteKernelTests/CommandPathTests.swift, Tests/command-path-baseline/*.txt | CommandPathTests | #3073 | merged 1f116104 |
| CC-12 | CC-lint | 3 | stale baseline ratchet; lead.md sentence | Tests/SuiteKernelTests/CommandPathTests.swift, docs/factory/lead.md | CommandPathTests.staleBaselineFails | #3102 | merged 1422c727 |
| CC-13 | CC-z | 5 | CommandWalkTests | Tests/SuiteKernelTests/CommandWalkTests.swift | CommandWalkTests | #3182 | merged a4814ea3 |
| CC-14 | CC-z | 6 | shared prose, status built, feature-done | docs/blueprints/suiteui.md, docs/engineering.md, Sources/SuiteKernel/SuiteKernel.swift, command-catalog.wave.json | waves check | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target `dev` (CLAUDE.md, lead contract rule 4); the brief's main 349578b is verified as an ancestor of dev b3283d3.
- Builder branches use the dash form `lead/command-catalog-CC-<n>`, since a slash form can't sit beside `lead/command-catalog`.
- `gh` has no token in this session; PRs, issues and comments go through the GitHub MCP tools.
- `HistoryReading` already exists in `Sources/SuiteKernel/History/History.swift`, so the catalog's `history:` parameter uses it as-is.

## Open
- CC-u waits on font-picker FP-a (planned); editor-kernel is built on dev (#3040), so EK-u is met.
- CC-14: EK-z is met (editor-kernel built #3040).
- Kernel gaps from AC-f1 (#3189): ParamSchema has no oneOf builder; SchemaProbe probes [String: T] as a closed empty object and cannot see flattened owner fields; availability takes no params (dry runs use the example); ids reject capitals. Candidates for gap issues after CC-z.

## Decisions (run act-1a1543c764c-0mz9)
- 2026-10-19T13:01:46Z: Belt lists CC-z done; #2996 has no CC-z Belt-Slice-Done line yet. CC-u is the remaining slice and is blocked on font-picker:FP-a (not started). CC-z's line waits on a run that proves it.

## Decisions (run act-1a157b2050f-ovpu)
- 2026-10-20: unchained CC-9 from font-picker:FP-a. The wait was only file order on `SuiteGallery.swift`; FP-a has no issue, no lead and no PR. The order is reversed instead: FP-a (FP-1) waits on command-catalog:CC-u, and gradient-fill GF-a (GF-2) also waits on FP-a, so GF-2 still lands after both as before (it already waited on FP-a through CC-u). `scripts/waves check`: OK. Packets' prose updated to match. Folded into the CC-9 PR (rule 12: under 50 lines).
- PRs still target `dev`, not `main` as the brief's step list implies: CLAUDE.md and the lane only take crew PRs on dev (a main PR is retargeted).
- 2026-10-20T09:52:24Z: CC-z (CC-14) opened as #3588 (head 14cae3ba, 4 files +29/-4, feature-done); scripts/ci --changed PASS. Belt-Slice-Done for CC-u and CC-z waits on a completed full or app=suiteui run on dev containing #3484 and #3588.
- 2026-10-20T13:16:33Z: CC-u #3484 and CC-z #3588 merged; full CI 39416190119 and 39423713631 cancelled. Waiting on scoped suiteui run 39424969406 (queued, 897ccbb2) for Belt-Slice-Done.

- 2026-10-20T14:18:51Z: Waiting on a successful run: scoped suiteui 39424969406 at 897ccbb2 still queued; full CI 39436941980 at 56e73319 pending.

- 2026-10-20T14:40Z: Full CI 39436941980 cancelled. Full CI 39438701609 at 9f880c85 (contains every slice, incl. 6fa96843) queued; scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:00Z: Full CI 39438701609 (9f880c85) and newer 39442633733 (0dd23d65, also contains every slice) both queued; macOS queue backed up. Scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:21Z: Full CI 39442633733 (0dd23d65), 39438701609 (9f880c85) and newer 39447117246 (27b67332, pending) all contain every slice; none started. Scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:41Z: No full or scoped CI run has completed since 15:21Z; 39447117246 (27b67332), 39442633733, 39438701609 and scoped runs at 897ccbb2 still waiting on macOS runners. Slice lines wait.

- 2026-10-20T16:00Z: Still no completed full or scoped CI run since 15:21Z (only a Linux check at 27b67332 finished). Full runs 39447117246, 39442633733, 39438701609 and scoped runs at 897ccbb2 wait on macOS runners. Slice lines wait.

- 2026-10-20T16:20Z: No completed full or scoped CI run since 15:21Z (only Linux checks at 27b67332 and 47dd9bb8). Full runs 39447117246, 39442633733, 39438701609 and scoped runs at 897ccbb2 still wait on macOS runners. Slice lines wait.

- 2026-10-20T16:40Z: no qualifying run completed; full CI 39447117246 at 27b67332 still pending, 39442633733 and 39438701609 queued; only Linux checks completed (5eceabf7, 47dd9bb8)

- 2026-10-20T17:00Z: no qualifying run completed; full CI 39447117246 at 27b67332 still pending; only a Linux check completed (7b45f176)

- 2026-10-20T17:20Z: full CI 39447117246 at 27b67332 cancelled (replaced); new full CI 39464293440 at 39a1c97e pending, contains every slice; no qualifying run completed yet

- 2026-10-20T17:40Z: full CI 39464293440 at 39a1c97e cancelled (replaced while pending); new full CI 39467874733 at 59fe72db pending, contains every slice; no qualifying run completed yet

- 2026-10-20T18:00Z: full CI 39467874733 at 59fe72db cancelled (replaced while pending); new full CI 39469318877 at d7f615dc pending, contains every slice; no qualifying run completed yet

- 2026-10-20T18:19Z: full CI 39469318877 at d7f615dc still pending (queued since 17:48Z, contains every slice); Linux check 39469631014 at d7f615dc passed (does not count); no qualifying run completed yet

- 2026-10-20T18:39Z: full CI 39469318877 at d7f615dc replaced while pending; new full CI 39475897385 at 875b44d2 pending, contains every slice; no qualifying run completed yet

- 2026-10-20T18:58Z: full CI 39475897385 at 875b44d2 still pending (queued since 18:34Z, contains every slice); Linux check 39476966994 at 875b44d2 passed (does not count); no qualifying run completed yet

- 2026-10-20T19:18Z: full CI 39475897385 at 875b44d2 still pending (contains every slice merge); scoped: suite 39479908321 at a48992b7 queued (suite scope, not suiteui); no qualifying run completed yet

- 2026-10-20T19:38Z: full CI 39475897385 at 875b44d2 still pending (contains every slice merge); latest completed runs are Linux checks only; no qualifying run completed yet

- 2026-10-20T19:58Z: full CI 39475897385 at 875b44d2 cancelled (replaced); new pending full CI 39485502739 at 8c90de14 (contains 875b44d2, so every slice merge); no qualifying run completed yet

- 2026-10-20T20:18Z: full CI 39485502739 at 8c90de14 still pending (contains every slice merge); scoped: design 39490030243 at 014da2f1 pending (would cover AC-design and AT-design); no qualifying run completed yet

- 2026-10-20T20:38Z: no qualifying run yet: full CI 39485502739 (8c90de14) and scoped design 39490030243 (014da2f1) still pending; latest completed runs are Linux checks
