# canvas-marks lead record

Issue: #1512 · Packet: docs/blueprints/suiteui/features/canvas-marks.md
Run: act-1a146cb0013-zu3h · Session: (this session) · Started: 2026-10-16T22:48Z
Stage: 2 plan
Base: 1f55a91db97af4921e3e46c7d66e3dcf91401097
Next: wave 1 blocked. Needs a Swift toolchain (macOS) and a working GitHub connection to open PRs and comment. See Open.

## Slices
Not a v3 packet (no `## Slices` table). v2 loop, contract rule 18 applies.

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CM-1 | 1 | contracts and Fakes | Contracts/CanvasNavigating.swift, Contracts/HandleGeometryProviding.swift, CanvasFakeTests.swift | CanvasFakeTests | – | planned |
| CM-5 | 1 | PathMarks, guide marks | CanvasMarks+Path.swift | CanvasPathMarksTests | – | planned |
| CM-6 | 1 | MotionPathMarks, GhostLayer | CanvasMarks+Motion.swift | CanvasMotionMarksTests | – | planned |
| CM-7 | 1 | CanvasPointMark (closes #706, #737) | CanvasMarks+Points.swift | CanvasPointMarksTests | – | planned |
| CM-8 | 1 | CanvasGrid (closes #530) | CanvasMarks+Grid.swift | CanvasGridTests | – | planned |
| CM-9 | 1 | ruler corner unit (closes #264) | CanvasViewport.swift, Ruler.swift | RulerMarksTests | – | planned |
| CM-10 | 1 | CanvasSurface.fitted | CanvasSurface.swift | CanvasSurfaceTests | – | planned |
| CM-2 | 2 | SuiteHandleGeometry | HandleGeometry.swift | HandleGeometryTests | – | planned |
| CM-3 | 2 | SuiteCanvasNavigating | ZoomMath.swift | ZoomMathTests | – | planned |
| CM-15 | 2 | baselines: motion, ghosts, point, grid | Golden/canvas | CI run actuals | – | planned |
| CM-4 | 3 | SelectionHandles (part of #273) | CanvasMarks+Vector.swift | CanvasMarksTests | – | planned |
| CM-11 | 4 | gallery canvas pages | Gallery/GalleryCanvas.swift | CI gallery | – | planned |
| CM-14 | 4 | baselines: viewport, handles, path | Golden/canvas | CI run actuals | – | planned |
| CM-12 | 5 | journeys SJ9, SJ10, SJ26 | UITests/SuiteJourneyTests+Canvas.swift | journey | – | planned |
| CM-13 | 5 | journeys SJ21, SP2, SP5 | UITests/SuiteJourneyTests+CanvasMarks.swift | journey | – | planned |
| CM-16 | 6 | baselines surface; feature-done | Golden/canvas, docs/blueprints/suiteui.md | CI run | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|
| – | – | – | – | – | – |

## Decisions
- Loop v2: no `## Slices` table in the packet.
- Suite-harness (#778) is `built`, so every wave-2 wait is met at this base.
- The three features own disjoint files, so one combined plan covers them. Per-packet waves merge by index (see the plan in the lead's scratchpad).
- Status channel: RECORD.md and timeline.tsv pushed to lead/canvas-marks at each stage, as the user asked. No PRs opened yet.

## Open
- needs-human: no Swift toolchain in the cloud container (scripts/ci --changed fails at swift build), so Fast-Check cannot be proven and SuiteUI cannot compile here.
- needs-human: gh token is invalid and the GitHub MCP server is disconnected, so no PR or issue comment can be posted from this session.
- Waiting on the supervisor: open the wave-1 PRs (builders, fast-lane label).
- Golden baselines (the last CM/LL/IC baseline tasks) need actuals from a dev CI run. They can't be done in one session.
- No macOS here: SwiftUI tasks are checked by the lane's build-only run and dev CI only.
