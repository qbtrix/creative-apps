# raw lead record

Issue: #1530 · Packet: docs/blueprints/library/features/raw.md
Run: act-1a15b10caae-y18c · Session: claude/lead-raw-tone-controls-ca9b2k · Started: 2026-10-20T20:48Z
Stage: 0 setup (blocked at 0.4; re-checked at dev 9781100b, 2026-10-20T20:48Z)
Base: 9781100bc432e119320c1bbbff41849ff4aeebdb (origin/dev; brief named main b3011ab9, see Decisions)
Next: wait for suiteui shared-raw SR-a (then RW-1) and shared-codecs SC-f/SC-16 plus library export-pack LX-a (then RW-2); re-run stage 0.4 when any merges

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| RW-a | raw quality per caller, float decode route | RW-1, RW-2 | - | shared-raw:SR-a (RW-1), shared-codecs:SC-f/SC-16 and export-pack:LX-a (RW-2) | no | 0 | blocked | - | - |
| RW-m | thumbnails and grid/loupe/develop through the RAW decoder | RW-3, RW-4 | - | RW-a, export-pack:LX-m, shared-thumbnails:ST-m, suite-imaging:IM-library (RW-3), shared-raw:SR-m, shared-codecs:SC-library (RW-4) | yes | 0 | blocked | - | - |
| RW-z | finish | RW-5, RW-6 | - | RW-m | yes | 0 | blocked | - | - |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| RW-1 | RW-a | - | see raw.wave.json | - | - | - | blocked |
| RW-2 | RW-a | - | see raw.wave.json | - | - | - | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- New run on the re-cut packet (#3685, comment 2026-10-20): slices RW-a/RW-m/RW-z, which replace the old RW-a/RW-b/RW-c cut. The brief listed RW-a, RW-b, RW-c; I follow the packet.
- Base is dev, not main: main b3011ab9 is far behind dev, PRs target dev (the lane retargets main), and the re-cut packet exists only on dev.
- Stage 0.4: no task can start. RW-1's tests use RawQuality, decodeLinear, FakeRawDecoder and PhotoFileKind.cameraRaw, which none of Sources has; shared-raw, shared-codecs, suite-imaging and shared-thumbnails are all `planned` with no issue filed. export-pack LX-a has open PRs (#3696, #3699) but only gates RW-2, which also needs SC-f.

## Open
- Blocked on suiteui shared-raw, shared-codecs, shared-thumbnails, suite-imaging (all planned, "file when ready") and library export-pack (PRs open).
