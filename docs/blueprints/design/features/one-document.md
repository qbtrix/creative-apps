# Feature packet: one-document

**Feature:** One document. Make a UI in Design, animate it, play it, save it and reopen it, all in one document, inside today's Design window, on kernel-owned time.
**Line:** `line:design` (no new line) · **Wave:** 5 · **Integration branch:** `feat/one-document` in `qbtrix/creative-apps`

**Covers:** the one-document staged hero. Source documents in paw-workspace: `docs/design/drafts/2026-10-29-one-document-audit.md` (chunks H0-H20), `docs/design/drafts/2026-10-29-one-document-spike.md` (measured), and the task breakdown `docs/design/drafts/2026-10-29-one-document-hero-tasks.md`, whose slice ids OD-1 to OD-18 this packet uses. OD-1 is this packet; OD-16 to OD-18 are measurement and owed-debt tasks outside the slice table.

**Depends on:** the Design features already on `dev` whose files the slices edit (the `depends` list in `one-document.wave.json`). The branch merges `origin/dev` daily, so it builds on their current state.

Every PR on this branch cites its slice as `Slice: OD-n` and targets `feat/one-document`, never `dev`.

## Decisions (captain, 2026-10-29)

- **Option B, the staged hero, Reading A.** The hero is the vector engine (Design) plus kernel-owned universal time. Flare is not a node in the hero.
- **Built inside Design's window.** No new target, no H0 supervisor gate, no `line:doc`, no new UTType, no new journey bundle.
- **The compositor is deferred** until a second engine needs it. The spike measured painter playback of 500 rectangles at 0 window bodies per frame.
- **Time lives once, top-level on `DesignNode`** (`DesignNode.time: DesignNodeTime?`, boxed in `DesignNodeExtras`), as absolute page values: `frame` and `opacity` are the rest pose, and the keys hold absolute values. Sampling moves a node's subtree by the node's delta, then each child samples its own.
- **LiveFiling version 2 policy** (constraint 10): a still document saves byte for byte as today at version 1; only a document with time writes version 2; a version-1-only reader refuses a version-2 file with `unsupportedVersion(2)` and its one-sentence message, and never opens it with the keys gone.
- **Low priority,** behind the beta bug arc, on the low-priority gate pool.
- **Never lands on `dev`** until the captain decides.

## Global Constraints

These bind every slice, verbatim from the task breakdown.

