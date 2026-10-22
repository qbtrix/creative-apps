# shell-text lead record

Issue: #3725 · Packet: docs/blueprints/suite/features/shell-text.md
Run: act-1a16278ef53-kw2i (resumed; first run act-1a15ef24f0e-t1j1) · Started: 2026-10-21T14:56Z
Stage: 3 wave D (stacked)
Base: 9f1b3d565fb90acb54c7e3bc734da5f838c7f8dc
Next: #4161 (ST-live2) waits on lane macOS build 39736024768; once merged, retarget #4337 (ST-8) to dev and mark ready, then mark #4350 ready once #4337 merges. #4349 (ST-9 C4 prose) is in the lane. Then Belt-Slice-Done ST-live, ST-z on a green run.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| ST-a | the text service contract: values, protocols, FakeText, SuiteServices.text slot | ST-1, ST-2 | MJ-ST0 | shell-media:SM-a (ST-1) | no | 0 | done (#4135, run 39719146044) | 39719146044 | – |
| ST-m | TextSpan/PlacedSpan validation, font fallback rules, FakeText measures by rule | ST-3, ST-6 | MJ-ST1 | ST-a | no | 0 | done (#4157, run 39728647575) | 39728647575 | – |
| ST-live | Core Text measuring, font list, glyph rasterizer on the Mac; Halo's rasterizer moves | ST-4, ST-5, ST-7 | MJ-ST2, MJ-ST3 | ST-a (ST-4) | no | 0 | building: #4156 merged, #4161 in lane | – | – |
| ST-z | slot live, walk on the Mac, shared prose, built | ST-8, ST-9 | MJ-ST4 | ST-m, ST-live | no | 0 | building: #4337 draft on #4161, #4349 open, #4350 draft | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| ST-1 | ST-a | A | text values and protocols (TextSpan, SpanMetrics, PlacedSpan, FontFace, FontFamily, SuitePoint, TextMeasuring, FontListing, GlyphRasterizing, TextServices) | Sources/SuiteModel/Values/Text.swift and the packet's ST-1 files | SuiteModelTests text values; mutations in SuiteModel.TextValues | #4135 | merged |
| ST-2 | ST-a | A | FakeText and the SuiteServices.text slot (pending "text") | packet's ST-2 files | SuiteModelTests FakeText/services | #4135 | merged |
| ST-3 | ST-m | B | TextRules.validated | packet's ST-3 files | mutations SuiteModel.TextRules | #4157 | merged |
| ST-6 | ST-m | B | FakeText measure rules | packet's ST-6 files | mutations SuiteModel.FakeText | #4157 | merged |
| ST-4 | ST-live | B | SuiteShell/Text Core Text measuring + C4 part shell-text.json | Sources/SuiteShell/Text/, docs/c4/parts/creative-apps/suite-shell/shell-text.json | packet's ST-4 test | #4156 | merged |
| ST-5 | ST-live | C | font list | packet's ST-5 files | packet's ST-5 test | #4161 | pr-open (ready, head 3f297e984) |
| ST-7 | ST-live | C | glyph rasterizer; Halo's HaloTextRasterizer moves | packet's ST-7 files | packet's ST-7 test | #4161 | pr-open (ready, head 3f297e984; Halo swap stays W3 per packet) |
| ST-8 | ST-z | D | slot live and the walk | packet's ST-8 files | MJ-ST4 | #4337 | pr-open (draft on #4161) |
| ST-9 | ST-z | D | shared prose, status built, feature-done | packet's ST-9 files | scripts/waves render --dry-run | – | #4349 open (C4), #4350 draft (built, feature-done) |

Wave plan (one PR per slice; slice PRs stack as drafts): A = ST-a once SM-1 merges; B = ST-m and ST-live's ST-4 in parallel after ST-a merges; C = rest of ST-live; D = ST-z.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- ST-a (#4135, 386 lines, Mutate SuiteModel.TextValues 4/4) adds Text+Rules.swift with pass-through TextRules.validated so the disabled TextRulesTests compile; ST-3 fills the bodies. ST-2's macOS checks (ShellTextMeasureTests, ShellFontListTests, ShellTextDrawTests) move to ST-4/ST-5/ST-7, which own those files. FakeText tracking lands in ST-6.
- Supervisor (#3725, 16:50Z): stack ST-a as a draft on #4034 now; #4034 is on the local Mac gate; once it lands, rebase ST-a onto dev and mark ready.
- Base is origin/dev (3f96cd10c74f0eb4da8641e8fe511a2e5e42a466), not main (0dd23d6, verified as the brief's step one): main is 248 commits behind dev, CLAUDE.md and lead.md target dev, and the lane retargets main PRs to dev.
- ST-1 waits on shell-media SM-1 (#4034: MediaFrame and the SuiteServices files), open with a red Linux check; sample-files runs first meanwhile (contract rule 19).

- 18:45Z: rather than wait on the lane for #4034, wave B starts as drafts stacked on ST-a (contract: next slice stacked as a draft). ST-live splits by the line cap: ST-4 first, ST-5 and ST-7 in a follow-up PR on the same slice.

- ST-9 is two docs-only PRs: scripts/check-c4-descriptions lets an existing part's description change only in a PR whose every path is under docs/c4/parts/, so the C4 prose can't ride with the wave.json status.

## Open
- (none)
- dev-red #3856 (Photo CommandPathTests, Flare SetLayerParent): not this feature's.
- 19:2xZ: ST-7 keeps Halo's HaloTextRasterizer call sites; the packet's "Adopted later" schedules that swap for W3, and it would edit Halo's line.
