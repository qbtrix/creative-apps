# thumbnails lead record

Issue: #1506 · Packet: docs/blueprints/library/features/thumbnails.md
Run: act-1a14fc0ecee-9q8k (resumes act-1a14cdfa655-jrmy) · Session: see Belt run page · Started: 2026-10-18T02:45Z
Stage: 5 fix round 1 (fix PRs in the lane)
Base: origin/dev 21066130 (wave 2)
Next: #2859 and #2860 merged; #2878 (also fixes #2766 J1 crash in TaskGroup::offer, #2882 J3 loupe thumbnail) passed its lane macOS build 39151487702 and merges on the next sweep. Scoped library run 39153204776 (c91b146, has #2860, not #2878) is queued; the run after #2878 decides round 1. Green: contact sheet. Red: round 2 (the last), then gaps

## Tasks
| id | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|
| TH-1 | 1 | Buckets, visible requests, tokens, eviction under 128 MB; TH-2's three result methods declared as stubs | LibraryThumbnails.swift, LibraryThumbnailTests.swift | LibraryThumbnailTests | #2536 | merged |
| TH-2 | 2 | Results: stale drops, failures, invalidate | LibraryThumbnails.swift, LibraryThumbnailResultTests.swift | LibraryThumbnailResultTests | #2575 | merged 05:12Z |
| TH-3 | 2 | LiveThumbnails actor, LRU 256 MB | Live/LiveThumbnails.swift, LibraryLiveThumbnailsTests.swift | LibraryLiveThumbnailsTests | #2573 | merged 05:48Z |
| TH-4 | 2 | Grid model budgets | LibraryGridBudgetTests.swift | budget tests | #2643 | merged 10:00 |
| TH-5 | 2 | Cells show images, values, marks, snapshots | LibraryGrid.swift, LibraryThumbnailSnapshots.swift, LibraryGridSnapshots.swift | snapshots | #2574 | merged 05:12Z |
| TH-6 | 2 | Thumbnails area: visible ids to requests | LibraryWindow+Thumbnails.swift | J2 steps 1-2 | #2601 | merged 05:25Z |
| TH-7 | 3 | J2 (F) steps | LibraryJourneyTests+Grid.swift | J2 (F) | #2637 | merged 08:55Z (carried TH-6f) |
| TH-6f | 3 | Grid reports cell size and display scale to cellSizeChanged | LibraryGrid.swift | J2 step 2 | #2644 | closed 09:0xZ, superseded by #2637 |
| TH-8 | 4 | J2 (L) step 1 | LibraryJourneyTests+Grid.swift | J2 (L) | #2708 | merged 10:31 (feature-done) |
| TH-9 | – | P1 perf, report-only | LibraryJourneyTests+PerfGrid.swift | P1 | – | waits #782 (open) |

## Rounds
| round | CI run | CI | audit vs baseline | lenses | confirmed | fixed by | clean |
|---|---|---|---|---|---|---|---|
| 1 | 39122753293 (scoped library, e3a4582) | red | not reached | journeys, clarity | #2749 (J2: every cell stays loading; #2715 batching) | #2878 (in the lane) | no |

## Decisions
- 2026-10-18: new run act-1a14cdfa655-jrmy replaces act-1a14698db7e-jmb4; toolchain installed by scripts/cloud-setup.sh (Swift 6.3.3), so the earlier blocker is gone.
- v2 loop: the packet has no Slices table. Rules 10 and 11 apply (#1302 merged before this run): critics file `finding` issues; more than 5 open pauses new feature tasks; at most 2 fix rounds, then open findings become `gap` issues.
- PRs target dev (CLAUDE.md: never branch from or target main), although the brief names main as the integration branch; main moves only by full CI on dev.
- Rule 18 (contract first): every Model signature the UI calls depends only on the spine, so wave 1 builds those signatures for real instead of as throwaway stubs; where a later task fills a method (thumbnails TH-2) wave 1 declares it as a stub. Wave 2 builds the UI on them, alongside the remaining logic.
- Rule 20 (canonical first): searched SuiteModel, SuiteKernel, SuiteUI and every Sources/*Model for zoom steps, an image LRU, a latest-wins render queue and catalog JSON coding; none exists, and none is a kernel concept in Tests/canonical-concepts.txt. The new files stay in LibraryModel.
- Perf tasks (P1, P4, P7) wait on #782, which is open; they become `gap` issues if #782 is still open at the finish.
- TH-5 and TH-6 start in wave 2 on TH-1's signatures (TH-2's results are stubs until it lands), not after TH-2: rule 18 unchains the UI from the logic.

## Open
- Import IM-6 status gates TH-8 (J2 on written files).
- TH-5 (#2574) notes `cellValue(for:)` is a linear lookup, O(n^2) over the grid on the 10,000-photo fixture; to raise at Anatomy as a perf finding if TH-9 confirms.
- The PR-create tool appends an attribution footer server-side; the lead strips it from every body after opening.
- TH-4 builder: requestThumbnails 4 ms alone, 20 ms under the parallel gate vs 5 ms debug budget; evictThumbnails similar. Cause: full scans of items and order per pass. Fix (id-to-index maps in LibraryThumbnails.swift) ships with the TH-4 test once TH-2 #2575 merges (same file). Budget not loosened.
- TH-6 (#2601) has no own test: it is view wiring only, proven by J2 steps 1-2 that TH-7 adds. Accepted.
- TH-7 (#2637) found that no view calls `cellSizeChanged` (TH-6 left it unwired), so J2 step 2 would fail on dev. Held #2637 off the lane (label removed, comment) and started TH-6f in LibraryGrid.swift; `fast-lane` goes back on #2637 once TH-6f merges. TH-7 step 4 steps Smaller Thumbnails until five cells show: accepted.
- TH-4 (#2643) meets both grid budgets without loosening them: an id-to-index lookup, checked on every use and rebuilt at most once per pass, makes a request O(visible) and eviction O(visible + held). Debug medians: request 6.39 to 0.39 ms, scroll 9.35 to 1.00 ms. Mutations caught 4/4. 14 release-mode budgets in other suites (Library catalog encode/decode, Photo, Halo, Home, Store) went over their limits when every suite ran in parallel; that is outside this feature and noted in the PR body.
- TH-6f (#2644) uses `.onChange(of: [cellSize, scale], initial: true)` and a new model helper, `thumbnailScale(forDisplayScale:)`, which clamps the scale to 1...8 and is tested. #2644 and #2643 both add `Tests/mutations/LibraryModel.LibraryThumbnails.json`; the JSON merge driver or the lane joins them, so I am watching for `needs-rebase`.
