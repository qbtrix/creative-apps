# canvas-marks lead record

Issue: #1512 · Packet: docs/blueprints/suiteui/features/canvas-marks.md
Run: act-1a1504abd7d-2wty (line lead with #1344, #1512, #1510; took over from act-1a14d48ae2f-857a)
Stage: CM-16 #3060 merged (b1383770); dev CI 39183169319 at f191be21 pending
Base: 2e27b8db (origin/dev)
Next: when 39183169319 is green: Belt-Contact-Sheet on #1512

## Slices
Not a v3 packet (no `## Slices` table). v2 loop, contract rule 18 applies.

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| CM-1 | 1 | contracts and Fakes | Contracts/CanvasNavigating.swift, Contracts/HandleGeometryProviding.swift, CanvasFakeTests.swift | CanvasFakeTests | #2610 | merged |
| CM-5 | 1 | PathMarks, guide marks | CanvasMarks+Path.swift | CanvasPathMarksTests | #2631 | open |
| CM-6 | 1 | MotionPathMarks, GhostLayer | CanvasMarks+Motion.swift | CanvasMotionMarksTests | #2640 | open |
| CM-7 | 1 | CanvasPointMark (closes #706, #737) | CanvasMarks+Points.swift | CanvasPointMarksTests | #2632 | open |
| CM-8 | 1 | CanvasGrid (closes #530) | CanvasMarks+Grid.swift | CanvasGridTests | #2633 | merged 06:33Z |
| CM-9 | 1 | ruler corner unit (closes #264) | CanvasViewport.swift, Ruler.swift | RulerMarksTests | #2641 | open (unit only; rest is CM-9b) |
| CM-10 | 1 | CanvasSurface.fitted | CanvasSurface.swift | CanvasSurfaceTests | #2642 | open |
| CM-2 | 2 | SuiteHandleGeometry as an adapter onto SuiteKernel BoxMath/HandleHit | HandleGeometry+Kernel.swift | HandleGeometryTests | – | #2752 open (Head 481361b2) |
| CM-3 | 2 | SuiteCanvasNavigating | ZoomMath.swift | ZoomMathTests | #2681 | open, gated |
| CM-15 | 2 | baselines: motion, ghosts, point, grid | Golden/canvas | CI run actuals | – | planned |
| CM-4 | 3 | adopt EK-5's SelectionHandles over the canvas (part of #273) | CanvasMarks+Vector.swift | CanvasMarksTests | – | building (EK-5 #2738 on dev) |
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

- Rule 20 (2026-10-18T04:36Z): handle hit, resize with ⇧, and `SelectionHandles` are editor-kernel concepts: editor-kernel owns `Sources/SuiteKernel/Transform/BoxMath.swift`, `HandleHit.swift` (EK-box: EK-19, EK-20) and `Sources/SuiteUI/SelectionHandles.swift` (EK-5). The only other copy is DesignModel's `DesignRect.resized`. So CM-1 lands `CanvasNavigating` and its Fake only; `HandleGeometryProviding`, CM-2 and CM-4 wait on EK-box and EK-5 and then adapt onto them (no copy). CM-5's guide marks are viewport guides, not the kernel's `SnapGuideMarks`.

- 2026-10-18T05:30Z: wave 1 PRs #2607, #2608 (merged) and #2609, #2610 (open) were opened by the stalled earlier session (Belt-Lead act-1a14d1f3122-r1yb, disconnected since 04:59Z). This run adopts them rather than opening duplicates. A gate push briefly overwrote their heads; they were restored to the exact heads their Head: lines name.

- 2026-10-18T05:43Z: CM-9 shipped the ruler unit only (#2641). Its `canvas-drag` series and the viewport's `.suiteControl` registration split into CM-9b (same files, wave 2, after #2641 merges).

## Open
- Earlier blockers cleared in this run: Swift 6.3.3 is installed via scripts/cloud-setup.sh and scripts/ci passes; PRs and comments go through the GitHub MCP and REST gh api (GraphQL is 403).
- Wave 1 starts after the editor-chrome rescope PR (#2554), with rule 20 checks first (SelectionHandles, Transform and Snap are canonical concepts).
- Golden baselines (CM-14, CM-15, CM-16) need actuals from a dev CI run.
- No macOS here: SwiftUI tasks are checked by the lane's build-only run and dev CI only.
- 2026-10-18T04:35Z: the 03:54Z wave-1 builders of run act-1a14d17c86c-d1qr opened no PR; this run relaunches wave 1 on d3a4f16e, at most 4 builders at a time.
- 2026-10-18T04:36Z: run act-1a14d48ae2f-857a took over; no wave-1 PR existed. Swift 6.3.3 installed; wave 1 relaunched on e01529f4 via build-wave.js, at most 4 builders per batch.
- 2026-10-18T07:31:48Z: CM-9b built on lead/canvas-marks-CM-9b (stacked on CM-9). The probe key is not installed by any host yet; CM-11's gallery page installs it.

- 2026-10-18T09:53Z: CM-9 #2641 got needs-fix from a batch red that was dev's own (LibraryLoupeBudgetTests, fixed by #2698); regating for a new head.

- 2026-10-18T10:07Z: CM-10 (#2642) would fail dev's new view-statics lint (`CanvasSurface.fitted` is an unmarked static on a View). The fix marks it `nonisolated` (2b2dd85d), and the branch is regating. CM-9, CM-3 and CM-9b pass the lint.
- 2026-10-18T10:11Z: CM-10 #2642 gate PASS, Head 041e4d42 (body updated).
- 2026-10-18T11:14Z: CM-9b opened as #2753 (PASS, Head 5d0ec681), fast-lane.
- 2026-10-18T12:14Z: CM-9b #2753 merged. CM-10 #2642 Head e975155d (CGFloat.nan fix, PASS). #2752 CM-2 got needs-rebase on the C4 part; dev was merged in (a42b1660, both descriptions kept) and is gating. CM-4 (SelectionHandlesEditor over EK-5) is built on lead/canvas-marks-CM-4 (78eba6a4, 365 lines). Its PR opens on dev once #2752 merges, to stay under 400 lines.
- 2026-10-18T12:43Z: CM-2 #2752 and CM-10 #2642 merged. CM-4 rebuilt as one commit on dev (24aedccb, 365 lines, 4 files; C4 description re-applied over dev's) and gating. Its PR and the line:design adoption issue follow on PASS.
- 2026-10-18T12:44Z: CM-4 opened as #2780 (PASS, Head 24aedccb), fast-lane; the lane's macOS build is its next check. Gap #2778 covers the frameResize pointers for the handles. Design adoption is filed as #2781 (line:design, part of #273). Next: CM-11's gallery pages, then the goldens CM-14 to CM-16, which need dev CI actuals.
- 2026-10-18T12:57Z: CM-4 #2780 waits on the lane's macOS build. Gap #2784 filed: suiteProbes() records no component series, so every SP journey reads 0 samples. CM-11 (the gallery canvas, canvas-pt, marks, surface and probe pages) is being built on lead/canvas-marks-CM-11, stacked on CM-4; its PR opens on dev once #2780 merges.
- 2026-10-18T12:59Z: CM-11 committed (baee545b, 319 lines, adds GalleryCanvasTests) and gating. CM-12 (SJ9, SJ10, SJ26) and CM-13 (SJ21, SP2, SP5) builders were launched on it. #1939 is still blocked: #1933 has only Belt-Slice-Done: EK-a.
- 2026-10-18T13:03Z: CM-11 gate PASS on baee545b; branch lead/canvas-marks-CM-11 pushed. PR opens once CM-4 #2780 merges (rebuilt on dev, regated).
- 2026-10-18T13:07Z: CM-13 built (3f4c82d2, 199 lines: SJ21 Light+Dark, SP2, SP5 report-only; 0-sample series pass until #2784) and pushed to lead/canvas-marks-CM-13. PR opens after CM-11.
- 2026-10-18T13:13Z: CM-12 built (b05e98a1, 285 lines: SJ9, SJ10 at 100/400 %, SJ26) and pushed to lead/canvas-marks-CM-12. SJ10's 25 % and 400 % bottom-right coverage filed as gap #2794. PR opens after CM-11.
- 2026-10-18T13:27Z: CM-4 #2780 merged. CM-11 rebuilt on dev as 7f4983d8, gate PASS, opened as PR #2795 (fast-lane, line:suiteui, body clean). CM-12 and CM-13 open after #2795 merges.

## 2026-10-18T13:56Z stage 4 build
- CM-11 #2795 merged to dev.
- CM-12 and CM-13 were cherry-picked onto dev, gated and opened as #2803 and #2804.
- Next: CM-14, CM-15 and CM-16 (goldens; CM-16 is feature-done) once a dev CI run carries the actuals.
- 2026-10-18T14:19:36Z CM-12: merged #2803. Link fix for #2801 open as #2806; CM-13 #2804 open; CM-14..16 wait on a green run with artifacts after #2806.
- 2026-10-18T14:35:39Z CM-13: merged #2804. CM-14..16 goldens wait on a green run with artifacts after link fix #2806.
- 2026-10-18T14:36:12Z goldens: link fix #2806 merged (624c4291, #2801 closed). Waiting on a dev run including it for actuals.
- 2026-10-18T14:40:32Z goldens: waiting 624c4291. No dev run includes the link fix yet (CI 39135416326 and scoped suiteui 39136389298 are at 650d2985); CM-14..16 wait.
- 2026-10-18T15:02:15Z goldens: waiting 39137279211. CI at 80c14eed includes the link fix and is in progress; CM-14..16 start from its artifacts.
- 2026-10-18T15:24:08Z goldens: waiting 39137279211. Release bundles now build (both runs reached scripts/ui-test): #2801 confirmed fixed. CM-14..16 start from the artifacts.
- 2026-10-18T15:46:09Z goldens: waiting 39137893783. Scoped suiteui at its Findings step, full CI still in journeys (snapshots uploaded); goldens start from ui-screens.
- 2026-10-18T16:13:31Z triage: run 39137893783 triaged (04170953) SJ21 scroll bars unnamed; SJ9 cmd-= reads 100 %
- 2026-10-18T16:13:31Z findings: filed (#2847 #2848) scrollers fix gating; #2848 is cross-line (LibraryCommands Zoom In shortcut), no fix, to the supervisor
- 2026-10-18T16:15:40Z CM-13 fix gating #2847 scrollers fix gating; #2848 with the supervisor; dev CI 39143942767 pending
- 2026-10-18T16:20:27Z fix round 1 PR open #2856 canvas scroll bars hidden (CM-13); gate PASS
