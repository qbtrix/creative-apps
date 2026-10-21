# shell-text lead record

Issue: #3725 · Packet: docs/blueprints/suite/features/shell-text.md
Run: act-1a15ef24f0e-t1j1 · Session: cse_01Mv9wxYxE6yTZhCjfP2rdUH · Started: 2026-10-21T14:56Z
Stage: 3 wave A
Base: 3f96cd10c74f0eb4da8641e8fe511a2e5e42a466
Next: ST-a is draft #4135 stacked on #4034 (lead/shell-media-SM-1) per the supervisor's answer on #3725; when #4034 lands, rebase ST-a onto dev and mark it ready

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| ST-a | the text service contract: values, protocols, FakeText, SuiteServices.text slot | ST-1, ST-2 | MJ-ST0 | shell-media:SM-a (ST-1) | no | 0 | pr-open #4135 (draft on #4034) | – | – |
| ST-m | TextSpan/PlacedSpan validation, font fallback rules, FakeText measures by rule | ST-3, ST-6 | MJ-ST1 | ST-a | no | 0 | planned | – | – |
| ST-live | Core Text measuring, font list, glyph rasterizer on the Mac; Halo's rasterizer moves | ST-4, ST-5, ST-7 | MJ-ST2, MJ-ST3 | ST-a (ST-4) | no | 0 | planned | – | – |
| ST-z | slot live, walk on the Mac, shared prose, built | ST-8, ST-9 | MJ-ST4 | ST-m, ST-live | no | 0 | planned | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| ST-1 | ST-a | A | text values and protocols (TextSpan, SpanMetrics, PlacedSpan, FontFace, FontFamily, SuitePoint, TextMeasuring, FontListing, GlyphRasterizing, TextServices) | Sources/SuiteModel/Values/Text.swift and the packet's ST-1 files | SuiteModelTests text values; mutations in SuiteModel.TextValues | #4135 | pr-open |
| ST-2 | ST-a | A | FakeText and the SuiteServices.text slot (pending "text") | packet's ST-2 files | SuiteModelTests FakeText/services | #4135 | pr-open |
| ST-3 | ST-m | B | TextRules.validated | packet's ST-3 files | mutations SuiteModel.TextRules | – | planned |
| ST-6 | ST-m | B | FakeText measure rules | packet's ST-6 files | mutations SuiteModel.FakeText | – | planned |
| ST-4 | ST-live | B | SuiteShell/Text Core Text measuring + C4 part shell-text.json | Sources/SuiteShell/Text/, docs/c4/parts/creative-apps/suite-shell/shell-text.json | packet's ST-4 test | – | planned |
| ST-5 | ST-live | C | font list | packet's ST-5 files | packet's ST-5 test | – | planned |
| ST-7 | ST-live | C | glyph rasterizer; Halo's HaloTextRasterizer moves | packet's ST-7 files | packet's ST-7 test | – | planned |
| ST-8 | ST-z | D | slot live and the walk | packet's ST-8 files | MJ-ST4 | – | planned |
| ST-9 | ST-z | D | shared prose, status built, feature-done | packet's ST-9 files | scripts/waves render --dry-run | – | planned |

Wave plan (one PR per slice; slice PRs stack as drafts): A = ST-a once SM-1 merges; B = ST-m and ST-live's ST-4 in parallel after ST-a merges; C = rest of ST-live; D = ST-z.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- ST-a (#4135, 386 lines, Mutate SuiteModel.TextValues 4/4) adds Text+Rules.swift with pass-through TextRules.validated so the disabled TextRulesTests compile; ST-3 fills the bodies. ST-2's macOS checks (ShellTextMeasureTests, ShellFontListTests, ShellTextDrawTests) move to ST-4/ST-5/ST-7, which own those files. FakeText tracking lands in ST-6.
- Supervisor (#3725, 16:50Z): stack ST-a as a draft on #4034 now; #4034 is on the local Mac gate; once it lands, rebase ST-a onto dev and mark ready.
- Base is origin/dev (3f96cd10c74f0eb4da8641e8fe511a2e5e42a466), not main (0dd23d6, verified as the brief's step one): main is 248 commits behind dev, CLAUDE.md and lead.md target dev, and the lane retargets main PRs to dev.
- ST-1 waits on shell-media SM-1 (#4034: MediaFrame and the SuiteServices files), open with a red Linux check; sample-files runs first meanwhile (contract rule 19).

## Open
- ST-a blocked on shell-media SM-1, PR #4034 (open, Linux check red).
- dev-red #3856 (Photo CommandPathTests, Flare SetLayerParent): not this feature's.
