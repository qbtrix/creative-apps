# inspector-timeline lead record

Issue: #1515 · Packet: docs/blueprints/flare/features/inspector-timeline.md
Run: act-1a14a13ca4f-74rv (line lead for draw-key-save, layers-files, inspector-timeline; earlier run act-1a146828a2d-9sza) · Session: session_01NXMovyJtKvANXKD2WWypB3 · Started: 2026-10-16T18:20Z (resumed 2026-10-17)
Stage: 3 build (wave 1)
Base: d2c4fa212a4b4ea55bc551b783fc1c48520e5fbf (origin/dev)
Next: wave 1 (IT-0, IT-9a) building with layers-files wave 1 alongside; then wave 2 (IT-1..IT-4)

## Slices
No `## Slices` table: v2 packet, v2 loop applies.

## Tasks
| Task | Wave | Files | What | PR | State |
|---|---|---|---|---|---|
| IT-0 | 1 | FlareInspectorRead, FlarePaint, FlareTimelineEdit (Model, stubs), FlareWorkspace.swift + Tests | rule 18 stubs: every IT-1..IT-3 signature, fake value or NotBuilt; stored state cleared in load | | building |
| IT-9a | 1 | FlareStatusRead + Tests, PlaybackDriver(+Tests), ViewerStatusBar pills in FlareWindow, +Playback | StatusPills, measuredFPS, J10 | | building |
| IT-1 | 2 | FlareInspectorRead + Tests | inspectorSummary for real | | |
| IT-2 | 2 | FlarePaint + Tests | paint readout and setters for real (no FlareWorkspace edit, IT-0 owns it) | | |
| IT-3 | 2 | FlareTimelineEdit + Tests | key select, retime, delete, insert/remove frames, labels for real | | |
| IT-4 | 2 | FlareInspector, Transform/Fill/Scene/Timing sections, +Inspector | Properties tab on the stubs, J7 | | |
| IT-5 | 3 | FlareInspectorFill, FlareFillSnapshots, +FillStroke | J8 | | |
| IT-6 | 3 | FlareInspectorScene, FlareSceneSnapshots, +SceneInspector | | | |
| IT-7 | 3 | FlareTimelineEdit (App), FlareTimeline, FlareWindow+Timeline, +TimelineEdit | J11 | | |
| IT-8 | 3 | FlareInspectorTiming, FlareEasingPopover, delete FlareEasingInspector, +Easing | J12 | | |
| IT-9b | 3 | TransportCapsule | waits #340; gap if still open at wave 4 | | waiting |
| IT-10 | 4 | +Timeline, +Animate, packet, wave.json | feature-done, J9/J6 on -FlareSample | | |

## Reviews
None.

## Decisions
- Waves merged with layers-files into one plan (rule 19): w1 IT-0, IT-9a | LF-1, LF-3, LF-4, LF-5; w2 IT-1..IT-4 | LF-1d/LF-2 if #146/#73 closed; w3 IT-5..IT-8; w4 IT-10 | LF-6.
- Rule 18: IT-0 stubs the Model calls (and owns the FlareWorkspace.swift stored state) so IT-1..IT-4 run in parallel in wave 2 and IT-3 no longer waits on IT-2.
- IT-9 split: IT-9a (status read, measured fps, pills in the existing ViewerStatusBar, J10) now; IT-9b (TransportCapsule) waits on SuiteUI #340.
- Rule 20: the new files are adapters onto creative-core FlareCore services (AnimateContracts: KeyRef, moveKeys, removeKeys, insertFrames, removeFrames, setLabel, setFill, setStroke); key selection is a thin selectedKeys set that adopt-kernel-selection (#1935) and easing (#1937) migrate later. No file name hits Tests/canonical-concepts.txt.
- Depends on draw-key-save is met: its wave.json says built, feature-done #1738 merged, and this run's lead owns all three features; #1365 stays open only until its contact sheet (lane turns Closes into Refs for feature-lead issues).
- PR base is dev (CLAUDE.md: never target main), builder branches lead/<feature>-<id>.
- Stopped at stage 0: `Depends on: draw-key-save`, and #1365 is open (draw-key-save.wave.json status `planned`).
- Status is pushed to the designated branch claude/feature-lead-flare-line-yzaus7, not lead/inspector-timeline, per the session's branch rule.

## Open
- #340 (TransportCapsule) open: IT-9b waits; becomes a gap if still open at wave 4.