1. **Branch.** All work lands on `feat/one-document` in `qbtrix/creative-apps`, branched from `origin/dev` on day 0 and pushed as a long-lived integration branch. Slice PRs target `feat/one-document`, never `dev`, so they carry no `fast-lane` label and the lane never sees them. The hero lead merges its own slice PRs into the branch on a green Linux `scripts/ci --changed` plus the slice's Mac proof. Nothing from this branch is PR'd to `dev` until the captain says so.
2. **Daily `git merge origin/dev`, never rebase.** The integration branch merges `origin/dev` once a day (CLAUDE.md "Parallel agents": a PR behind dev merges `origin/dev` into itself, never rebases; `scripts/install-merge-drivers` is run once per clone so `.json` plans and `.wave.json` merge key by key). Slice branches merge `feat/one-document` the same way. Force-push never.
3. **Low-priority gate pool.** Every heavy verify runs as `./scripts/gate --scope creative-apps-onedoc <cmd>` from the workspace root. At most one Mac build from this arc at a time. When `./scripts/gate --status` shows a beta-arc holder waiting, this arc yields: finish the current build, then stop until the queue is clear. Journeys and the budget suites run in off-hours windows. The beta arc always wins the Mac.
4. **PR size caps per lead.md.** One behavior per PR (CLAUDE.md "Rules"): aim for 150-400 changed lines, hard cap 400 lines and 15 files, docs-only PRs uncapped (lead.md rules 4 and 22). The first commit of a slice PR adds its failing test; later commits make it pass (rule 13 and 22). A same-feature change under 50 lines folds into the next slice PR.
5. **Mutation plans.** Every slice that adds behavior adds 2 or more mutations to `Tests/mutations/<Target>.<File>.json` and runs `scripts/mutate --plan <plan>` until each is caught (lead.md rule 14). A `find` string that moves in a refactor is repointed in the same PR, or `scripts/ci` fails its occurs-once check. Plans at risk here: `DesignModel.DesignNode`, `DesignModel.DesignNodeExtras`, `DesignModel.LiveFiling`, `DesignModel.LiveTransforming`, `DesignModel.LiveStyling`, `DesignModel.LiveAligning`, `DesignModel.LiveDuplicating`, `DesignModel.LiveClipboard`, `DesignModel.LiveGrouping`, `DesignModel.LiveFraming`, `DesignModel.LiveMarquee`.
6. **Contract first.** OD-2 freezes the node-time contract (types, sampling, file keys) and merges before any other code slice. Every later task consumes it unchanged; a change to it is its own PR with a conformance-test diff, and reopens OD-3's refusal test.
7. **Canonical first (lead.md rule 20, captain 2026-10-17).** No second copy of an editor concept: one display-link driver (SuiteUI), one timeline family (SuiteUI TimelineStrip, KeyframeButton, TransportCapsule, CurveEditor), one key-rule set (SuiteKernel KeyRules, ColorKeyRules), one playback tick (PlaybackTiming). `scripts/check-dup-logic` and `Tests/canonical-baseline.txt` must not grow; where a task touches a baselined duplicate it shrinks it.
8. **Protected files stay untouched.** `Package.swift`, `Package.resolved`, `project.yml`, `.github/`, `.claude/`, `scripts/`, `UITests/quarantine.json`, the perf and heavy lists, `Bundle/Info/*.plist`. The staged hero needs none of them: no new target, no new UTType, no new journey bundle. If a task finds it needs one, it stops and reports; it does not edit.
9. **Linux first, Mac finish.** Model tasks (DesignModel, SuiteKernel) prove on Linux with `swift test --filter "$(scripts/test-scope design)"`. UI tasks (`Sources/DesignApp`, `Sources/SuiteUI`) are drafted blind and finished on the Mac (CLAUDE.md "You are writing SwiftUI blind", lead.md rule 17), with a render-budget row per UI slice (`Tests/render-budgets.md`) and light and dark snapshots. Journeys are report-only and never hold a merge (rule 6 and 18).
10. **Data safety.** No build may silently drop keys on resave (the 4550/2998/3000 class). A still document saves byte for byte as today at version 1. Only a document with time writes version 2. A version-1-only reader refuses a version-2 file with `unsupportedVersion(2)` and its one-sentence message; it never opens it with the keys gone.
11. **A tick never writes the document.** Playback and scrub show a sampled copy (the HaloLivePlayhead pattern, QB-F3); history, autosave and the saved marker never see a playhead change. The budget is 0 window bodies per playback frame (measured free in the spike) and QB-L4's 2 dropped frames in 5 s.
12. **Writing and hygiene.** `/humanize` on every PR title and body; no AI attribution anywhere, comments included; no competitor names in code; file headers describe the current state, no dated entries; `docs/design.md` for every view; `docs/cli.md` row for every new command id; command ids are append-only in `Tests/command-ids/design.txt`.

## Critical path

**Critical path:** OD-1 → OD-2 → OD-4 → OD-5 → OD-12 → OD-13 → OD-14 → OD-15, about 28 agent-hours serial. OD-10 starts on day 0 beside OD-1 (SuiteUI only). OD-3, OD-6, OD-7, OD-8, OD-9, OD-17 and OD-18 run beside the path.

