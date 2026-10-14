# Design features: waves

The Design blueprint (`docs/blueprints/design.md`, merged in #766) grouped
into features, one feature-lead session each. This file covers the
blueprint's waves 0, 1 and 2, which have packets; wave 3 (tier 2) gets its
packets once wave 2 has landed. A wave starts when everything it waits on
has merged. Two features in the same wave never own the same file. Each
packet lists its tasks, owned files and acceptance tests.

Blueprint wave 0 (`design-seams`, D0-1 to D0-7) is one feature in the
blueprint. Its code is about 954 lines before tests in the Model alone
(review of #766), and its window half waits on SuiteUI's harness while its
Model half does not, so it ships as two features in a chain: wave 0a
(Model) and wave 0b (window).

| wave | feature | packet | covers | waits on | feature issue |
|---|---|---|---|---|---|
| 0a | The Model seam: schema, contracts, services, fakes, live stubs, actions, routes, fixtures | `design-seams.md` | the `DesignPage` init gap (filed by the lead) | PR #753 (corner radius) merged | file when ready |
| 0b | The window seam: intents, launch arguments, menus, canvas slots, inspector shell, control ids, J15 and layout | `design-window.md` | #288 (part) | design-seams; #778 suite-harness | file when ready |
| 1 | Select and edit several layers | `select-several.md` | #714, #542, #607; gaps: marquee, several layers, Zoom to Selection | design-window | file when ready |
| 1 | Duplicate, group, cut, copy and paste | `copy-group.md` | #414, #416, #415 | design-window | file when ready |
| 1 | Style rows and drawing them | `style-rows.md` | #752, #267, #268, #276, #266 | design-window | file when ready |
| 1 | The Layers panel | `layers-panel.md` | #613, #589 (Design half); gap: rename, reorder, nest, Arrange | design-window | file when ready |
| 1 | Files and history | `files-history.md` | #275, #270; gap: open bad files journey | design-window | file when ready |
| 2 | The tier-2 seam | `design-seams-2.md` | – | all five wave-1 features | file when ready |

No Design feature issue is filed yet: every feature waits on an open
dependency (below). #288 closes when Design's `identifier` count reaches 0:
each wave-1 lead reads the count on its `feature-done` run, and the one
whose run reaches 0 carries `Closes #288` in its last PR (or files the
remainder as a `gap` issue if wave 1 ends above 0).

## File when ready

The lead playbook (`docs/factory/lead.md`, stage 0) stops a lead whose
`Depends on:` issue is still open, and Belt launches a lead the moment a
feature issue exists, so each issue is filed once its dependency has
merged or closed: labels `feature-lead`, `line:design` and `p1`, a link to
its packet, the issues it covers, one `Depends on:` line, and the lead
contract below.

| feature | title | tier | waits on | `Depends on:` line once filed |
|---|---|---|---|---|
| design-seams | Feature: design-seams | p1 | PR #753 merged (rebased first: it was CONFLICTING against `dev` at review) | `Depends on: #753 (merged)` |
| design-window | Feature: design-window | p1 | the design-seams feature issue closed, and #778 suite-harness closed | `Depends on: <design-seams issue> (closed)`; the body also names #778 |
| select-several | Feature: select-several | p1 | the design-window feature issue closed | `Depends on: <design-window issue> (closed)` |
| copy-group | Feature: copy-group | p1 | the design-window feature issue closed | same |
| style-rows | Feature: style-rows | p1 | the design-window feature issue closed | same |
| layers-panel | Feature: layers-panel | p1 | the design-window feature issue closed | same |
| files-history | Feature: files-history | p1 | the design-window feature issue closed | same |
| design-seams-2 | Feature: design-seams-2 | p2 (tier 2) | all five wave-1 feature issues closed | `Depends on: <files-history issue> (closed)`; the body lists the other four |

Housekeeping before wave 0a (review of #766, blueprint Q6): close PR #719,
whose fix shipped as #749, and rebase #753, dropping its `docs/c4/model.json`
edit on the rebase (the supervisor folds it in with the rest), or keeping it
as a captain-approved exception.

## Why this order

- **Wave 0a takes every shared Model file once** (`DesignNode.swift`,
  `DesignWorkspace.swift`, `DesignServices.swift`, the contracts, the
  actions, the gesture routes) and backs each new slot with `NotBuilt`,
  so nothing that works today goes off and no later feature has to add a
  case, slot or stored field. Wave 1 still edits some of these files for
  its own behavior, as a deliberate change from the blueprint's 8.2 table:
  select-several takes `DesignActions.swift`, `DesignActions+Edit.swift`
  and `DesignCanvasEditing.swift` (the #542 guard on the public entry
  points), and layers-panel takes `DesignWorkspace.swift` (#613); no two
  wave-1 features share one. It needs no SuiteUI and no engine, so it can start as soon as
  #753 merges.
- **Wave 0b takes every shared window file once** (`DesignIntent.swift`,
  `DesignWindow.swift`, `DesignCommands.swift`, the menus) and puts every
  tier-1 control on screen, disabled with "<Feature> isn't built yet.". It
  waits on SuiteUI's harness (#778) for three things it cannot make
  itself: the journey template that compiles `UITests/DesignJourneyTests*.swift`
  (SH-7, #333), `suite.controls` through `.suiteControl` and `.suiteProbes()`
  (SH-5, #775, the one publisher), and `suite.perf` (SH-4, #330).
- **Wave 1 is the everyday loop** in five features with disjoint files,
  any order. None waits on creative-core. Each SuiteUI part it would like
  (a `CanvasViewport` show-rect input, `ScrubField` mixed, `EditorSaveStatus`,
  the sidebar rename and group-row toggles) has a placeholder or an
  `XCTSkip` naming the issue, so no wave-1 feature waits on another line.
- **Wave 2 repeats the seam for tier 2** once wave 1 has let go of the
  shared files, so wave 3's four features (export, pen, components,
  variables) run side by side.

## What each feature waits on in other lines (none blocks its start)

| feature | SuiteUI | creative-core |
|---|---|---|
| design-seams | – | – |
| design-window | #778 suite-harness (SH-4 #330, SH-5 #775, SH-7 #333); files a new `needs-ui` issue: `ScrubField` mixed state | – |
| select-several | files a new `needs-ui` issue: `CanvasViewport` shows a document rect (J4's centering assert skips on it); #330, #333 for P1; #273 is not waited on (Q7: canvas-marks CM-4 files Design's adoption task) | – |
| copy-group | – | – |
| style-rows | #718 (inspector-controls IC-3: `onEnd` on the color rows; Design's local end works meanwhile); #330, #333 for P2 | – |
| layers-panel | lists-and-layers: #577, #108 (rename keys), #73 (context menus), #589 (LL-9, group-row toggles: J12's eye step skips on it); #330, #333 for P3 | – |
| files-history | editor-chrome EC-4 #339 (`EditorSaveStatus`; plain status text meanwhile); #330, #333 for P4 | – |
| design-seams-2 | editor-chrome EC-4 #339 (Export's primary style; plain item meanwhile) | – |

Screen-side budgets (blueprint 7.1, the review's "weak" note): until
#330 and #333 land, P1 to P4 cannot run even report-only; each lead
records them as blocked in RECORD.md with the issue numbers, and the model
half gates alone (Q3). QD-V2, QD-V4's golden half, QD-V9 and the QB-F5
goldens wait on #331 and #332 (suite-harness SH-9, SH-10).

## Files across the waves

- **Wave 0a, design-seams** owns, in `Sources/DesignModel/`:
  `DesignNode.swift`, `DesignWorkspace.swift`, `DesignSelection.swift`,
  `DesignFile.swift`, `Contracts/` (three files), `NotBuilt.swift`,
  `DesignServices.swift`, `Fakes/` (three files), `Live/` (ten files),
  `DesignActions.swift`, `DesignActions+Edit.swift`,
  `DesignCanvasEditing.swift`, `DesignFixtures.swift`, and its tests.
- **Wave 0b, design-window** owns `Sources/DesignModel/DesignWindowOptions.swift`
  and, in `Sources/DesignApp/`: `DesignIntent.swift`, `DesignWindow.swift`,
  `DesignEditor.swift`, `DesignCanvas.swift`, `DesignCanvasMarks.swift`,
  `DesignSelectionMarks.swift`, `DesignFrameLabels.swift`,
  `DesignInspector.swift`, `DesignAlignBar.swift`,
  `DesignPasteboardBridge.swift`, `DesignLayersPanel.swift`,
  `DesignPanel.swift`, `DesignCommands.swift`, `DesignEditMenu.swift`,
  `DesignObjectMenu.swift`; `UITests/DesignJourneyTests.swift`,
  `+EveryControl`, `+Layout`; its snapshots and tests.
- **Wave 1** (disjoint, checked by the critic):
  - select-several: `Live/LiveMarquee`, `LiveTransforming`, `LiveAligning`,
    `LiveFraming`; `DesignAlign.swift`, `DesignCanvasEditing.swift`,
    `DesignActions.swift`, `DesignActions+Edit.swift` (the #542 guard);
    `DesignCanvas.swift`, `DesignSelectionMarks.swift`, `DesignAlignBar.swift`;
    `+Select`, `+PerfCanvas`.
  - copy-group: `Live/LiveDuplicating`, `LiveGrouping`, `LiveClipboard`;
    three new snapshot files; `+Arrange`. No view.
  - style-rows: `Live/LiveStyling`; `DesignCorners.swift`,
    `DesignInspectorContent.swift`, `DesignText.swift`;
    `DesignInspector.swift`, `DesignInspectorStyle.swift`,
    `DesignCanvasMarks.swift`, `DesignFrameLabels.swift`,
    `DesignTextEditor.swift`; `+Style`, `+PerfScrub`.
  - layers-panel: `Live/LiveOrdering`; `DesignLayerToggles.swift`,
    `DesignWorkspace.swift`; `DesignLayersPanel.swift`; `+Layers`,
    `+PerfLayers`.
  - files-history: `Live/LiveFiling`; `DesignFile.swift`,
    `DesignHistory.swift`; `DesignCommands.swift`, `DesignWindow.swift`,
    `DesignEditor.swift`; `+Files`, `+PerfFiles`.
- **Wave 2, design-seams-2** takes back what it needs from wave 1 (listed
  in its packet) plus `Fakes/DesignTierTwoFakes.swift`, four `Live/`
  stubs, `DesignActions+TierTwo.swift`, `DesignExportSheet.swift` and
  `DesignVariablesSheet.swift`.
- **Nobody** in waves 0 to 2 edits `Sources/SuiteUI/**`, `project.yml`,
  `UITests/Journey*.swift`, `Tests/AppSnapshotTests/AppSnapshotTests.swift`,
  `docs/c4/model.json`, `docs/design.md` or `Package.swift`. The
  `design-model-sources` and `design-app-sources` components already own
  every new file by path; the supervisor folds the planned descriptions
  (`docs/blueprints/design/c4-planned.json`) and blueprint section 6's
  Design rules into those shared docs.

## Folded in from the review of #766

| note | where |
|---|---|
| Wave 0 waits on #753, CONFLICTING against `dev`; close #719 | design-seams' `Depends on:`; housekeeping above |
| §6's `docs/design.md` section had no owner | no feature edits it; the supervisor folds it in (shared-file rule); every packet points at blueprint section 6 |
| D0-2 is ~954 lines: split into at least three PRs; check D0-5a | D0-2.1 to D0-2.5 and D0-2b; D0-5a split into D0-5a and D0-5c, D0-5b into D0-5b and D0-5d |
| Option-drag records one "Duplicate" step, ids minted once | design-seams D0-3c's pseudocode and `DesignOptionDragTests` |
| Q3: raise #330 | it is now covered by suite-harness #778 (SH-4), wave 1 of SuiteUI |
| Screen-half rows unmeasurable until #330 and #333 | declared above and in each packet's quality table |
| shared files: `project.yml` (D0-7), `docs/c4/model.json` (D0-2, D0-5b, D2-4), `docs/design.md` | none edited: SuiteUI SH-7 owns the template; the supervisor owns the docs |
| needs-ui list (#330, #331, #332, #333, #339, #589, #577, #108, #73, #111, #706, #745/#718, #273) | the table above; #745 is closed, so #718 is the open one |

Factual slips fixed in the packets: J5's first marquee selects A and B
(Title ends at y 72), as the blueprint says, and the fakes' scratch test
agrees; J10's stroke reaches width 4 with three → presses from the default
width 1; the `crowd` count is 2,000 layers (40 frames, each 48 rectangles
and one text).

## Critic round

One read-only critic agent tried to refute the seven packets: task size,
owned files overlapping within a wave or between side-by-side tasks, the
shared-file rule and protected paths, tests that cannot fail or whose
numbers are wrong against the fixtures, closed or duplicate issues, facts
against `dev`, and the lead contract. It found 5 blocking, 12 major and 18
minor problems, all fixed in the packets:

| # | finding | fix |
|---|---|---|
| 1 | the #542 guard on `apply` would stop every several-layer drag step | the guard sits on the public entry points only (select-several S-5) |
| 2 | J12 "drag C above B" is a no-op on `cards` (C is already above B), and L-1's index put C below B | "drag B above C"; L-1 moves B to index 2 (the blueprint's J12 has the same slip) |
| 3 | "Pair into E1" throws `.intoItself`, not `.notAContainer` | "A into E1" |
| 4 | the marquee inside a hidden Pair returned its children | `LiveMarquee` returns [] under a hidden or locked parent |
| 5 | the saved marker was the undo count: wrong after undo-then-edit and at the 100-step cap; a new file read dirty | step serials that only increase; tests for both cases |
| 6 | FH-2 edited `newFile` in `DesignWorkspace.swift`, layers-panel's file | the marker lives in `DesignHistory`; no workspace edit |
| 7 | D0-5a used the pasteboard bridge before D0-5d | `DesignWindow.swift` chains D0-5a → D0-5d → D0-7a; D0-5d fills the cases |
| 8 | D0-5b drew several-layer handles on `.live` (dead) and contradicted the unchanged PNG | handles only when `transformHelp` is nil; S-6 owns the PNG change |
| 9 | design-seams said the lane dispatches no CI for it | the `feature-done` merge dispatches it |
| 10 | ST-3 breaks `DesignCompactSelectionTests` | added to ST-3 |
| 11, 12 | wrong Pen reason and a help sentence no refusal has | the real sentences |
| 13 | file version 2 breaks the version-1 byte checks D2-1b did not own | added to D2-1b |
| 14, 15 | `layerDrop` ignored the removal of the dragged layer; L-2 tested a stub | it takes the dragged id; L-2 follows L-1 |
| 16 | D0-2.5 likely over 400 lines | the contract law is D0-2.6 |
| 17 | waves.md said no later feature edits the seams | reworded as a deliberate change |
| 18–36 | tests that could not fail (A's zero offset, `.live == .live`, blank rename already refused), unnamed refusals, opacity scale, LL task names, L-6 ordering, an unowned fuzz file, `didSave` duplicated, App-only logic, run ending after a save, which File ids, who closes #288, #753's corner sentence and its C4 edit, the `ScrubField` mixed issue's overlap, 5.5 vs 5.4 paste rule, fixture ids in C-3 | each fixed in place |

Checked clean: the lead contract below is byte-identical to
`docs/factory/lead.md`; every cited issue is open except #413 and #745
(both said so); no issue is closed by two features; no shared or protected
path is edited; the five wave-1 features own disjoint files; the fixture
numbers (J5's marquee, "Mixed" fields, clamps, the `crowd` count) hold; no
product names.

## The lead contract

Every feature lead and every task below codes against this. It is handed
verbatim to every session, and each feature issue carries it.

1. **Feature issue.** One GitHub issue per feature, labels `feature-lead` and `line:<app>`. Body links the packet `docs/blueprints/<app>/features/<feature>.md` and has one `Depends on:` line.
2. **Run.** Belt runs one cloud session per feature issue (a lead), from the trusted launch folder, with the repo's Auto settings (creative-apps#733, creative-core#263). A lead holds one in-flight slot however many PRs it opens.
3. **Status channel.** The lead pushes `docs/leads/<feature>/RECORD.md` and `timeline.tsv` to branch `lead/<feature>` after every stage. Belt reads the branch's last commit time; nothing else is polled besides PRs and issue comments.
4. **Swarm PRs.** Base `dev`, label `fast-lane`, at most 400 lines and 15 files. Body lines: `Belt-Lead: <run id>`, `Feature: <feature>`, then `Fast-Check: pass` and `Head: <full sha>` after `scripts/ci` passes. The lane merges them. Nobody merges into dev by hand or by an agent.
5. **Review policy (decision for the captain).** `Belt-Lead:` PRs do not need the `belt/review` status. The lead's own critic panel is the review. Only `Belt-Run:` and `Belt-Test:` PRs keep it.
6. **Done.** All three: a `Belt-Lead:` PR labelled `feature-done` has merged; the CI run it triggered on dev is green; the lead commented on the feature issue with a line starting `Belt-Contact-Sheet:` and the run link.
7. **Stall.** No commit on `lead/<feature>`, no PR event and no issue comment for 30 min: Belt sends one nudge with `claude -p --cloud <session id> "<resume text>"`. A second stall: relaunch with a resume brief that says "read RECORD.md, continue from the last stage". A third: label the issue `needs-human` and stop.
8. **Timeouts.** Lead runs: 8 h wall clock, no 1 h no-PR rule. Task runs keep today's 4 h and 1 h.
9. **Brief rules.** Step one checks out the integration branch and verifies the base SHA. Set the repo-local identity "Prakash Dalai" / `86671543+prakashUXtech@users.noreply.github.com`. No attribution line anywhere, comments included. Fixers run the full harness before handing back. The Anatomy loop stops after 2 clean rounds or 4 rounds total; once a round is clean, add no new critics. One critic lens is first-use clarity: "what does each number and label mean to someone new?". Agents never treat a chat message as a reason to stop or skip a merge; questions go to the supervisor.
