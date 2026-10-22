# file-flow lead record

Issue: #4514 (was #3474) · Packet: docs/blueprints/halo/features/file-flow.md
Run: act-1a16474bd28-v3ht · Session: claude/halo-feature-lead-3yp4w1 · Started: 2026-10-22T16:00Z (took over from earlier runs)
Stage: 3 wave 1 (HF-a building, stacked on PH-u)
Base: 2cc149f57 (origin/dev; the brief says main, CLAUDE.md and the lane use dev)
Next: HF-a PR opens when PH-a #4426 and PH-u (#4437/#4438) merge; HF-u then stacks on HF-a; HF-m waits on HT-m #4415 and PH-m

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| HF-a | adapter stubs; scene adopts suiteApp, Open Recent via SuiteFileCommands, file drop | HF-1, HF-2 | - | transform:HT-a, shape-tools:HS-a, placed-images:PH-u | yes | 0 | blocked | - | - |
| HF-m | adapter bodies, catalog ids, recents imported once, RJ-H42 | HF-3, HF-4 | - | HF-a; gradient-fill:HG-m, autosave-history:HA-m, transform:HT-m, shape-tools:HS-m, stroke-style:HK-m, placed-images:PH-m | no | 0 | blocked | - | - |
| HF-u | snapshots, render budget, journey skipped | HF-5, HF-6 | - | HF-a | yes | 0 | blocked | - | - |
| HF-z | journey live; halo.md, built, feature-done | HF-7, HF-8 | HaloFileFlowJourneyTests | HF-m, HF-u; export-pack:HX-z, placed-images:PH-z | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| HF-1 | HF-a | 1 | adapter stubs | Sources/HaloModel/HaloFileFlow+Kernel.swift, Tests/HaloModelTests/HaloFileFlowTests.swift | compiles; tests disabled | - | blocked |
| HF-2 | HF-a | 2 | scene, File menu, drop | Sources/HaloApp/HaloApp.swift, see packet | HaloFileFlowSnapshots.menu | - | blocked |
| HF-3 | HF-m | 2 | adapter bodies, ids, RJ-H42 | see packet | HaloFileFlowTests | - | blocked |
| HF-4 | HF-m | 2 | window notes opens and saves | Sources/HaloApp/HaloWindow+File.swift, Tests/AppSnapshotTests/HaloFileFlowLiveTests.swift | HaloFileFlowLiveTests | - | blocked |
| HF-5 | HF-u | 3 | snapshots, budget | Tests/AppSnapshotTests/HaloFileFlowSnapshots.swift, Tests/AppSnapshotTests/RenderBudgetHaloFileDropTests.swift | RenderBudgetHaloFileDropTests | - | blocked |
| HF-6 | HF-u | 3 | journey skipped | UITests/HaloJourneyTests+FileFlow.swift | compiles, skipped | - | blocked |
| HF-7 | HF-z | 4 | journey live | UITests/HaloJourneyTests+FileFlow.swift | testOpenRecentAndDrop | - | blocked |
| HF-8 | HF-z | 5 | halo.md, built, feature-done | docs/blueprints/halo.md, docs/blueprints/halo/features/file-flow.wave.json | waves render --dry-run | - | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Record lives on lead/halo-file-flow at docs/leads/halo-file-flow/: lead/file-flow already belongs to the suite file-flow lead (#3480). Other Halo leads use the same lead/halo-<feature> naming.
- Base dev, not main: CLAUDE.md, the fast lane and every other lead target dev.

## Open
- HF-a blocked (2026-10-21T00:13Z): transform:HT-a likely in (#3702 adapter bodies merged), shape-tools:HS-a in review (#3676), placed-images:PH-u not started (PH-a still waiting).
- 2026-10-21T13:42:11Z check-in: still blocked; placed-images is at Stage 0, PH-a waits on HS-a (#3676), HK-a (key-editing) and PL-a.
- 2026-10-22T16:37:55Z: New run act-1a16474bd28-v3ht for #4514. SF-a is on dev 7e9f260 (FileFlowTarget/FileFlowCommands in SuiteKernel/Files, SuiteFileDrop in SuiteShell, SuiteDocumentHost, SuiteDocumentsBridge used by Photo). HT-a and HS-a are merged; PH-u is drafts #4437/#4438 on PH-a #4426.
- 2026-10-22T16:37:55Z: Decision: HF-a builds stacked on lead/halo-placed-images-PH-u2 (shares HaloViewer.swift and HaloFileMenu.swift, PH-u is A/C first), branch lead/halo-file-flow-HF-a; its PR opens after PH-u merges. Halo already has HaloDocumentHost.swift (A-HA-1) and .suiteApp(.halo, host:); HF-1 builds on that rather than adding a second host.