```
 Model (Linux)                                   UI (Mac)
 ─────────────                                   ────────
 OD-1 ─▶ OD-2 ─┬─▶ OD-3 ──────────────────────────────────┐
               ├─▶ OD-4 ─▶ OD-5 ─┬─▶ OD-6                │
               │                 ├─▶ OD-7                │
               │                 ├─▶ OD-8 ─▶ OD-9 ───────┼──────────┐
               │                 │                       │          │
               │                 └──────────▶ OD-12 ─▶ OD-13 ─▶ OD-14 ─▶ OD-15 ─▶ (feel gate)
               │                                  ▲                 ▲        ▲
 OD-10 ───────────────────────────▶ OD-11 ────────┘─────────────────┘────────┤
               │                        └─▶ OD-16                            │
               └─▶ OD-17 (after OD-9 for the raster path)                    │
 OD-18 (owed debt, any time, report-only budgets) ───────────────────────────┘
```

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on | ui |
|---|---|---|---|---|---|
| OD-2 | `DesignNodeTime` on `DesignNode`, sampled through `DesignPage.sampled(at:)` with easing, with fixtures and a conformance suite, and nothing else changed in the product. | OD-2a, OD-2b | MJ-OD-2 | – | no |
| OD-3 | A document with time saves and reopens with its keys, a still document is unchanged on disk, and an old reader refuses the new file instead of losing keys. | OD-3a, OD-3b | MJ-OD-3 | OD-2 | no |
| OD-4 | With the workspace playhead set, every read of the page (paint, hit-test, handles, snapping, marquee, zoom-to-selection) sees the sampled tree. | OD-4a, OD-4b | MJ-OD-4 | OD-2 | no |
| OD-5 | At a non-zero playhead, moving, nudging, aligning or setting x, y or opacity on a keyed node writes a key at the playhead with the asked-for value. | OD-5a, OD-5b | MJ-OD-5 | OD-4 | no |
| OD-6 | A duplicated or pasted keyed node lands where it was asked and keeps its animation, every x and y key shifted by the same offset. | OD-6a, OD-6b | MJ-OD-6 | OD-5 | no |
| OD-7 | Grouping, ungrouping, framing and reparenting a keyed node leaves it where it shows at the playhead, and its animation still plays. | OD-7a, OD-7b | MJ-OD-7 | OD-5 | no |
| OD-8 | The keyframe and time commands work headless, from the CLI and as MCP tools, with their ids in the ledger. | OD-8a, OD-8b | MJ-OD-8 | OD-5 | no |
| OD-9 | PNG and SVG export take an optional frame and write the page as it shows at that frame. | OD-9a, OD-9b | MJ-OD-9 | OD-8 | no |
| OD-10 | One display-link driver in SuiteUI, which Flare and Halo adopt. | OD-10a, OD-10b | MJ-OD-10 | – | yes |
| OD-11 | Space plays the document in Design's window on the one clock, with 0 window bodies per frame, and nothing is written to history or autosave. | OD-11a, OD-11b | MJ-OD-11 | OD-10, OD-8 | yes |
| OD-12 | The first key slides a timeline in at the bottom of Design's window, one lane per keyed node; scrubbing the ruler moves the playhead; a still document shows no timeline. | OD-12a, OD-12b | MJ-OD-12 | OD-5, OD-11 | yes |
| OD-13 | The X, Y and Opacity inspector rows carry KeyframeButton, an Animate menu lists play, pause, stop and the key commands with shortcuts, and the first key made this way slides the timeline in. | OD-13a, OD-13b | DesignJourneyTests.testFirstKeySlidesTimelineIn | OD-12 | yes |
| OD-14 | In the window, a keyed document saves, closes, reopens and recovers with its keys, and a newer file shows the refusal sentence. | OD-14a, OD-14b | DesignJourneyTests.testSaveReopenKeepsKeys | OD-3, OD-13 | yes |
| OD-15 | One journey does the whole hero (new document, draw, key two nodes, play, save, reopen, play again) and the five render-budget rows that hold it are measured and written. | OD-15a, OD-15b | DesignJourneyTests.testOneDocumentHero | OD-9, OD-11, OD-14 | yes |

