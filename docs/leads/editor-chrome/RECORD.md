# editor-chrome lead record

Issue: #1344 · Packet: docs/blueprints/suiteui/features/editor-chrome.md
Run: act-1a1504abd7d-2wty (line lead with #1344, #1512, #1510; took over from act-1a14d48ae2f-857a)
Stage: 4 review (fix round 2 open)
Base: 2e27b8db (origin/dev)
Next: #2941 (EC-b round 2, fixes #2831) in the lane; then a scoped suiteui run: if the gallery and chrome journeys pass, Belt-Contact-Sheet on #1344, else the rest become gap issues

## Slices
| slice | tasks | journeys | waits on | state |
|---|---|---|---|---|
| EC-a (contract) | EC-1, EC-4, EC-7 | ChromeFakeTests, SuiteEmptyStateSnapshots, SuiteTabsSnapshots | – | code complete; critics wait on a scoped suiteui run |
| EC-b (ui) | EC-5a, EC-6a, EC-9, EC-11 | SJ5, SJ6, SJ7, SJ8, SP9 | EC-a | building (EC-5a, EC-6a open) |
| EC-c (logic) | EC-5b, EC-6b, EC-8b | TransportTests, StatusPillTests, ToolPickingTests | EC-a | code complete (#2674-#2676 open) |
| EC-d (integrate) | EC-8, EC-10, EC-12, EC-13 | SJ4 | EC-b, EC-c | planned |

## Tasks
| id | slice | wave | behavior | test | PR | state |
|---|---|---|---|---|---|---|
| EC-1 | EC-a | 1 | three contracts, Fakes, three rules as stubs | ChromeFakeTests | #2609 | merged |
| EC-4 | EC-a | 1 | empty state's primary button | SuiteEmptyStateSnapshots | #2607 | merged |
| EC-7 | EC-a | 1 | capsule tabs, still a Picker | SuiteTabsSnapshots | #2608 | merged |
| EC-5a | EC-b | 2 (first) | TransportCapsule on the gallery editor page | SuiteTransportSnapshots | #2672 | open, gated |
| EC-6a | EC-b | 2 | ViewerStatusBar over StatusPillComposing | SuiteStatusSnapshots | #2673 | open, gated |
| EC-5b | EC-c | 2 | SuiteTransport live: wrap, clamp, seconds:frames | TransportTests | #2674 | open, gated |
| EC-6b | EC-c | 2 | SuiteStatusPills live: "–" for a non-number zoom | StatusPillTests | #2675 | open, gated |
| EC-8b | EC-c | 2 | SuiteToolPicking live | ToolPickingTests | #2676 | open, gated |
| EC-9 | EC-b | 3 | gallery editor and empty pages; editor-plain removed | SuiteGalleryTests | – | planned |
| EC-12 | EC-d | 3 | goldens: transport, pills, empty | Golden checks | – | planned |
| EC-11 | EC-b | 4 | SJ5–SJ8, SP9 | journeys | – | planned |
| EC-8 | EC-d | 4 | .floating palette picks through SuiteToolPicking (MAC_GATED) | ToolbarPickingTests | – | planned |
| EC-10 | EC-d | 5 | SJ4 | journey | – | planned |
| EC-13 | EC-d | 6 | goldens: tabs, palette; feature-done | Golden checks | – | planned |

## Reviews
| slice | run | commit | lenses | filed | after round |
|---|---|---|---|---|---|

## Decisions
- Rescoped per the captain's 2026-10-17 comment on #1344, in one docs-tier fast-lane PR (#2554): dropped ShellLayingOut, EC-2, EC-3, the EditorTopBar half of EC-4, rail colours, editor-plain, SJ1–SJ3, SP10 and the shell/top-bar goldens.
- v3 loop: the packet now has a Slices table. EC-4 and EC-7 ride in the contract slice (they restyle existing views and need no contract) so the waves rules (2–5 tasks, a journey per slice) hold and EC-9/EC-11 find them in place.
- Rule 20: SuiteTransport follows FlarePlayback's stepping and seconds:frames timecode; TransportFace gains timecodeHelp.
- editor-shell-removal.wave.json gains depends: [editor-chrome] (both own ToolbarGroup.swift); editor-chrome depends on suite-harness (built).
- PRs target dev, not main: the lane retargets main to dev and CLAUDE.md forbids main.
- Critic panel includes the first-use clarity lens (what each number and label means to someone new), per the brief. Anatomy loop stops after 2 clean rounds or 4 total.
- #342 (timeline slot) is moot under the one shell; closed as not planned once #2554 merges.

- 2026-10-18T05:30Z: wave 1 PRs #2607, #2608 (merged) and #2609, #2610 (open) were opened by the stalled earlier session (Belt-Lead act-1a14d1f3122-r1yb, disconnected since 04:59Z). This run adopts them rather than opening duplicates. A gate push briefly overwrote their heads; they were restored to the exact heads their Head: lines name.

## Open
- #2554 merged into dev; #342 closed as not planned.
- 2026-10-18T04:35Z: the 03:54Z wave-1 builders of run act-1a14d17c86c-d1qr opened no PR and pushed no branch in 40 min; this run relaunches EC-1, EC-4, EC-7 on d3a4f16e. Swift 6.3.3 is installing via scripts/cloud-setup.sh for the gate.
- 2026-10-18T04:36Z: run act-1a14d48ae2f-857a took over; no wave-1 PR or task branch existed from earlier runs. Swift 6.3.3 installed; wave 1 relaunched on e01529f4 through build-wave.js.

- 2026-10-18T09:53Z: EC-6b #2675 failed its macOS build on a duplicate top-level @Test name; renamed (5191426b), regating, Head line follows.

- 2026-10-18T09:58Z: wave 4 started ahead of the lane: EC-11 (lead/editor-chrome-EC-11, on EC-9) and EC-8 (lead/editor-chrome-EC-8, on EC-9 + EC-8b).

- 2026-10-18T10:06Z: EC-11 built (journeys SJ5 to SJ8, press series SP9). EC-9 conflicted with dev (#2697's min-height header in SuiteGalleryTests); the conflict was resolved by merging the comments, and EC-9 is now be2d0bfc on dev ca6c45b7. EC-11 d19883a6 and EC-8 bb619d32 are restacked on it, and all three are gating.

- 2026-10-18T10:07Z: #2672 (EC-5a) got needs-fix from the new view-statics lint (scripts/check-view-statics, dev): `TransportCapsule.timecodeParts` is an unmarked static on a View. The fix marks it `nonisolated` (e34d8d3b on EC-5a; the same commit tops the EC-9, EC-8 and EC-11 stacks). The EC-9, EC-8 and EC-11 gates had failed on the same lint. All are regating. The other lead branches pass the lint against dev.
- 2026-10-18T10:11Z: gates PASS. #2672 Head 7956bfe0 (body updated). The stacked branches passed as well: EC-9 8a36fd24, EC-8 4ea49a32, EC-11 14cc5187.
- 2026-10-18T11:25Z: EC-9 (e2f96351), EC-11 (06544a7f) and EC-8 (7dc240fc) restacked on EC-5a's bda1546c, gated PASS and pushed. Their PRs open once #2672 merges (EC-9 first; EC-8 is MAC_GATED via ToolbarGroup).
- 2026-10-18T12:14Z: EC-5a #2672 merged. Once it squashed, EC-9 was rebuilt as a single commit on dev (fd7211ef) and is gating; its PR opens on PASS. EC-11 and EC-8 get rebuilt the same way once EC-9 merges.
- 2026-10-18T12:15Z: EC-9 opened as #2769 (Head b290bce7). EC-11 and EC-8 follow once it merges.
- 2026-10-18T12:57Z: EC-9 #2769 merged. EC-11 and EC-8 rebuilt as one commit each on dev and gated PASS. EC-11 opened as #2788 (Head d12ac10c, slice EC-b). EC-8 opened as #2789 (Head 6869034c, slice EC-d); it is MAC_GATED through ToolbarGroup, so the lane's macOS run is its proof. Next: EC-10 once EC-8 merges, and EC-12 once a CI run carries EC-5a, EC-6a and EC-4 actuals.

## 2026-10-18T13:45Z stage 4 build
- EC-8 #2789 merged to dev.
- EC-10 (SJ4 tool palette journey) gated c373cabe and opened as #2798. Its key step depends on the palette having focus after a click; if that fails on macOS, it becomes a finding against EC-8.
- Waiting on the lane: #2788 (EC-11). Next: EC-12 once a CI run carries the EC-5a, EC-6a and EC-4 actuals; then EC-13 (feature-done).

## 2026-10-18T13:48Z stage 4 build
- EC-11 #2788 merged to dev. Open: #2798 (EC-10). Left: EC-12 (needs CI actuals), EC-13.

## 2026-10-18T14:04Z stage 4 build
- EC-10 #2798 merged to dev. Left: EC-12, from the actuals of the scoped suiteui run 39133362138 at 3f5ae7f3 (in progress); then EC-13 (feature-done).
- 2026-10-18T14:19:36Z EC-a: fix-open #2807. Tabs fade pair closes itself (#2805 SegmentedTabs half); EC-12/EC-13 wait on a green run with artifacts after #2806.
- 2026-10-18T14:36:12Z goldens: link fix #2806 merged (624c4291, #2801 closed). Waiting on a dev run including it for actuals.
- 2026-10-18T14:40:32Z EC-a: fix-building #2807. Lane dispatched the macOS build for #2807; EC-12/EC-13 wait on a dev run including 624c4291.
- 2026-10-18T14:47:47Z EC-a: tabs fade fix #2807 merged. Proof: aTabChangeRecordsAFadePair on the next scoped suiteui run. EC-12/EC-13 wait on a dev run with actuals.
- 2026-10-18T15:02:15Z goldens: waiting 39137893783. CI 39137279211 (80c14eed) and scoped suiteui 39137893783 (04170953, has #2807) queued/running; EC-12 starts from their artifacts.
- 2026-10-18T15:24:08Z goldens: waiting 39137893783. Scoped suiteui and full CI both in the journeys step past bundle-apps; EC-12 starts from the artifacts.
- 2026-10-18T15:46:09Z goldens: waiting 39137893783. Scoped suiteui at its Findings step, full CI still in journeys (snapshots uploaded); goldens start from ui-screens.
- 2026-10-18T16:13:31Z EC-a: round 2 open (#2841) fade-end on a run-loop Timer; restores #2807, which #2818 (a Halo PR) reverted
- 2026-10-18T16:13:31Z triage: run 39137893783 triaged (04170953) SJ4, SJ7, gallery audit are mine; SP9 empty because the chip probe merged after (#2816), recheck next run
- 2026-10-18T16:13:31Z findings: filed (#2844 #2845 #2846) palette focus (EC-d), tabs keys + segment ids (EC-b), switch labels (EC-b); fixes gating
- 2026-10-18T16:15:40Z EC-a merged #2841 tabs fade pair on a Timer; fixes #2844-#2846 gating; dev runs 39143942767 (CI) and 39143178581 (scoped suiteui) pending
- 2026-10-18T16:20:27Z fix round 1 PRs open #2853 #2854 #2855 palette focus (EC-d), tabs keys + segment ids (EC-b), switch labels (EC-b); gate PASS
