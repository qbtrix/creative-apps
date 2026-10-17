# render-out lead record

Issue: #1505 · Packet: docs/blueprints/halo/features/render-out.md
Run: act-1a1429c87eb-3ecm · Session: claude/feature-lead-halo-run-ugkm44 · Started: 2026-10-17T00:05Z
Stage: 2 plan (viewer-playback done; #333 status checked below)
Base: 2be6a100 (origin/dev at 2026-10-17T00:05Z)
Next: stage 3 wave 1 (RO-1, RO-2, RO-3 in parallel), once a Swift toolchain can run HaloModelTests here or the supervisor accepts a Linux-only gate for the Model tasks

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| RO-1 | 1 | `HaloRenderRules` (plan, frame loop with cancel and sink errors); `LiveCompositionRendering` | Live/HaloRenderRules.swift, Live/LiveCompositionRendering.swift, HaloRenderPlanTests | HaloRenderPlanTests | – | planned |
| RO-2 | 1 | `renderCurrentFrame`, `renderedFrameStale`, `renderedFrameSummary` | HaloRenderFrame.swift, HaloRenderFrameTests | HaloRenderFrameTests | – | planned |
| RO-3 | 1 | Render job: sheet open/close, `startRender`, progress, cancel, finish | HaloRenderJob.swift, HaloRenderJobTests | HaloRenderJobTests | – | planned |
| RO-4 | 2 | `HaloAvailability+Render.swift` (both commands turn on); HB-12, HB-13 report-only | HaloAvailability+Render.swift, HaloRenderAvailabilityTests, HaloRenderBudgetTests | HaloRenderAvailabilityTests | – | planned |
| RO-5 | 2 | App: `HaloFrameImage`, `HaloRenderedFrameView` replaces the W0 stub; snapshots | Sources/HaloApp/HaloFrameImage.swift, HaloRenderedFrameView.swift, HaloWindow+Render.swift | halo-rendered-frame-*.png | – | planned |
| RO-6 | 3 | `HaloPNGWriter` (PNG sequence, HF-7) | Sources/HaloApp/HaloPNGWriter.swift, HaloPNGWriterTests | HaloPNGWriterTests | – | planned |
| RO-9 | 3 | Journey H-J20 on parented | UITests/HaloJourneyTests+RenderFrame.swift | H-J20 on dev CI | – | planned |
| RO-7 | 4 | `HaloMovieWriter` (H.264 .mp4, HF-8) | Sources/HaloApp/HaloMovieWriter.swift, HaloMovieWriterTests | HaloMovieWriterTests | – | planned |
| RO-8 | 5 | `HaloRenderSheet` (Render… ⇧⌘R) | Sources/HaloApp/HaloRenderSheet.swift, HaloWindow+Render.swift | halo-render-sheet-*.png | – | planned |
| RO-10 | 6 | Journey H-J21; `feature-done` | UITests/HaloJourneyTests+RenderFrame.swift | H-J21 on dev CI | – | planned |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| – | – | – | – | – | – | – | – |

## Decisions
- Stage 2 (2026-10-17): viewer-playback is built on dev (#1035 done), so render-out is unblocked. Packet is v2 (no Slices table): 10 tasks in 6 waves, copied from its Build waves section.
- Stage 0 checked the dependency chain in docs/blueprints/halo/features/waves.md: no task of this packet can start yet, so the lead stops here (contract rule 9 / v2 stage 0.4).

## Open
- No Swift toolchain on this box (`which swift` empty): RO-1 to RO-4 are Model tasks that the Linux gate would test, so wave 1 needs a toolchain or a supervisor decision.
- Blocked on viewer-playback (#1035, not done); #333.
