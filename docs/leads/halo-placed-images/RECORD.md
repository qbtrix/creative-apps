# placed-images (Halo) lead record

Issue: #3456 · Packet: docs/blueprints/halo/features/placed-images.md
Run: act-1a163ac7196-3crm (resumed; was act-1a15a9f4eda-rqhh) · Session: cloud · Started: 2026-10-20T18:43Z
Stage: 3 wave 1
Base: 1a518080de143b64a57ee1838c3ef01b775e52e6
Next: build PH-a (PH-1 + PH-2, one slice PR to dev); then PH-u (waits only on PH-a) and PH-m (re-read HT-m, HK-m first)

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PH-a | picture fields, draw item copy, PlacedImageTarget stubs, checks and job folders disabled | PH-1, PH-2 | MJ-PH | HG-a (merged #3516), HS-a (merged #3676), HK-a (merged #4336), PL-a (done) | false | 0 | building | – | – |
| PH-u | Place… and viewer drop on the stubs, viewer draws by cover, inspector rows, snapshots, budget, journey | PH-3, PH-4 | HJ-P1 | PH-a; HG-u, CL-probe, HT-a, HS-a, HK-a all merged | true | 0 | waiting (PH-a) | – | – |
| PH-m | render draws the picture inside its outline; place commands one undo step | PH-5, PH-6 | MJ-PH | PH-a; HG-m (built), HA-m (built), HS-m (done), HT-m (HT-6 open), HK-m (HK-5 merged; HK-6?) | false | 0 | waiting | – | – |
| PH-z | live services, journey on live, blueprint, feature-done | PH-7, PH-8 | HJ-P1 | PH-u, PH-m; HG-z (merged #4318) | true | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| PH-1 | PH-a | 1 | solid fields, draw item copy, conformance and drawing stubs; HaloPlaceTests disabled | HaloLayer.swift, Contracts/HaloDocumentValues.swift, HaloPlace+Kernel.swift, Live/HaloPlacedDrawing.swift, HaloPlaceTests.swift | fixtures round-trip byte-equal; duplicate keeps picture | – | building |
| PH-2 | PH-a | 1 | HaloPlaceRenderTests disabled; RJ-H36, RJ-H02 job folders waits_on PH-5 | HaloPlaceRenderTests.swift, Tests/RealJobs/halo/place-logo/, logo-reveal/ | compiles, disabled | – | building (same PR as PH-1, rule 22) |
| PH-3 | PH-u | 2 | Place…, drop, ⌥-drag focus, viewer draws, inspector rows | HaloApp: HaloPlace, HaloFileMenu, HaloViewer, HaloViewerCanvas, HaloPlaceInspector, HaloLayerInspector | HaloPlaceSnapshots.logo | – | waiting |
| PH-4 | PH-u | 2 | snapshots, render budget, journey skipped | HaloPlaceSnapshots, RenderBudgetHaloPlaceTests, UITests/HaloJourneyTests+Place | snapshots, budget | – | waiting |
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
- PH-1 and PH-2 ship as one PH-a slice PR (rule 22); PH-3+PH-4 and PH-5+PH-6 likewise.

## Open
- PH-m: re-read transform HT-m (HT-6) and stroke-style HK-m (HK-6) before starting; they share HaloDrawRules/LiveFrameRendering/HaloCommandCatalog.
