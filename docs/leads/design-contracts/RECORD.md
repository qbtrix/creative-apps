# design-contracts lead record

Issue: #1324 · Packet: docs/blueprints/design/features/design-contracts.md
Run: act-1a14478b14e-i8ep · Session: session_01DKQiisBimhgRgEM46b1U5E · Started: 2026-10-16T11:29Z
Stage: done
Base: fb72b7e52405a824fabe34c6c408fcc00d242da2
Next: nothing; feature done (Belt-Contact-Sheet posted on #1324 for run 38956769306)

## Slices
| slice | behavior | tasks | journeys | waits on | rounds | state | run |
|---|---|---|---|---|---|---|---|
| CT-a | old files open with defaults; corner radius saves and reopens | D0-0, D0-2.1 (#1304), D0-1 | MJ1 | nothing | 0 | done | 38905490687 |
| CT-b | fakes act; live says "isn't built yet." | D0-2.2 (#1307), D0-2.3, D0-2.4 (#1312), D0-2.5 | MJ2 | CT-a | 0 | done | 38956769306 |
| CT-c | help law on every fake and stub; four fixtures | D0-2.6, D0-2b, D0-4a | MJ3 | CT-b; CT-a | 0 | done | 38956769306 |
| CT-d | each command one named step; one-layer edits keep today's methods | D0-3a, D0-3b | MJ4 | CT-b | 0 | done | 38956769306 |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| D0-2.1 | CT-a | pilot | edit contracts, style types | Contracts/EditContracts.swift, Contracts/StyleTypes.swift | DesignIDMintTests, DesignRefusalHelpTests | #1304 | merged |
| D0-2.2 | CT-b | pilot | use-case protocols, DesignDocument | Contracts/UseCases.swift | DesignDocumentTests | #1307 | merged |
| D0-2.4 | CT-b | pilot | fake helpers, select fakes | Fakes/FakeSupport.swift, Fakes/DesignSelectFakes.swift | DesignSelectFakesTests | #1312 | merged |
| D0-0 | CT-a | 1 | corner radius (Model half of #753) | DesignNode.swift, DesignCorners.swift, DesignFile.swift, DesignCornerRadiusTests.swift | DesignCornerRadiusTests | #1336 | merged |
| D0-4a | CT-c | 1 | four fixtures, budget helper | DesignFixtures.swift, DesignFixturesTests.swift, DesignBudget.swift, DesignBudgetHelperTests.swift | DesignFixturesTests, DesignBudgetHelperTests | #1327 | merged |
| F-1314 | CT-b | 1 | DesignDocumentTests header fix (#1314) | Tests/DesignModelTests/DesignDocumentTests.swift | DesignDocumentTests | #1328 | merged |
| D0-1 | CT-a | 2 | style schema, public DesignPage init, marquee, selection ends run; MJ1 | DesignNode.swift, DesignWorkspace.swift, DesignSelection.swift, DesignFile.swift, DesignStyleSchemaTests.swift, DesignSelectionRunTests.swift | DesignStyleSchemaTests, DesignSelectionRunTests | #1356 | merged |
| D0-2.3 | CT-b | 3 | NotBuilt, DesignServices .live, services/useServices | NotBuilt.swift, DesignServices.swift, DesignWorkspace.swift, DesignNotBuiltTests.swift | DesignNotBuiltTests | #1354 | merged |
| D0-2.5 | CT-b | 4 | arrange fakes, .fake; MJ2 | Fakes/DesignArrangeFakes.swift, DesignServices.swift, DesignArrangeFakesTests.swift | DesignArrangeFakesTests | #1388 | merged |
| D0-2.6 | CT-c | 4 | contract law | DesignContractLawTests.swift | DesignContractLawTests | #1394 | merged |
| D0-3a | CT-d | 4 | DesignCommand, help, run, apply, mint | DesignActions.swift, DesignActionsTests.swift | DesignActionsTests | #1395 | merged (Mutate 6/6) |
| D0-2b.1 | CT-c | 3 | six new Live stubs (Duplicating, Grouping, Clipboard, Ordering, Styling, Filing) | Live/Live{Duplicating,Grouping,Clipboard,Ordering,Styling,Filing}.swift, DesignLiveStubTests.swift | DesignLiveStubTests | #1383 | merged |
| D0-2b.2 | CT-c | 5 | .live names every Live type; law on .live; MJ3 | DesignServices.swift, DesignLiveStubTests.swift | DesignLiveStubTests | #1401 | merged (Mutate 10/10) |
| D0-3b | CT-d | 5 | clipboard, moveLayer, setStyle; MJ4 | DesignActions+Edit.swift, DesignActionsEditTests.swift | DesignActionsEditTests | #1400 | merged (Mutate 5/5) |
| FD | CT-d | 6 | feature-done: design-contracts.wave.json status built, feature issue #1324 | docs/blueprints/design/features/design-contracts.wave.json | scripts/ci (waves render) | #1410 | merged, feature-done |

Waves: 1 = D0-0, D0-4a, F-1314 (all independent). 2 = D0-1 (waits D0-0: same DesignNode/DesignFile). 3 = D0-2.3 (waits D0-1: DesignWorkspace.swift). 4 = D0-2.5 (waits D0-2.3: DesignServices.swift). 5 = D0-2.6, D0-3a (both wait D0-2.5's .fake; independent of each other). 6 = D0-2b (waits D0-2.6, D0-4a), D0-3b (waits D0-3a); later of the two carries feature-done.

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- D0-2.1, D0-2.2, D0-2.4 already merged in the mini-pilot (#1304, #1307, #1312), per #1324; not rebuilt.
- D0-4a unchained from D0-1 and moved to wave 1: the blueprint 4 fixtures use only existing fields and DesignModel's internal inits, so it needs nothing from D0-1.
- All four slices are Linux-only Model walks: no critic panel runs (lead.md stage 3, Reviews: a Linux-only slice gets no panel).
- PRs target dev (CLAUDE.md, lead contract rule 4); the brief's "main" equals dev's SHA at start and the lane retargets main to dev.
- #1314 (a design-seams finding on DesignDocumentTests, a file this packet now owns) is fixed in wave 1 as F-1314.
- D0-2.3 runs in wave 2 beside D0-1: they share only DesignWorkspace.swift, and D0-2.3 adds just `services`/`useServices` there; whichever merges second rebases. Saves a wave.
- The PR-create tool appends a 'Generated by' footer server-side; the lane strips it from the squash commit (CLAUDE.md), so builders' PRs merged with it (#1327, #1328, #1336).
- D0-2b split: D0-2b.1 (the six new stub files, tests on the stubs alone) runs in wave 3 beside D0-2.5; D0-2b.2 (wiring `.live`, the law on `.live`, MJ3) waits on D0-2.5, D0-2.6 and D0-2b.1. LiveMarquee/Transforming/Aligning/Framing already exist (S-1..S-4), so D0-2b only registers them. Waves now: 3 = D0-2.5, D0-2b.1; 4 = D0-2.6, D0-3a; 5 = D0-2b.2, D0-3b.
- Wave 4 builders start from #1388's branch (D0-2.5, `.fake`) while it waits on the lane, then `rebase --onto origin/dev` and open their PRs only after #1388 merges: saves the lane's macOS-build wait.
- #1388 also edits its C4 part (docs/c4/parts/.../design-model-sources.json) as CLAUDE.md requires for a new file; accepted.
- feature-done goes on a final docs-only PR (FD) after D0-2b.2 and D0-3b merge, so neither code PR has to know which lands last; docs-only takes the lane on the Linux check alone.
- Builders exit before a stacked base merges; the lead hands the rebase and PR to a short shipper agent (D0-2.6 → #1394, D0-3a → #1395).
- gh api writes append a 'Generated by' footer; shippers strip it with the GitHub MCP update_pull_request tool.
- Filed gap #1326 (public DesignPage init); D0-1 closes it.

## Open
- Scoped design run 38917492060 (contains #1388) red: testDrawShapesAddTextAndSave, testShellLight, testShellDark; Model tests green. Culprit #1391 (shell-parity), reported on #1393. CT-b..CT-d need a green Design run.
- Full CI run 38915938965 (head fb72b7e) red on Linux LibraryImportBudgetTests.beginImportWithinBudget (Library line, not this feature) and macOS; CT-b is judged on the scoped design run.
- gap #1326: closes with D0-1.
