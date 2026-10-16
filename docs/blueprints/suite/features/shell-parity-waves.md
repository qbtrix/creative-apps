# Shell parity: waves

The captain's two decisions of 2026-10-15, recorded in section 6 of
`docs/blueprints/suite.md`, `suiteui.md`, `design.md` and `photo.md`:

1. One shell for all five apps, the `SuiteWindow` style Flare and Halo use.
   Design and Photo move onto it and keep their tools, shortcuts, tool
   options, canvas with rulers, status line and panel contents.
2. Flare's tool box is the standard for every app that has tools:
   `ToolbarGroup`'s `.floating` style, one glass capsule over the canvas.
   Design and Photo drop the docked `.rail`.
3. A visible app switcher at the top of every app window: one centered
   row of monochrome glyphs (Home and the five apps), the current one in a
   glass capsule. SuiteUI draws it (editor-in-window EW-7 and EW-8) with
   every item disabled and saying why. The switching feature (wave 2 of
   `waves.md`, not started) wires it to the same `SwitchMenu` items as
   Window > Switch To, and its journeys click it (`switching.md`, SW-3d).

Then `EditorShell`, `EditorTopBar` and `.rail` are deleted. The packets follow
`docs/factory/packets.md` (lesson 105): each has a `## Build waves` section with
its independent tasks and longest chain, and only the final task of
editor-shell-removal (ER-2) edits a shared doc (`docs/design.md`). That is four
features, one feature-lead session each. A wave starts when everything it
waits on has merged. Two features in the same wave never own the same file.

| wave | feature | line | packet | waits on | longest chain |
|---|---|---|---|---|---|
| 1 | `SuiteWindow` can hold a canvas editor: sidebar slot, subtitle, document actions, inspector width, `-SuiteWindowSize`, `EditorDetail`, `SidebarActionRow`, the app switcher, the journeys' window and geometry checks, the parity journey | `line:suiteui` | `docs/blueprints/suiteui/features/editor-in-window.md` | nothing | 4 (EW-1 → EW-8 → EW-5 → EW-5b; 3 without the #933 wait) |
| 2 | Design opens in `SuiteWindow` with the floating tool box | `line:design` | `docs/blueprints/design/features/shell-parity.md` | editor-in-window | 3 (DS-1 → DS-3 → DS-4) |
| 2 | Photo opens in `SuiteWindow` with the floating tool box | `line:photo` | `docs/blueprints/photo/features/shell-parity.md` | editor-in-window, #812 (photo-seams) | 3 (PS-1 → PS-3 → PS-4) |
| 3 | Delete `EditorShell`, `EditorTopBar`, `.rail` and their tokens; rewrite `docs/design.md`'s Editor shell section | `line:suiteui` | `docs/blueprints/suiteui/features/editor-shell-removal.md` | Design shell-parity, Photo shell-parity | 2 (ER-1 → ER-2) |

This file stays prose: the cross-app order, the shared files and the
collisions below. Each feature's live status and feature issue are data in
its own app, `docs/blueprints/<app>/features/<feature>.wave.json` (wave
`SP1` to `SP3`), and show in that app's generated `features/waves.md`.

**SuiteWindow's base.** The packets build on `SuiteWindow` as it was before
#962, with the inspector inside the split view's detail column. #962 broke
four apps' journeys and is being reverted. **#933** (the split view
overflowing a 900 to 1000 pt window) will be fixed by changing column
minimums, and is a dependency of editor-in-window's geometric test (EW-5,
EW-5b), not a design any packet builds on. editor-in-window is still filed
with `Depends on: none`, because its other tasks don't wait on #933; its
issue body names #933 for the geometric test.

