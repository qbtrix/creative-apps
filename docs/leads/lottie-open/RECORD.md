# lottie-open (Flare) lead record

Issue: #3791 · Packet: docs/blueprints/flare/features/lottie-open.md
Run: act-1a16c619006-nour (took over from act-1a166b69fab-fd09) · Session: claude/feature-lead-export-pack-rpvio0 · Started: 2026-10-21T10:50Z (this run 2026-10-24)
Stage: 4 fix round 1
Base: e055e6713e4e852d6c19d98f7c2fd82c6758e67a
Next: (2026-10-24 08:25Z) All four slices have Belt-Slice-Done (LO-z on full run 40037716897). Fix round 1: PR #5036 (Fixes #4954, Fast-Check pass at 942fcb1c) waits for the lane's next batch (the current one, lane/batch-20261024081307, is #4903-#4952 and bisecting). Then panel on LO-u/LO-z screens from the next flare journeys run, contact sheet (gaps #4709, #4720). Record lives here; lead/flare-lottie-open mirrors lead/lottie-open and docs/leads/flare-lottie-open/RECORD.md points here.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| LO-a | FlareLottieOpen stub, checks disabled, journey skipped, RJ-F12 re-pointed | LO-1, LO-2 | MJ-LO | – | no | 0 | done: run 39620526621 (Linux green at 3f96cd10) | #4031 | merged |
| LO-u | open panel takes JSON, import note, render budget | LO-4, LO-4b | FJ-LO | LO-a, file-flow:FL-m | yes | 0 | done: run 39915272307 | #4708 | Mac-Finish ad60de98 |
| LO-m | open body over LottieImport; CLI open | LO-3, LO-3h | MJ-LO | LO-a, file-flow:FL-m, pen-paths:FP-m | no | 0 | done: run 39934106780 | #4719 | – |
| LO-z | live open + note, journey on, RJ-F12 on; built (feature-done) | LO-5, LO-6 | FJ-LO, MJ-LO | LO-u, LO-m | yes | 1 | done: run 40037716897; finding #4954 in fix round 1 | #4780 | wanted |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| LO-1 | LO-a | 1 | FlareLottieOpen stub; FlareLottieOpenTests disabled; fixtures | Sources/FlareModel/FlareLottieOpen.swift, Tests/FlareModelTests/FlareLottieOpenTests.swift, Tests/FlareModelTests/Fixtures/Lottie/* | compiles, disabled by name | #4031 | merged |
| LO-2 | LO-a | 1 | journey written, skipped; RJ-F12 check re-pointed, disabled | UITests/FlareJourneyTests+LottieOpen.swift, Tests/RealJobs/flare/open-recolour-lottie/open-recolour-lottie.jobs.json | scripts/jobs check (OK) | #4031 | merged |
| LO-4 | LO-u | 2 | panel types, drop routing, import note | Sources/FlareApp/FlareFilePanels.swift, Sources/FlareApp/FlareWindow+File.swift, Sources/FlareApp/FlareImportNote.swift | render budget row | #4708 | merged |
| LO-4b | LO-u | 2 | render budget | Tests/AppSnapshotTests/RenderBudgetFlareLottieOpenTests.swift | openInThreeBodies | #4708 | merged |
| LO-3 | LO-m | 2 | body over LottieImport.document(from:) | Sources/FlareModel/FlareLottieOpen.swift, FlareFiles, FlareHeadless, catalog, flare.txt, plan | FlareLottieOpenTests | #4719 | merged |
| LO-3h | LO-m | 2 | CLI open | Tests/AfterGlowCLITests/FlareLottieOpenCLITests.swift | FlareLottieOpenCLITests | #4719 | merged |
| LO-5 | LO-z | 3 | live wiring, journey on | Sources/FlareApp/FlareWindow+File.swift, UITests/FlareJourneyTests+LottieOpen.swift, jobs.json | FJ-LO | #4780 | merged |
| LO-6 | LO-z | 4 | status built (feature-done) | docs/blueprints/flare/features/lottie-open.wave.json | waves render | #4780 | merged |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-24 run act-1a16c619006-nour: #4954 is the journey matching InspectorNote rows as staticTexts; InspectorNote is one element with children ignored, so the fix matches any descendant by label or value (AfterGlowJourneyTests+Home pattern). Red-triage called it flaky; it was red on its only run, so it is treated as real.
- 2026-10-23T03:07Z run act-1a166b69fab-fd09: PRs base dev (CLAUDE.md) though the brief names main. LO-m stacks on the FP-m branch (catalog owner order).
- 2026-10-23T03:57Z: import.report moves from LO-m to LO-z: it reads LO-u's importNote (#4708), which had not merged when LO-m was built; LO-m didn't copy it.
- 2026-10-23T03:57Z: the skip sentences name the kind and not the layer ("The precomp isn't supported yet and was left out."): FlareCore's ImportReport.skipped at the pin carries no layer names. Naming the layer needs a needs-core change on qbtrix/creative-core, which this run can't reach (repo scope); the captain should file it. Recorded as a gap for the contact sheet.
- 2026-10-23T03:57Z: --in-place over a .json would overwrite the Lottie; the guard is AfterGlowCLICore's (suite), asked in #4720.
- PRs target `dev` (CLAUDE.md, lead.md rule 4), not main.
- One PR per slice (brief).

- RJ-F12 stays as open-recolour-lottie.jobs.pending.json (waits_on LO-5): the .pending name is how the harness skips a job; LO-5 renames it.
- Fixtures live under Tests/FlareModelTests/Fixtures/Lottie/; the wave lists them without the folder (LO-3 reads them there).
- 2026-10-24: this session's GitHub writes get the attribution footer appended on the way out, so PATCHing it out of PR bodies doesn't hold; the lane strips it from the squash commit and waits on nothing for it. Left as is.

## Open
- 2026-10-21T18:42:09Z: no file-flow FL-m PR open; LO-u/LO-m still waiting.
- Core ImportReport.skipped has kind+count, no layer names: the packet sentence naming "Logo" needs a core change. LO-3 test checks kind word + ending; needs-core ask posted to the supervisor on #3791 (issuecomment-6314815070); this session is scoped to creative-apps only.
- Core leaves Document title empty: LO-3 sets it from the file name.
- file-flow FL-m (#3482) far off (waits on FG-m, FS-m, FK-m, PF-m): LO-u, LO-m wait; rule 23 question after 3 identical polls.
