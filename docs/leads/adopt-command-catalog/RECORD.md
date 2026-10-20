# adopt-command-catalog lead record

Issue: #2999 · Packet: docs/blueprints/suiteui/features/adopt-command-catalog.md
Run: act-1a157b2050f-ovpu (resumed from act-1a1543c764c-0mz9) · Session: claude/feature-lead-suiteui-run-336pic · Started: 2026-10-20T05:08Z
Stage: 3 wave 4 (AC-flare, AC-library, AC-z listed done by Belt; AC-photo, AC-design, AC-halo wait on CC-u for their menus-from-specs tasks AC-p3, AC-d3, AC-h3)
Base: b3011ab9dc5579023722e79f83254e6e2520e612 (main); dev 18464f26
Next: AC-p3, AC-d3, AC-h3 built and pushed (CI: PASS each), stacked on CC-u (#3484); PRs to dev once #3484 merges; then AC-z2 (feature-done).

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| AC-photo | Photo actions as catalog commands, PhotoHeadless, menus from specs | AC-p1, AC-p2, AC-p3 | MJ-AC-photo | command-catalog:CC-run; CC-u, CC-lint (AC-p3) | true | 0 | building | – | – |
| AC-design | Design commands, DesignHeadless, menus from specs | AC-d1, AC-d2, AC-d3 | MJ-AC-design | command-catalog:CC-run; CC-u, CC-lint (AC-d3) | true | 0 | building | – | – |
| AC-flare | FlareCore's commands and Flare actions, FlareHeadless, menus | AC-f1, AC-f2, AC-f3, AC-f4 | MJ-AC-flare | command-catalog:CC-run; CC-u, CC-lint (AC-f4) | true | 0 | building | – | – |
| AC-halo | HaloCommand cases, HaloHeadless, menus | AC-h1, AC-h2, AC-h3 | MJ-AC-halo | command-catalog:CC-run; CC-u, CC-lint (AC-h3) | true | 0 | building | – | – |
| AC-library | Library actions into the Model, catalog, LibraryHeadless, menus | AC-l1, AC-l2, AC-l3, AC-l4 | MJ-AC-library | command-catalog:CC-run; CC-u, CC-lint (AC-l4) | true | 0 | building | – | – |
| AC-z | all-apps goldens, conformance walk, status built | AC-z1, AC-z2 | MJ-AC-all | every slice above; command-catalog:CC-z (AC-z2) | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| AC-p1 | AC-photo | 1 | Photo catalog | Sources/PhotoModel/PhotoCommandCatalog.swift | PhotoCommandCatalogTests | #3187 | merged c083b7ad |
| AC-p2 | AC-photo | 2 | Photo headless | Sources/PhotoModel/PhotoHeadless.swift | PhotoHeadlessTests | #3225 | merged f3936261 |
| AC-p3 | AC-photo | 2 | Photo menus from specs | Sources/PhotoApp/PhotoCommands*.swift | menu golden | – | built beae2410, PR waits #3484 |
| AC-d1 | AC-design | 1 | Design catalog | Sources/DesignModel/DesignCommandCatalog.swift | DesignCommandCatalogTests | #3188 | merged 25f6d337 |
| AC-d2 | AC-design | 2 | Design headless | Sources/DesignModel/DesignHeadless.swift | DesignHeadlessTests | #3210 | pr a1a332dc |
| AC-d3 | AC-design | 2 | Design menus from specs | Sources/DesignApp/DesignCommands.swift | menu golden | – | built fae0354e, PR waits #3484 |
| AC-f1 | AC-flare | 1 | FlareCore commands | Sources/FlareModel/FlareCoreCommandCatalog.swift | FlareCoreCommandCatalogTests | #3189 | merged fbfde9a1 |
| AC-f2 | AC-flare | 2 | Flare app actions | Sources/FlareModel/FlareCommandCatalog.swift | FlareCommandCatalogTests | – | building |
| AC-f3 | AC-flare | 3 | Flare headless | Sources/FlareModel/FlareHeadless.swift | FlareHeadlessTests | – | blocked |
| AC-f4 | AC-flare | 3 | Flare menus from specs | Sources/FlareApp/FlareCommands.swift | menu golden | – | blocked |
| AC-h1 | AC-halo | 1 | Halo catalog | Sources/HaloModel/HaloCommandCatalog.swift | HaloCommandCatalogTests | #3191 | merged 80c205d5 |
| AC-h2 | AC-halo | 2 | Halo headless | Sources/HaloModel/HaloHeadless.swift | HaloHeadlessTests | #3207 | pr 98b2db9f |
| AC-h3 | AC-halo | 2 | Halo menus from specs | Sources/HaloApp/HaloCommands.swift | menu golden | – | built c7f0e5e2, PR waits #3484 |
| AC-l1 | AC-library | 1 | Library actions into the Model | Sources/LibraryModel/LibraryActions.swift | LibraryActionTests | #3190 | merged ec18f81b |
| AC-l2 | AC-library | 2 | Library catalog | Sources/LibraryModel/LibraryCommandCatalog.swift | LibraryCommandCatalogTests | – | building |
| AC-l3 | AC-library | 3 | Library headless | Sources/LibraryModel/LibraryHeadless.swift | LibraryHeadlessTests | – | blocked |
| AC-l4 | AC-library | 3 | Library menus from specs | Sources/LibraryApp/LibraryMenus.swift | menu golden | – | blocked |
| AC-z1 | AC-z | 4 | AllAppsCatalogTests | Tests/AfterGlowCLITests/AllAppsCatalogTests.swift | AllAppsCatalogTests | – | blocked |
| AC-z2 | AC-z | 5 | shared prose, status built, feature-done | docs/blueprints/suiteui.md, adopt-command-catalog.wave.json | waves check | – | blocked |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- PRs target `dev` (CLAUDE.md, lead contract rule 4).
- The whole feature waits on command-catalog's CC-run, which this same run builds; nothing starts before it merges.

## Open
- CC-run merged (CC-8 671c98e7, 06:31Z); wave 1 started.
- AC-p2 (#3225): only batch-resize of the two real jobs; the watermark job waits on gap #3219 (place a pasted layer, set opacity; job script posted there). Core PNG/JPEG codecs are stubs at the pin, so CoreRasterImageCodec carries a spec-built PNG reader/writer on core's zlib (drop after the core bump with IC-4/IC-5); JPEG refuses. Also fixes PhotoDocumentFile reopen taking a layer's size as the canvas. batch-resize job ~27 s in debug.
- AC-d2 (#3210): multi-file export writes out/{stem}/<frame>.svg, an invented rule the CLI real-jobs harness (CL-7/CL-9) must adopt or replace; tests carry a small SHA-256 (none on Linux Foundation); PNG export waits on a Linux PNG writer. AC-d3 can replace DesignCatalogDoc in DesignCommandCatalogTests with DesignHeadless. Same stub-test edits as #3207.
- AC-h2 (#3207): CommandSpec.run is internal, so headless docs rewrap specs (HaloHeadless.lifted); a kernel CommandCatalog.lifted helper would remove it (gap candidate). PNG.write unsupported at pinned core until IC-5. RealJobs.check still the CL-9 stub. Stub tests CommandFakeTests/CLIStubTests now skip built apps. Halo window file commands (save, open, open-recent, start-render) still notBuilt: AC-h3.
- The real jobs depend on afterglow-cli CL-jobs (#2998). Photo and Library Linux PNG depend on creative-core image-codecs #562.
- AC-p1 (#3187): CommandSpec has one title (= undo name); menu labels live in PhotoWorkspace.menuTitle(_:). AC-p3 must use it, or a kernel display-title field gets filed for CC-u.
- AC-d1 (#3188): AC-d3 hand-offs: alignHelps differs from help(.align) (catalog uses help); Rename Page has no menu item; page.rename now off during text edit; Copy/Cut/Paste/Move Layer are not DesignCommands, so not in the catalog.
- AC-f1 (#3189): registry has 68 ids (not 63); FlareCore ids kebab-cased for the catalog (layer.setFlags -> layer.set-flags); 37 layer commands use a hand schema table (probe cannot see flattened owner); shapeKey.set/remove unavailable (unbuilt in core).
- AC-l1 (#3190): LibraryCommands.swift still duplicates the disabled-item reasons; AC-l4 builds menus from help(_:) and drops the copy.
- AC-h1 (#3191): conformance skips with reasons: playhead saved in the file (scrub/next-frame change bytes), step names follow the payload, no-op edits stay enabled, duplicate keeps the id counter, ~15 examples need a richer fixture; file commands and render.start wait on AC-h2.

## Decisions (run act-1a1543c764c-0mz9)
- 2026-10-19T13:01:46Z: Belt's brief lists AC-photo/design/flare/halo/library as done, but no slice has a Belt-Slice-Done line on #2999: AC-d2 #3210 and AC-h2 #3207 are open (macOS builds 39231785889, 39229979032 green), AC-f2/AC-l2 never opened a PR, and AC-*3/AC-*4 are unbuilt. Working the real state: AC-f2 and AC-l2 rebuilt now; no Belt-Slice-Done until a slice's tasks are merged and a run proves it.
- 2026-10-19T13:01:46Z: lead branches rebased on main 6f9a2b88 (shallow clone unshallowed first).
- 2026-10-19 AC-f2 #3255: Flare catalog with 99 ledger ids. Left out to stay under 400 lines: scenes.select, Finish Path, Export, Close, the per-file Open Recent items, View, Symbol, keyframe and timeline commands. These ride AC-f4 (menus), or become gap issues at AC-z. Core ids are ledgered, not conformance-checked, because no single fixture runs all 63.
- 2026-10-19 AC-l2 #3248: Library catalog. Import Folder and Export are left out because Library has no Model runner for them yet. Develop and crop menu reasons stay as today's menu text; the more specific Model help strings are a later choice for AC-l4.
- 2026-10-19 Builder PR bodies picked up a session footer, and a REST edit can't remove it because the server re-appends it. The lane strips it from the squash, and the commits are clean (author Prakash Dalai, no trailers).

## Decisions (run act-1a157b2050f-ovpu)
- 2026-10-20: command-catalog CC-u unchained from font-picker FP-a (see command-catalog RECORD), so AC-*3 now wait only on CC-u, which is building.
- PRs target `dev` (CLAUDE.md, the lane).
- AC-p3/d3/h3 (built, branches lead/adopt-command-catalog-AC-{p3,d3,h3}): each app gets <App>MenuState in its Model. Baselines can't be emptied: Photo keeps Close, Clear Menu (no catalog spec) and sheet buttons; Design keeps Close, Export…, zoom items (no catalog commands) and "OK"; Halo keeps sheet/alert buttons outside the menu files. Enabled items' help is now the spec summary; Halo's Space hints are gone (gap candidate for kernel export/zoom specs).
- 2026-10-20T09:43:56Z: AC-photo #3584 (head 22c6fa07), AC-design #3585 (569e890f), AC-halo #3587 (ad65da23) opened on dev with fast-lane; each passed scripts/ci --changed after merging dev (CC-u #3484). AC-z2 waits on these three.

- 2026-10-20T11:09:53Z: AC-d3 (#3585) needs-rebase fixed. Merging dev conflicted in the design-model-sources C4 description; the merge keeps dev's layer-tree clause and the DesignMenuState clause. Gate PASS, head a9eca0ed, Head line moved.
- 2026-10-20T13:16:33Z: AC-d3 #3585 and AC-h3 #3587 merged. AC-z2 opened as #3606 (head 0742cf4a, fast-lane + feature-done; suiteui.md Menu commands row says every app builds its menus from its catalog, wave status built; scripts/ci --changed PASS). Belt-Slice-Done waits on a successful run containing the slices; scoped runs 39424969406 (suiteui), 39424984298 (photo), 39424963422 (design) and 39426337532 (halo) are queued on 897ccbb2.

- 2026-10-20T14:18:51Z: AC-z2 #3606 merged 14:00Z as 59708c02; every slice merged. Full CI 39436941980 at 56e73319 (has AC-design 2128ac4b and AC-z 59708c02) pending; slice lines wait on it.

- 2026-10-20T14:40Z: Full CI 39436941980 cancelled. Full CI 39438701609 at 9f880c85 (contains every slice, incl. 6fa96843) queued; scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:00Z: Full CI 39438701609 (9f880c85) and newer 39442633733 (0dd23d65, also contains every slice) both queued; macOS queue backed up. Scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:21Z: Full CI 39442633733 (0dd23d65), 39438701609 (9f880c85) and newer 39447117246 (27b67332, pending) all contain every slice; none started. Scoped runs at 897ccbb2 still queued. Slice lines wait.

- 2026-10-20T15:41Z: No full or scoped CI run has completed since 15:21Z; 39447117246 (27b67332), 39442633733, 39438701609 and scoped runs at 897ccbb2 still waiting on macOS runners. Slice lines wait.

- 2026-10-20T16:00Z: Still no completed full or scoped CI run since 15:21Z (only a Linux check at 27b67332 finished). Full runs 39447117246, 39442633733, 39438701609 and scoped runs at 897ccbb2 wait on macOS runners. Slice lines wait.

- 2026-10-20T16:20Z: No completed full or scoped CI run since 15:21Z (only Linux checks at 27b67332 and 47dd9bb8). Full runs 39447117246, 39442633733, 39438701609 and scoped runs at 897ccbb2 still wait on macOS runners. Slice lines wait.

- 2026-10-20T16:40Z: no qualifying run completed; full CI 39447117246 at 27b67332 still pending, 39442633733 and 39438701609 queued; only Linux checks completed (5eceabf7, 47dd9bb8)

- 2026-10-20T17:00Z: no qualifying run completed; full CI 39447117246 at 27b67332 still pending; only a Linux check completed (7b45f176)

- 2026-10-20T17:20Z: full CI 39447117246 at 27b67332 cancelled (replaced); new full CI 39464293440 at 39a1c97e pending, contains every slice; no qualifying run completed yet

- 2026-10-20T17:40Z: full CI 39464293440 at 39a1c97e cancelled (replaced while pending); new full CI 39467874733 at 59fe72db pending, contains every slice; no qualifying run completed yet

- 2026-10-20T18:00Z: full CI 39467874733 at 59fe72db cancelled (replaced while pending); new full CI 39469318877 at d7f615dc pending, contains every slice; no qualifying run completed yet