Each slice's first task (`a`) is its failing test, the first commit of the slice PR; the second (`b`) makes it pass (rule 22). `MJ-OD-n` is the slice's Linux Model walk: its new test file green on `swift test --filter "$(scripts/test-scope design)"`. The three XCUITest journeys are report-only (rules 6 and 18); the task breakdown names them without the `test` prefix XCTest needs.

OD-2 is the contract slice (rule 12, constraint 6): `DesignNodeTime`, `DesignKeyProperty`, `DesignNode.time`, `DesignNode.sampled(at:)`, `DesignPage.sampled(at:)`, `DesignDocumentTime`, `DesignFixtures.animated(_:)` and `DesignFixtures.keyedCrowd`, frozen once it merges. A change to it is its own PR with a conformance-test diff.

## Owned files

| slice | files |
|---|---|
| OD-2 | `Sources/DesignModel/DesignNodeTime.swift`, `Sources/DesignModel/DesignNode.swift`, `Sources/DesignModel/DesignNodeExtras.swift`, `Sources/DesignModel/DesignFixtures.swift`, `Sources/DesignModel/DesignWorkspace.swift`, `Tests/DesignModelTests/DesignNodeTimeTests.swift`, `Tests/mutations/DesignModel.DesignNodeTime.json`, `Tests/mutations/DesignModel.DesignNode.json`, `Tests/mutations/DesignModel.DesignNodeExtras.json` |
| OD-3 | `Sources/DesignModel/Live/LiveFiling.swift`, `Sources/DesignModel/DesignRecoveryStore+Kernel.swift`, `Sources/DesignModel/DesignRecovery+Kernel.swift`, `Tests/DesignModelTests/LiveFilingVersionTests.swift`, `Tests/DesignModelTests/Fixtures/version-2-keyed.design`, `Tests/DesignModelTests/Fixtures/version-3.design`, `Tests/mutations/DesignModel.LiveFiling.json` |
| OD-4 | `Sources/DesignModel/DesignCanvasEditing.swift`, `Sources/DesignModel/Live/LiveMarquee.swift`, `Sources/DesignModel/DesignSnapGuides+Kernel.swift`, `Tests/DesignModelTests/DesignPlayheadReadTests.swift`, `Tests/mutations/DesignModel.DesignCanvasEditing.json`, `Tests/mutations/DesignModel.LiveMarquee.json`, `Tests/mutations/DesignModel.DesignSnapGuides.json` |
| OD-5 | `Sources/DesignModel/Live/LiveKeying.swift`, `Sources/DesignModel/Live/LiveTransforming.swift`, `Sources/DesignModel/Live/LiveStyling.swift`, `Sources/DesignModel/Live/LiveAligning.swift`, `Tests/DesignModelTests/DesignAutoKeyTests.swift`, `Tests/mutations/DesignModel.LiveKeying.json`, `Tests/mutations/DesignModel.LiveTransforming.json`, `Tests/mutations/DesignModel.LiveStyling.json`, `Tests/mutations/DesignModel.LiveAligning.json` |
| OD-6 | `Sources/DesignModel/Live/LiveDuplicating.swift`, `Sources/DesignModel/Live/LiveClipboard.swift`, `Tests/DesignModelTests/DesignKeyedDuplicateTests.swift`, `Tests/mutations/DesignModel.LiveDuplicating.json`, `Tests/mutations/DesignModel.LiveClipboard.json` |
| OD-7 | `Sources/DesignModel/Live/LiveGrouping.swift`, `Sources/DesignModel/Live/LiveFraming.swift`, `Sources/DesignModel/Live/LiveOrdering.swift`, `Tests/DesignModelTests/DesignKeyedReparentTests.swift`, `Tests/mutations/DesignModel.LiveGrouping.json`, `Tests/mutations/DesignModel.LiveFraming.json` |
| OD-8 | `Sources/DesignModel/DesignCommandCatalog.swift`, `Sources/DesignModel/DesignHeadless.swift`, `Tests/command-ids/design.txt`, `Tests/RealJobs/design/animate-and-check/`, `docs/cli.md`, `Tests/mutations/DesignModel.DesignCommandCatalog.json` |
| OD-9 | `Sources/DesignModel/DesignExport+Kernel.swift`, `Sources/DesignModel/DesignExportOptions.swift`, `Sources/DesignApp/DesignRasterizer.swift`, `Tests/mutations/DesignModel.DesignExportOptions.json` |
| OD-10 | `Sources/SuiteUI/SuitePlaybackDriver.swift`, `Sources/FlareApp/PlaybackDriver.swift`, `Sources/HaloApp/HaloPlaybackDriver.swift`, `Tests/SuiteUITests/SuitePlaybackDriverTests.swift`, `Tests/canonical-baseline.txt`, `Tests/mutations/SuiteUI.SuitePlaybackDriver.json` |
| OD-11 | `Sources/DesignApp/DesignPlayer+Kernel.swift`, `Sources/DesignModel/DesignTransport.swift`, `Tests/DesignModelTests/DesignPlaybackTests.swift`, `Tests/AppSnapshotTests/RenderBudgetDesignAnimateTests.swift`, `Tests/mutations/DesignModel.DesignTransport.json` |
| OD-12 | `Sources/SuiteUI/EditorDetail.swift`, `Sources/DesignModel/DesignTimelineTracks.swift`, `Sources/DesignApp/DesignTimeline.swift`, `Tests/DesignModelTests/DesignTimelineTracksTests.swift`, `Tests/mutations/DesignModel.DesignTimelineTracks.json` |
| OD-13 | `Sources/DesignApp/DesignInspectorTransform+Kernel.swift`, `Sources/DesignApp/DesignInspectorStyle.swift`, `Sources/DesignApp/DesignAnimateMenu.swift`, `Tests/mutations/DesignModel.DesignIntent.json` |
| OD-14 | `UITests/DesignJourneyTests+Animate.swift`, `UITests/DesignJourneyTests+BadFiles.swift`, `Tests/AppSnapshotTests/DesignFileSnapshots.swift` |
| OD-15 | `UITests/DesignJourneyTests+Hero.swift`, `Tests/render-budgets.md` |

