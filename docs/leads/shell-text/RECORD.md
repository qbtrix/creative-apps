# shell-text lead record

Issue: #3725 · Packet: docs/blueprints/suite/features/shell-text.md
Run: act-1a1643afacf-vq3h (wrap-up; earlier runs act-1a15ef24f0e-t1j1, act-1a16278ef53-kw2i) · Started: 2026-10-21T14:56Z
Stage: 3 polling (every task merged; wrap-up)
Base: 18902a68c36c4c6ec07cdc171f68881007f22ca8
Next: wait for a CI run on dev whose Linux job contains 18902a6 (#4431, the Halo trim-keys test fix) and #4350 (817bc5271); on green post Belt-Slice-Done ST-live and ST-z, then Belt-Contact-Sheet. Linux check 39802370482 (3fcea2844) contains every slice PR but is red only on HaloModelTests.HaloStrokeTrimKeysTests (dev-red #3856, line:halo); every text suite passed there.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| ST-a | the text service contract: values, protocols, FakeText, SuiteServices.text slot | ST-1, ST-2 | MJ-ST0 | shell-media:SM-a (ST-1) | no | 0 | done (#4135, run 39719146044) | 39719146044 | – |
| ST-m | TextSpan/PlacedSpan validation, font fallback rules, FakeText measures by rule | ST-3, ST-6 | MJ-ST1 | ST-a | no | 0 | done (#4157, run 39728647575) | 39728647575 | – |
| ST-live | Core Text measuring, font list, glyph rasterizer on the Mac; Halo's rasterizer moves | ST-4, ST-5, ST-7 | MJ-ST2, MJ-ST3 | ST-a (ST-4) | no | 0 | merged: #4156, #4161 (1f58800c4) | – | – |
| ST-z | slot live, walk on the Mac, shared prose, built | ST-8, ST-9 | MJ-ST4 | ST-m, ST-live | no | 0 | merged: #4337, #4349, #4350 (817bc5271, feature-done) | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| ST-1 | ST-a | A | text values and protocols (TextSpan, SpanMetrics, PlacedSpan, FontFace, FontFamily, SuitePoint, TextMeasuring, FontListing, GlyphRasterizing, TextServices) | Sources/SuiteModel/Values/Text.swift and the packet's ST-1 files | SuiteModelTests text values; mutations in SuiteModel.TextValues | #4135 | merged |
| ST-2 | ST-a | A | FakeText and the SuiteServices.text slot (pending "text") | packet's ST-2 files | SuiteModelTests FakeText/services | #4135 | merged |
| ST-3 | ST-m | B | TextRules.validated | packet's ST-3 files | mutations SuiteModel.TextRules | #4157 | merged |
| ST-6 | ST-m | B | FakeText measure rules | packet's ST-6 files | mutations SuiteModel.FakeText | #4157 | merged |
| ST-4 | ST-live | B | SuiteShell/Text Core Text measuring + C4 part shell-text.json | Sources/SuiteShell/Text/, docs/c4/parts/creative-apps/suite-shell/shell-text.json | packet's ST-4 test | #4156 | merged |
| ST-5 | ST-live | C | font list | packet's ST-5 files | packet's ST-5 test | #4161 | merged |
| ST-7 | ST-live | C | glyph rasterizer; Halo's HaloTextRasterizer moves | packet's ST-7 files | packet's ST-7 test | #4161 | merged (Halo swap stays W3 per packet) |
| ST-8 | ST-z | D | slot live and the walk | packet's ST-8 files | MJ-ST4 | #4337 | merged |
| ST-9 | ST-z | D | shared prose, status built, feature-done | packet's ST-9 files | scripts/waves render --dry-run | #4349, #4350 | merged (#4350 feature-done, 817bc5271) |

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
- 15:28Z supervisor: wrap-up against a green dev Linux check that contains the slices; no full macOS run wait.
- Belt watches lead/suite-shell-text; RECORD and timeline now go to both lead/shell-text and lead/suite-shell-text (docs/leads/shell-text and docs/leads/suite-shell-text).
- 08:38Z supervisor: stop polling and end this run; the lane lands the PRs once the macOS runner backlog (32 queued at 08:17Z) clears; the supervisor relaunches the feature for feature-done and the contact sheet.
- dev-red #3856 (Photo CommandPathTests, Flare SetLayerParent): not this feature's.
- 19:2xZ: ST-7 keeps Halo's HaloTextRasterizer call sites; the packet's "Adopted later" schedules that swap for W3, and it would edit Halo's line.
