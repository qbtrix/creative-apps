# loupe-viewport lead record

Issue: #1513 · Packet: docs/blueprints/library/features/loupe-viewport.md
Run: act-1a14fc0ecee-9q8k (resumes act-1a14cdfa655-jrmy) · Session: see Belt run page · Started: 2026-10-18T02:45Z
Stage: 5 fix round 1 (fix PRs in the lane)
Base: origin/dev 21066130 (wave 2)
Next: waiting on full dev CI 39171756438 (349578b, has #2878): Linux green, macOS job started 23:24Z. Prior full run 39160459432 void (hung in AfterGlowHomeSidebarTests, line:suite). Supervisor: please route that hang to line:suite and dispatch a scoped library run on dev (I can't dispatch). Green: contact sheet. Red: round 2 (the last), then gaps

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| LV-1 | 1 | Zoom: fit, actual, steps, titles | LoupeZoom.swift, LibraryLoupeZoomTests.swift | LibraryLoupeZoomTests | #2571 | merged 04:58Z |
| LV-2 | 1 | Picture state: focus change, requests, latest wins, failures, neighbours | LibraryLoupeImage.swift, LibraryLoupeImageTests.swift | LibraryLoupeImageTests | #2537 | merged |
| LV-3 | 1 | RenderQueue: one running, the latest waiting | RenderQueue.swift, LibraryRenderQueueTests.swift | LibraryRenderQueueTests | #2535 | merged |
| LV-4 | 1 | Home, End, readout with the name | LoupeState.swift, LibraryLoupeTests.swift | LibraryLoupeTests | #2539 | merged |
| LV-5 | 1 | LiveLoupeImaging: decode, develop, 3-photo cache, prefetch | Live/LiveLoupeImaging.swift, LibraryLiveLoupeTests.swift | LibraryLiveLoupeTests | #2570 | merged 04:58Z |
| LV-6 | 2 | Loupe model budgets | LibraryLoupeBudgetTests.swift | budget tests | #2612 | merged 05:48Z |
| LV-6f | 2 | Focus change without scans (focusChangeWithinBudget red at 1.02 ms) | LibraryLoupeImage.swift, LibraryLoupeImageTests.swift | budget | #2698 | merged 08:48Z (fixes dev-red #2667) |
| LV-7 | 2 | Loupe on CanvasViewport; remove loupeArtboard; snapshots | LibraryLoupe.swift, LoupeState.swift, LibraryLoupeTests.swift, LibraryLoupeSnapshots.swift | snapshots | #2625 | merged 09:20Z (carried LV-6f) |
| LV-8 | 3 | Loupe area: View menu, queue, prefetch, Home and End | LibraryWindow+Loupe.swift | J3 steps 2-5 | #2719 | merged 10:44 |
| LV-9 | 4 | J3 (F) steps | LibraryJourneyTests+Loupe.swift | J3 (F) | #2728 | merged 10:56 |
| LV-10 | 5 | J3 (L) step 1 | LibraryJourneyTests+Loupe.swift | J3 (L) | #2729 | merged 11:54 (feature-done; dev merged in at e2f3f6df, add/add on the Loupe journey file kept LV-10's side); wave.json built |
| LV-11 | – | P4 perf, report-only | LibraryJourneyTests+PerfLoupe.swift | P4 | – | waits #782 (open) |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 39122753293 (scoped library, e3a4582) | red | not reached | journeys, clarity | #2767 (J3 step 3 reads "" after Actual Size, XCUITest #262) | #2859 merged | no |

## Decisions
- 2026-10-18: new run act-1a14cdfa655-jrmy replaces act-1a14698db7e-jmb4; toolchain installed by scripts/cloud-setup.sh (Swift 6.3.3), so the earlier blocker is gone.
- v2 loop: the packet has no Slices table. Rules 10 and 11 apply (#1302 merged before this run): critics file `finding` issues; more than 5 open pauses new feature tasks; at most 2 fix rounds, then open findings become `gap` issues.
- PRs target dev (CLAUDE.md: never branch from or target main), although the brief names main as the integration branch; main moves only by full CI on dev.
- Rule 18 (contract first): every Model signature the UI calls depends only on the spine, so wave 1 builds those signatures for real instead of as throwaway stubs; where a later task fills a method (thumbnails TH-2) wave 1 declares it as a stub. Wave 2 builds the UI on them, alongside the remaining logic.
- Rule 20 (canonical first): searched SuiteModel, SuiteKernel, SuiteUI and every Sources/*Model for zoom steps, an image LRU, a latest-wins render queue and catalog JSON coding; none exists, and none is a kernel concept in Tests/canonical-concepts.txt. The new files stay in LibraryModel.
- Perf tasks (P1, P4, P7) wait on #782, which is open; they become `gap` issues if #782 is still open at the finish.
- No `panLoupe`: CanvasViewport owns the scroll; the Model never stores a pan.
- LV-4 and LV-7 both edit LoupeState.swift, so LV-7 waits for LV-4 (one writer per file per wave).

- LV-1 and LV-5 builders stopped before their gate finished in wave 1; finished by follow-up builders on the same branches (lead/loupe-viewport-LV-1, -LV-5).
- Builder branches are lead/<feature>-<id>: a lead/<feature>/<id> ref cannot coexist with the lead/<feature> status branch.
- LV-4 found loupeReadout already on dev (#1661) and tested it instead of adding a second one.

## Open
- Import IM-6 status gates LV-10.
- LV-6 builder: focus change 10.9 ms vs 1 ms debug budget; loupePlace rebuilds sortedItems on every read. LV-6 ships the LoupeState.swift fix with its budget test (same branch).
- LV-9 #2728: shot `loupe-open` (not `loupe`: an older test owns it); pan check accepts 200 pt or 200/backing scale (scroll unit is the pixel), reverses if the runner's scroll direction is natural. LV-10 #2729: live run on writeShoot files, no slow sub-step live.
- LV-8 #2719: lead fix on review: opening the loupe on the grid's focused photo never rendered (only focusedItemID changes triggered); added onChange(of: model.mode). Anatomy candidates: fitScale not observed (zoom menu enabled state can lag a resize); render long side is the screen's, not full resolution past fit.
- LV-7 #2625: also edits LibraryBrowser.swift (call site passed photo and position, not model and menu, against the packet's note) and LibraryLoupeGridButtonTests.swift (new init). No panned snapshot: CanvasViewport owns its scroll; J3 step 4 drives the pan. The app shows the placeholder until LV-8 feeds renders. docs/blueprints/library.md line 45 still names the fixed 4032 × 3024 board; left for the finish (no task edits a blueprint).
- LV-7 (#2625) needs-rebase: LV-6 and LV-7 both added `Tests/mutations/LibraryModel.LoupeState.json`. The fixer merged dev in and kept all 7 mutations; mutate caught 7/7 and the gate passed. Head is now 9f548842.