## Journey steps

- `DesignJourneyTests.testFirstKeySlidesTimelineIn` (OD-13): key a still rectangle from the inspector; the timeline slides in.
- `DesignJourneyTests.testSaveReopenKeepsKeys` (OD-14): key a node, save, close, reopen; the playhead at 0 shows the rest pose and at 60 the keyed pose (`time.sample` is the oracle).
- `DesignJourneyTests.testOneDocumentHero` (OD-15): new document, draw a UI frame with rectangles and a text node, key two nodes, play, save, reopen, play again, with a `shot` at each step for the contact sheet.

## Render budget rows

Measured in `RenderBudgetDesignAnimateTests` and written to `Tests/render-budgets.md` (OD-11, OD-12, OD-15):

1. playback of animated(500): 0 window bodies per frame, at most 2 dropped frames in 5 s (QB-L4)
2. drag a keyed rectangle at playhead 60 on animated(500): within Design's drag row, 3 bodies and 6 ms p95
3. scrub the ruler 120 samples: canvas body only, 8.3 ms p95
4. first key slide-in: one window body
5. inspector toggle-key: at most the inspector's body

## Done check

Per slice: its PR merged into `feat/one-document` on a green Linux `scripts/ci --changed`, its mutations all caught (`Mutate:` line in the body), and for a `"ui": true` slice its Mac proof (snapshots, budget row, feel gate). The feature is done when the hero journey reports green twice in a row on a quiet Mac and the five budget rows are within budget. Landing on `dev` is a separate captain decision.
