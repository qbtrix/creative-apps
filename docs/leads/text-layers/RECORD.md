# text-layers lead record

Issue: #1509 · Packet: docs/blueprints/halo/features/text-layers.md
Run: act-1a1429c87eb-3ecm · Session: claude/feature-lead-halo-run-ugkm44 · Started: 2026-10-17T00:05Z
Stage: 2 plan (waits met 2026-10-17: #1035 done, #1036 closed 2026-10-15, #1037 built)
Base: 2be6a100 (origin/dev at 2026-10-17T00:05Z)
Next: stage 3 wave 1 (TX-1, TX-2, TX-3, TX-4 in parallel), once a Swift toolchain can run HaloModelTests here or the supervisor accepts a Linux-only gate for the Model tasks

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| TX-1 | 1 | `setText`, `setFontSize`, `endTextSizeScrub`, `sizeText`; edits store the measured box; scrubs coalesced | Sources/HaloModel/HaloTextEdits.swift, Tests/HaloModelTests | TX-1 tests | – | planned |
| TX-2 | 1 | `setLayerColor` ("Change Color") for text, solid and shape; `HaloLayerColor(bytes:)` | Sources/HaloModel/HaloTextEdits+Color.swift, Tests/HaloModelTests/HaloTextColorTests.swift | HaloTextColorTests | – | planned |
| TX-3 | 1 | `HaloAvailability+Text.swift` replaced whole: state-only help | Sources/HaloModel/Availability/HaloAvailability+Text.swift, Tests/HaloModelTests | HaloTextAvailabilityTests | – | planned |
| TX-4 | 1 | `HaloTextRasterizer` on CoreText: `measure` and `rasterize` | Sources/HaloApp/HaloTextRasterizer.swift, Tests/AppSnapshotTests/HaloTextRasterizerTests.swift | HaloTextRasterizerTests | – | planned |
| TX-5 | 2 | HF-10 macOS half: ink inside the stored box; viewer matches `render` | Tests (HF-10 files) | HF-10 tests | – | planned |
| TX-6 | 2 | App: `HaloTextInspector` (TEXT header, TextField, size slider, color row); `HaloWindow+Text.swift` | Sources/HaloApp/HaloTextInspector.swift, HaloWindow+Text.swift | snapshots | – | planned |
| TX-7 | 3 | Journey H-J22 on `-HaloSample empty`; shared-doc edits (C4 part, wave.json); `feature-done`, `Closes #430` | UITests/HaloJourneyTests+Text.swift, docs/c4/parts, text-layers.wave.json | H-J22 on dev CI | – | planned |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| – | – | – | – | – | – | – | – |

## Decisions
- Stage 2 (2026-10-17): plan copied from the packet (7 tasks, 3 waves). Dependencies: #1036 closed 2026-10-15 and #1035 done, so the wait is met; dev's `layer-keys.wave.json` still says "building" and waves.md with it, a stale generated status.
- Stage 0 checked the dependency chain in docs/blueprints/halo/features/waves.md: no task of this packet can start yet, so the lead stops here (contract rule 9 / v2 stage 0.4).

## Open
- No Swift toolchain on this box: TX-1 to TX-4 are Model or Model-adjacent tasks; wave 1 needs a toolchain or a supervisor decision.
- Blocked on layer-keys (#1036, building), viewer-playback (#1035, not done: its feature-done PR #1685 merged, its halo CI not green yet), history-files (#1037, built); #333 (SuiteUI journey files).
