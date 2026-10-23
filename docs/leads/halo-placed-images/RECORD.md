# placed-images (Halo) lead record

Issue: #3456 · Packet: docs/blueprints/halo/features/placed-images.md
Run: act-1a163ac7196-3crm (resumed; was act-1a15a9f4eda-rqhh) · Session: cloud · Started: 2026-10-20T18:43Z
Stage: 3 wave 2
Base: 1a518080de143b64a57ee1838c3ef01b775e52e6
Next: PH-a DONE. PH-m DONE. PH-u: #4438 (e76365be) lane macOS build 39875643496, then merge. PH-z: #4649 head 30471d52 (PH-u2 merged in, clean, 2 files +193 vs dev) draft on PH-u2; #4658 head bc63740a (clean) draft on PH-z. Retarget #4649 to dev after #4438 merges; then #4658 with fast-lane+feature-done. Gate note: dev's quarantine has 6 entries expiring 10-23, renewal in supervisor PR #4660. Gap candidates: SVG gradient flat, SVG strokes, no overshoot ease preset.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PH-a | picture fields, draw item copy, PlacedImageTarget stubs, checks and job folders disabled | PH-1, PH-2 | MJ-PH | HG-a (merged #3516), HS-a (merged #3676), HK-a (merged #4336), PL-a (done) | false | 0 | pr-open #4426 | – | – |
| PH-u | Place… and viewer drop on the stubs, viewer draws by cover, inspector rows, snapshots, budget, journey | PH-3, PH-4 | HJ-P1 | PH-a; HG-u, CL-probe, HT-a, HS-a, HK-a all merged | true | 0 | drafts #4437 (u1 PH-3, 384 lines, head 6c7f834d) and #4438 (u2 PH-4, 196 lines, head 6b60d8c6), stacked on PH-a; retarget to dev + fast-lane once #4426 merges | – | – |
| PH-m | render draws the picture inside its outline; place commands one undo step | PH-5, PH-6 | MJ-PH | PH-a; HG-m (built), HA-m (built), HS-m (done), HT-m (HT-6 #4415 open, rebased, Fast-Check blocked by dev-red #3856), HK-m (HK-6 #4400 merged) | false | 0 | waiting | – | – |
| PH-z | live services, journey on live, blueprint, feature-done | PH-7, PH-8 | HJ-P1 | PH-u, PH-m; HG-z (merged #4318) | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PH-1 | PH-a | 1 | solid fields, draw item copy, conformance and drawing stubs; HaloPlaceTests disabled | HaloLayer.swift, Contracts/HaloDocumentValues.swift, HaloPlace+Kernel.swift, Live/HaloPlacedDrawing.swift, HaloPlaceTests.swift | fixtures round-trip byte-equal; duplicate keeps picture | #4426 | open |
| PH-2 | PH-a | 1 | HaloPlaceRenderTests disabled; RJ-H36, RJ-H02 job folders waits_on PH-5 | HaloPlaceRenderTests.swift, Tests/RealJobs/halo/place-logo/, logo-reveal/ | compiles, disabled | #4426 | open (same PR as PH-1, rule 22) |
| PH-3 | PH-u | 2 | Place…, drop, ⌥-drag focus, viewer draws, inspector rows | HaloApp: HaloPlace, HaloFileMenu, HaloViewer, HaloViewerCanvas, HaloPlaceInspector, HaloLayerInspector, HaloWindow+Viewer | HaloPlaceSnapshots.logo | #4437 | draft |
| PH-4 | PH-u | 2 | render budget, journey skipped | RenderBudgetHaloPlaceTests, UITests/HaloJourneyTests+Place | budget | #4438 | draft |
| PH-5 | PH-m | 2 | render path draws the picture | HaloDrawRules, HaloPlacedDrawing, LiveFrameRendering, HaloPlaceRenderTests, mutations, jobs | HaloPlaceRenderTests | – | waiting |
| PH-6 | PH-m | 2 | conformance bodies, catalog specs | HaloPlace+Kernel, HaloCommandCatalog, command-ids/halo.txt, HaloPlaceTests, mutations | HaloPlaceTests | – | waiting |
| PH-7 | PH-z | 3 | journey on live | UITests/HaloJourneyTests+Place | testPlaceLogo | – | waiting |
| PH-8 | PH-z | 4 | halo.md, status built, feature-done | halo.md, placed-images.wave.json | waves render | – | waiting |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch is lead/halo-placed-images: lead/placed-images belongs to the suiteui lead.
- PRs target dev, not main: the brief says main, but CLAUDE.md says never target main and main only takes dev SHAs that passed full CI (main is 487 commits behind dev). Slice-done reads dev runs.
- PH-1 and PH-2 ship as one PH-a slice PR (rule 22); PH-5+PH-6 likewise.
- PH-u splits into two stacked PRs (PH-3 with snapshots, PH-4 budget+journey): one PR was 568 lines, over the 400 cap. PH-u also wires HaloWindow's haloPlace so Place isn't a dead control.

## Open
- dev Linux red (#3856): HaloStrokeTrimKeysTests from HK-6 #4400, not ours; slice-done needs a green dev Linux run after our last PR, so slice-done waits on the stroke lead's fix, #4431 (open, fast-lane, clean).
- PH-m: re-read transform HT-m (HT-6) and stroke-style HK-m (HK-6) before starting; they share HaloDrawRules/LiveFrameRendering/HaloCommandCatalog.
- 15:10Z lesson: `scripts/ci --changed` on a HaloModel-only diff skips SuiteModelTests' repo-wide ratchets (FormatListRatchetTests); fixers and builders also run `swift test --filter SuiteModelTests` before claiming Fast-Check.
