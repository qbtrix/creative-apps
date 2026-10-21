# placed-images (Halo) lead record

Issue: #3456 · Packet: docs/blueprints/halo/features/placed-images.md
Run: act-1a15a9f4eda-rqhh · Session: session_01SEp2gy695K32UTCMdrBDFC · Started: 2026-10-20T18:43Z
Stage: 0 setup
Base: e382f9d7fba02ffdefc8ba2f23c9461b4774fad6
Next: re-read the waits of PH-a (shape-tools HS-a, key-editing HK-a, suiteui placed-images PL-a) and start PH-a when they clear

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| PH-a | contract: placed layer fields, PlacedImageTarget, HaloPlacedDrawing | see packet | – | gradient-fill:HG-a (done), shape-tools:HS-a, key-editing:HK-a, placed-images(suiteui):PL-a | – | 0 | waiting | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Lead branch is lead/halo-placed-images: lead/placed-images belongs to the suiteui lead.

## Open
- Supervisor (2026-10-21): don't take HS-a; it is #3676 (lead/halo-shape-tools-HS-a), being rebased for the Mac gate. Park placed-images until #3676, HK-a (#3536) and PL-a show Belt-Slice-Done.
- PH-a blocked: HS-a (shape-tools #3445, PR #3676), HK-a (key-editing #3536), PL-a (suiteui placed-images, waiting on PL-2).