**#873 (targets)** is not a dependency. It owns `Package.swift`,
`Sources/SuiteModel/`, `Sources/SuiteShell/`, `Sources/AfterGlowApp/`,
`scripts/size-report`, `.github/workflows/ci.yml` and `docs/c4/model.json`
(TG-0, the supervisor's commit). No shell-parity task touches any of those,
and no shell-parity task needs a target that isn't on `dev` yet.

**#812 (photo-seams)** is a dependency of Photo shell-parity only. Its
S-8a to S-12 own nearly every file of `Sources/PhotoApp/`
(`docs/leads/photo-seams/RECORD.md` on `lead/photo-seams`, in its build
stage on 2026-10-15). The Photo packet names the files photo-seams leaves, and its
lead re-checks them at stage 1.

## File when ready

Each feature issue is titled "Feature: <name>" and carries the labels
`feature-lead`, its line and `p1`, a link to its packet, the issues it
covers (none: the work comes from the captain's decision, so the body cites
it), one `Depends on:` line and the lead contract below. The lead playbook
(`docs/factory/lead.md`, stage 0) stops a lead whose `Depends on:` issue is
still open, and Belt launches a lead as soon as its issue exists, so a
feature is filed only once everything it waits on is closed.

| feature | title | labels | file when these are closed | `Depends on:` line |
|---|---|---|---|---|
| editor-in-window | Feature: editor-in-window | `feature-lead`, `line:suiteui`, `p1` | nothing (file after this packet PR merges) | `Depends on: none`; the body names #933 as the geometric test's dependency (EW-5b) |
| design-shell-parity | Feature: design-shell-parity | `feature-lead`, `line:design`, `p1` | the editor-in-window issue | `Depends on: #<editor-in-window>` |
| photo-shell-parity | Feature: photo-shell-parity | `feature-lead`, `line:photo`, `p1` | the editor-in-window issue and #812 | `Depends on: #812 (photo-seams)`; the body also names the editor-in-window issue, which closes first in the expected order. If #812 closes first, the line names the editor-in-window issue instead. |
| editor-shell-removal | Feature: editor-shell-removal | `feature-lead`, `line:suiteui`, `p1` | both shell-parity issues | `Depends on: #<photo-shell-parity> (closed)`; the body also names the Design one (closed) |

Design and Photo shell-parity run side by side once both can start. They
share no file: each keeps its root view's name and init
(`DesignEditor(model:zoom:)`, `PhotoEditor(model:tiles:zoom:)`), so neither
edits the shared `Tests/AppSnapshotTests/AppSnapshotTests.swift`.

## Why this order

- **SuiteUI first, alone.** Both apps need its slots, and its journey
  helpers are in `UITests/Journey*.swift`, which only a SuiteUI feature may
  change (the shared-file rule). It is additive: Flare, Halo and Library
  keep their window, and the launch and minimum goldens prove it.
- **The apps in parallel.** Each owns only its own app, model, tests and
  journey files. Design can start as soon as editor-in-window closes; Photo
  also waits for photo-seams, which owns its window, panel, top bar and
  status line until S-13.
- **Subtract last.** `EditorShell`, `EditorTopBar` and `.rail` can go only
  when no app uses them. The one `docs/design.md` edit (task ER-2) lands
  with that deletion, so the rules never describe a shell that is gone, or
  one that doesn't exist yet.
- **Chains.** The longest task chain in any packet is three (DS-1 or DS-2,
  DS-3, DS-4 in Design; PS-1 or PS-2, PS-3, PS-4 or PS-5 in Photo). Each
  packet explains its middle step: the lists leave the panel in the same
  commit that puts them in the sidebar.

## Files across the waves

| path | wave 1 | wave 2 | wave 3 |
|---|---|---|---|
| `Sources/SuiteUI/SuiteWindow.swift` | EW-1, then EW-8 (#933's fix, outside these features, also edits it; whichever merges second rebases) | – | – |
| `Sources/SuiteUI/SuiteSidebarList.swift`, `SuiteWindowSizer.swift`, `Tests/SuiteUITests/SuiteWindowSizeTests.swift`, `Tests/AppSnapshotTests/SuiteWindowSlotSnapshots.swift` | EW-1 | – | – |
| `Sources/SuiteUI/EditorDetail.swift`, `CanvasViewport.swift` (its ⌘0), `Tests/SuiteUITests/EditorDetailLayoutTests.swift`, `Tests/AppSnapshotTests/SuiteEditorDetailSnapshots.swift` | EW-2 | – | – |
| `Sources/SuiteUI/SidebarActionRow.swift`, `Tests/AppSnapshotTests/SuiteSidebarActionRowSnapshots.swift` | EW-3 | – | – |
| `Sources/SuiteUI/AppSwitcher.swift`, `Tests/SuiteUITests/AppSwitcherTests.swift`, `Tests/AppSnapshotTests/SuiteAppSwitcherSnapshots.swift` | EW-7 | – | – |
| `Tests/AppSnapshotTests/SuiteEditorShellSnapshots.swift`, `SuiteEditorBarDimmingTests.swift`, `Tests/SuiteUITests/EditorShellTests.swift` | – | – | ER-1 |
| `Sources/SuiteUI/Gallery/GalleryEditorWindow.swift`, `SuiteGallery.swift` | EW-5 | – | – |
| `Sources/SuiteUI/EditorShell.swift`, `EditorTopBar.swift`, `ToolbarGroup.swift`, `SuiteEnvironment.swift` | – | – | ER-1 |
| `Sources/SuiteUI/Tokens.swift` | EW-7 (the switcher's tokens) | – | ER-1 (comments), then ER-2 |
| `Tests/SuiteUITests/TokensTests.swift`, `docs/design.md` | – | – | ER-2 |
| `UITests/Journey.swift`, `UITests/Journey+Geometry.swift` | EW-4 | – | ER-1 (`Journey.swift`) |
| `Tests/AppAuditTests/ShellGeometry*.swift` | EW-4 | – | – |
| `UITests/SuiteJourneyTests+EditorWindow.swift`, `+Parity.swift` | EW-5 (then EW-5b), EW-6 | – | – |
| `Sources/DesignApp/`, `Sources/DesignModel/DesignToolbarItems.swift`, `Tests/DesignModelTests/DesignToolbarItemsTests.swift`, `UITests/DesignJourneyTests*.swift`, `Tests/AppSnapshotTests/Design*` | – | Design DS-1 to DS-4 | – |
| `Sources/PhotoApp/`, `Sources/PhotoModel/PhotoToolbarItems.swift`, `Tests/PhotoModelTests/PhotoToolbarItemsTests.swift`, `UITests/PhotoJourneyTests*.swift`, `Tests/AppSnapshotTests/Photo*` | – | Photo PS-1 to PS-5 | – |
| `docs/c4/model.json` | – | – | – (the supervisor, below) |
| `project.yml`, `Package.swift`, `.github/`, `scripts/` | – | – | – |

Within a wave, no path is in two features. Within a feature, every shared
path is a chain in its packet.

## Collisions with features not running yet

None of these has a feature issue today. The supervisor files them only
when the shell-parity feature that owns the same files is closed, or
rescopes them first.

| feature | shared files | rule |
|---|---|---|
| SuiteUI lists-and-layers (wave 2 of `suiteui/features/waves.md`) | `SuiteWindow.swift`, `Gallery/GalleryLists.swift` | file it after editor-in-window closes; its packet's `SuiteWindow` tasks build on the sidebar slot |
| SuiteUI canvas-marks | `CanvasViewport.swift` (CM-9) | EW-2 touches only its ⌘0; file canvas-marks after editor-in-window closes, or rebase CM-9 on it |
| Suite switching (wave 2, not started) | none: it builds the switcher's items in `Sources/SuiteModel/` and `Sources/SuiteShell/` and hands them to SuiteUI through the `suiteSwitcher` environment value | `switching.md` now names the editor-in-window issue on SW-3d's `depends on` |
| SuiteUI editor-chrome | `EditorShell.swift`, `EditorTopBar.swift`, `ToolbarGroup.swift` | rescope before filing: EC-3 (the timeline slot) and EC-4 (`.primary`, save status) target `SuiteWindow` and `EditorDetail` now, and EC-7's rail colors go with `.rail`; file it after editor-shell-removal |
| Flare F1a #346, F1b #347 ("the window on `EditorShell`") | `Sources/FlareApp/` | they target `SuiteWindow` (flare.md section 3's dated paragraph); see the next section; the supervisor rewords both issues, which no shell-parity task edits |
| Halo's `-HaloWindowSize` | `Sources/HaloApp/HaloWindowSizer.swift` | not touched here; the editor-in-window lead files a `line:halo` issue to retire it for `-SuiteWindowSize` |
| Design design-window (wave 0b) and the wave-1 Design features' view slices | `Sources/DesignApp/`, `UITests/DesignJourneyTests.swift` | design-window is filed after Design shell-parity closes, and the wave-1 view slices wait on its first slice (DW-a); design-contracts, design-seams and the wave-1 Model slices run beside shell-parity, since DS-1 adds a new Model file only (Design's v3 pilot, `docs/blueprints/design/waves.in.md`) |
| Photo photo-journey-kit, photo-documents, photo-edit, photo-crop | `UITests/PhotoJourneyTests.swift`, `Sources/PhotoApp/` (window, panel, commands; PV-1's save status) | file after Photo shell-parity closes; PV-1's save status shows in the window subtitle (`PhotoToolbarItem.saveState`), not in a top bar |

## Flare's F1a and F1b target SuiteWindow

`docs/blueprints/flare.md` (section 3.1, 7.3 and its waves) still plans
Flare's future window as `FlareEditor` on `EditorShell` with a docked rail,
built by F1a (#346) and F1b (#347). Under the 2026-10-15 decisions Flare
stays on `SuiteWindow` with its floating palette, and both tasks target it.
Their `EditorShell` parts are dropped:

| `EditorShell` part in F1a/F1b | where it goes on `SuiteWindow` |
|---|---|
| the top bar's actions (New, Open, Save, Undo, Redo, Auto-key, Assist, zoom) | the window toolbar: file commands as `documentActions`, the rest as `actions`, the app switcher centered between them |
| the right panel's tabs | the inspector |
| scenes and layers | the sidebar, as today |
| the timeline (`EditorShell(timeline:)`'s bottom slot) | under the stage in the content (the detail column), not a shell slot |
| the docked rail | the floating `ToolbarGroup` palette over the stage, as today |

Flare's line can use editor-in-window's `EditorDetail` (stage, floating
palette, status line) and add the timeline below it in its own content
view. A shared resizable timeline slot is a SuiteUI change for a later
packet: editor-chrome's rescope (above) moves EC-3 there. No shell-parity
task edits #346, #347 or `Sources/FlareApp/`.

## For the supervisor

- **C4.** Once the app features merge, `docs/c4/model.json` still
  describes Design and Photo as "built from SuiteUI's EditorShell", and
  `suiteui-sources` lists the editor shell. No feature edits that file, so
  the supervisor rewords those three descriptions after editor-shell-removal
  (new SuiteUI files are already owned by `Sources/SuiteUI/`).

## Critic round

One read-only critic agent tried to refute the four packets and this file
against `dev` at 54e16aa. It looked for oversized tasks, owned files
overlapping inside a wave or with #812 and #873, the shared-file rule,
tests that can't fail, and journey identifiers that would break. It found
4 blockers, 7 major and 11 minor problems, all fixed:

| # | finding | fix |
|---|---|---|
| 1 | DS-3 would turn the core Design journey red: it clicks the Layers and Properties tabs DS-3 removes (`tab(_:in:)`, lines 99 and 111) | DS-3 removes the tab switches and their helper, and finds the rows in `suite.sidebar` and `suite.inspector` |
| 2 | PS-3 would turn `testTier1Layers` red: it clicks `radioButtons["Layers"]` | PS-3 finds `photo.layers` in the sidebar; the lead greps for every tab lookup first |
| 3 | A 1024 × 768 window can't exist on the runner (its menu bar takes 31 pt) | "1024 × 768" means the display. The window takes the visible frame (about 1024 × 737), and the tests assert the window inside the visible frame and every frame inside the window. |
| 4 | The inspector arithmetic was wrong: the padding is `m` = 12, not 16 | 304 pt and a 944 pt window minimum everywhere |
| 5 | Eight trailing actions plus the toggle would overflow the toolbar | `documentActions` in a `.navigation` group beside the title (New/Open/Save, Export); EW-5 proves every item is hittable before wave 2; zoom leaves the toolbar before Save, Undo or Redo would |
| 6 | `SuiteWindow` apps had their sidebar rows offscreen (#933); Design and Photo have no `offscreen` key to absorb that | #933 gates the geometric test: EW-5's geometric steps wait on its fix (EW-5b), and editor-in-window's `feature-done` waits on EW-5b, so wave 2 starts on a shell that fits |
| 7 | "goldens unchanged" can't fail: `snapshot()` only writes PNGs, and there are no recorded goldens on `dev` | PNGs are for review and named in PRs; acceptance rests on journeys, unit tests and greps |
| 8 | ER-1's own grep would hit `Tokens.swift` comments and `Checks/DisabledDim.swift`'s comment; app file headers still named `EditorShell` | ER-1 owns the Tokens comments; DisabledDim's comment is allowed and left alone; DS-3 and PS-3 reword the headers |
| 9 | A 20000 × 20000 artboard is clamped at 0.05 and can't clear the palette | clearance asserted only where the unclamped fit is at or above the smallest stop; the clamp asserted on its own |
| 10 | The parity journey can't size Design and Photo before wave 2; Halo and Photo have their own size flags; copying Halo's sizer risks jscpd | the size is asserted only for `SuiteWindow` apps; the sizer is written fresh; a `line:halo` issue retires `-HaloWindowSize`; PS-4 retires `-PhotoWindowWidth` |
| 11 | DS-3's snapshot PNGs do change (tab bar), and `DesignFileSnapshots` renders the whole editor | named as changing |
| 12–13 | "region" counted the rulers twice; `CanvasViewport`'s ⌘0 fit ignored the palette | `EditorDetailLayout(viewport:toolCount:)` on the `onSize` viewport; ⌘0 reads `canvasFitScale` (EW-2 owns that one change in `CanvasViewport.swift`) |
| 14 | Row actions are found by title | EW-3 asserts the accessibility label is the title |
| 15 | No journey proved a toolbar identifier; the gallery palette had none | EW-5 asserts both |
| 16 | Two Opacity sliders in Photo's inspector | Photo's opacity drags name their identifier |
| 17 | `Size` doesn't exist in the audit | a width/height pair on `AppAudit.Rect` |
| 18 | EW-3 can't reach a private ink helper that ER-1 deletes | EW-3 keeps its own copy |
| 19 | `-PhotoWindowWidth`'s 880 pt floor is under the new minimum | retired in PS-4 |
| 20 | Design's packet and blueprint paragraph disagreed about the subtitle | the subtitle is the save state's place, empty until #270 |
| 21 | This file's dependency wording and photo-seams range were off; the file table missed test files | fixed |
| 22 | The parity test would sort last and attach audit counts under the wrong apps; it needed its own Photo test image | `testAppsSideBySide`, using ⌘N and `-HaloSample` |

The third decision (the app switcher) was folded in after the critic round,
together with these fixes. It adds EW-7, EW-8 and switching's SW-3d.

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
