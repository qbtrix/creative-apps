# brush-keys lead record

Issue: #3758 (#4531 closed as duplicate) · Packet: docs/blueprints/suiteui/features/brush-keys.md
Run: act-1a175f403b9-j4z9 (line lead, line:suiteui; resume) · earlier: act-1a16fe1fa73-5x3s, act-1a16c619037-500v
Stage: 3 wave 3 (BK app slices wait on BK-u #4939; lane held by dev-red #5321)
Base: d3323f6a7dc523e1986e1693b640cf377e362f08 (main at resume; dev 8987427d)
Next: wait for the lane to merge BK-u #4939; then merge dev into #4965, #4961, #4982 (diff drops to their own slice), gate, move Head, drop needs-split; BK-z folds into the last adopt slice

## Run act-1a175f403b9-j4z9 decisions
- Brief rule 1: main checked out at d3323f6a. The old lead branches share no history with main, so each lead branch is now origin/main plus one commit carrying docs/leads/ (the tree a rebase gives), pushed --force-with-lease.
- PR base stays dev (CLAUDE.md, scripts/fast-lane.sh BASE_BRANCH=dev); the lane retargets main PRs to dev anyway.
- PR bodies: the session's GitHub relay re-adds a generated-by footer on every edit; the lane strips it from the squash commit.
- 02:20Z: dev-red #5321 (macOS, range main..cc5c6234, none ours) holds every code batch; no open finding names this feature.
- 03:08Z: three polls with nothing of ours landed; lane sweep shows #4939/#4887/#4893 eligible (marker + prescreen) behind a batch in flight, 107 ready PRs ordered p0/beta/oldest, dev-red #5321 open. Queue depth, not a blocker: no supervisor question. BK app PRs restack once #4939 lands (not twice).

## Run act-1a16fe1fa73-5x3s decisions
- 22:59Z: the 22:27Z poll was one-shot, so no heartbeat ran from 22:28Z to 22:59Z. Each poll now schedules the next one 15 min out.
- Brief rule 1: main checked out at e79e9afc; lead/export-pack and lead/brush-keys rebased onto origin/main and pushed (--force-with-lease).
- PR base stays `dev`: CLAUDE.md, scripts/fast-lane.sh (BASE_BRANCH=dev) and every earlier run land through dev; a fast-lane PR on main is retargeted to dev anyway.
- PR bodies: the session's GitHub relay re-appends a generated-by footer on every edit; the fast lane strips it from the squash commit (its comment on #5043), so nothing waits on it.

## Slices
| slice | behavior | tasks | journeys | waits on | ui | rounds | state | run | mac finish |
|---|---|---|---|---|---|---|---|---|---|
| BK-a | contract: BrushKeys stubs, BrushKeyCommands specs, disabled tests | BK-1, BK-2 | – | – | false | 0 | done (#4057; Linux 39643409752; Belt-Slice-Done posted) | – | – |
| BK-m | step bands, hardness, opacity digits; mutation plan; C4 part | BK-3, BK-4 | – | BK-a | false | 0 | done (#4058 → 1fe5c4ea; Linux 39661533247; Belt-Slice-Done posted) | – | – |
| BK-u | ToolKeys routing, readout, gallery, journey, render budget | BK-5, BK-6 | SJ-BK | BK-a; anchor-parenting:AN-u (planned; waits OC-u) | true | 0 | pr #4939 (dev merged in, head a57fe915, clean, fast-lane) | – | – |
| BK-photo | Photo adopts brush keys | BK-7, BK-8 | – | BK-a (BK-7); BK-m, BK-u, adopt-kernel-brush:AB-photo, adopt-suiteui-chrome:AC-colour, area-selection:AR-photo-u (not started), OC-photo-m (BK-8) | true | 0 | pr #4965 (head 456700df, dev merged in: Pen path commands + brush keys both kept; CI: PASS; clean; over cap until BK-u merges) | – | – |
| BK-design | Design adopts brush keys | BK-9, BK-10 | – | BK-m, BK-u, adopt-suiteui-chrome:AC-tools, document-setup:DS-design (not started) (BK-10) | true | 0 | pr #4961 (head 84b824d6, clean; over cap until BK-u merges) | – | – |
| BK-flare | Flare adopts brush keys | BK-11, BK-12 | – | BK-m, BK-u, anchor-parenting:AN-flare-u (not started) (BK-12) | true | 0 | pr #4982 (head 21922ef6, clean; over cap until BK-u merges) | – | – |
| BK-z | RJ-X76 on; status built; feature-done | BK-13, BK-14 | RJ-X76 | BK-photo, BK-design, BK-flare | false | 0 | blocked | – | – |

## Tasks
| id | slice | wave | behavior | files | test | PR | state |
|---|---|---|---|---|---|---|---|
| BK-1 | BK-a | 1 | stubs + six CommandSpecs | Sources/SuiteKernel/Stroke/BrushKeys.swift, Sources/SuiteKernel/Stroke/BrushKeyCommands.swift | CommandShapeTests | #4057 66acfc5a | merged |
| BK-2 | BK-a | 1 | disabled BrushKeysTests | Tests/SuiteKernelTests/BrushKeysTests.swift | BrushKeysTests (disabled) | #4057 | merged |
| BK-3 | BK-m | 2 | bodies + plan SuiteKernel.BrushKeys | Sources/SuiteKernel/Stroke/BrushKeys.swift, Tests/SuiteKernelTests/BrushKeysTests.swift, Tests/mutations/SuiteKernel.BrushKeys.json | BrushKeysTests; mutate (5/5) | #4058 4987a228 | merged |
| BK-4 | BK-m | 2 | C4 part kernel-stroke | docs/c4/parts/creative-apps/suite-kernel/kernel-stroke.json | scripts/ci C4 | #4060 merged fb6f4b83 (docs-only; existing part description can only change in a docs-only PR) | merged |

## Wire
- [ ] Wire: anchor-parenting:AN-u (BK-u shares SuiteUI files)
- [ ] Wire: anchor-parenting:AN-flare-u (BK-flare)
- [ ] Wire: area-selection:AR-photo-u (BK-photo)
- [ ] Wire: orientation-crop:OC-photo-m (BK-photo)
- [ ] Wire: document-setup:DS-design (BK-design)

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- 2026-10-21T11:26Z: one PR per slice (brief rule 8): BK-1+BK-2 ship as the BK-a PR; BK-3+BK-4 as BK-m stacked on it.
- 2026-10-21T11:26Z: app slices start only when their external waits clear; their test-first tasks (BK-7, BK-9, BK-11) ride in the slice PR, not alone.
- 2026-10-21T11:26Z: anchor-parenting, document-setup and area-selection have no lead branch or issue: BK-u and every app slice are blocked on them.
- 2026-10-23T15:25Z (act-1a16958d72f-a4mg): contract-first waits (lead.md rule 12, #4814): a wait on another feature is met once that feature's first slice merged; each wait built ahead of its slice is listed under Wire. Merged-done = green `Linux` on a dev CI run containing the slice's last PR.

## Open
- BK-u blocked: anchor-parenting:AN-u (feature not started).

- 2026-10-26T13:39:43Z (act-1a177ff0916-4jm7): 13:39Z poll: dev 01600e46; dev-red #5321 still open (not ours); no merges of ours. BK-u #4939 fast-lane, queued; #4965/#4961/#4982 keep needs-split until #4939 lands (then merge dev, gate, move Head, drop needs-split). Next: unchanged. No needs-fix/needs-rebase; 0 findings.
- 2026-10-26T14:04:02Z (act-1a177ff0916-4jm7): 14:04Z poll: dev 68be32fc; dev-red #5321 open (linux, range not ours); no merges of ours; #4939 queued. Drift #5745 (finding, 7 items): items 1-5 are BK-u #4939 and the BK app PRs #4965/#4961/#4982 (open); items 6-7 are packet drift: corrected the packet to BrushKeyTarget: Sendable (mutating, layerOpacityHelp) and specs(_:) on lead/brush-keys-drift-5745, gating, then a docs-only PR. Open findings 1.
- 2026-10-26T14:05Z (act-1a177ff0916-4jm7): poll: dev 68be32fc; drift #5745 items 6-7: packet fix PR #5799 (docs-only, fast-lane; no swift here so lane Linux check is the proof); items 1-5 ride #4939/#4965/#4961/#4982. None merged yet; open findings 1.
- 2026-10-26T14:27Z (act-1a177ff0916-4jm7): poll: dev 68be32fc; no merges; #4939 and packet fix #5799 queued in lane (dev-red #5321 open, lane check on #5799 pending). Open findings 1.
- 2026-10-26T14:45Z (act-1a177ff0916-4jm7): poll: dev f86f72f7; no merges of ours (dev moved by #5780 only); #4939 and packet fix #5799 queued, lane check on #5799 not started; dev-red #5321 open. Open findings 1.
- 2026-10-26T15:02Z (act-1a177ff0916-4jm7): poll: dev f86f72f7; no merges of ours; lane Linux check on packet fix #5799 running (run 40343265441); #4939 queued; dev-red #5321 open. Open findings 1.
- 2026-10-26T15:21Z (act-1a177ff0916-4jm7): poll: dev f86f72f7; no merges of ours; #5799 (packet drift fix for #5745) lane Linux check passed (run 40343265441), attribution footer removed from its body and the #5745 comment; awaiting lane sweep; dev-red #5321 open
- 2026-10-26T15:39Z (act-1a177ff0916-4jm7): poll: dev 310d7d14; no merges of ours; #5799 clean with green lane Linux check, awaiting lane sweep; #4939 open; dev-red #5321 open
- 2026-10-26T15:56Z (act-1a177ff0916-4jm7): poll: dev 310d7d14; no merges of ours, dev unchanged; #5799 clean with green lane Linux check, awaiting lane sweep; #4939 open; dev-red #5321 open
- 2026-10-26T16:16Z (act-1a177ff0916-4jm7): poll: dev e14f65fa; no merges of ours; #4939 and #5799 open, clean, in the lane queue; dev-red #5321 open
- 2026-10-26T16:33Z (act-1a177ff0916-4jm7): poll: dev 527676af; no merges of ours; #4939 and #5799 await the lane; dev-red #5321 last seen open
