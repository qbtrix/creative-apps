# Photo v1

Photo v1 is the first build of the raster editor meant for daily use. It
covers the tier-1 jobs in `docs/priorities.md`: open, save and export; crop,
straighten and resize; the tone tools; undo, redo, zoom and pan; and basic
layers. This page says what works, how each part is tested, what the quality
bar measures today, and how to get the app.

## Get it

Every green `CI` run on `dev` uploads the release builds as the `app-builds`
artifact.

```bash
gh run list -R qbtrix/creative-apps --workflow ci.yml --branch dev --status success --limit 1
gh run download <run-id> -R qbtrix/creative-apps -n app-builds
tar xzf app-builds.tar.gz && open PhotoApp.app
```

The bundle is ad-hoc signed and needs macOS 26. If you fetch the artifact
through a browser instead of `gh`, macOS quarantines it: Control-click the app
and choose Open once, or run `xattr -dr com.apple.quarantine PhotoApp.app`.

Photo's sign-off run is
[38474121045](https://github.com/qbtrix/creative-apps/actions/runs/38474121045),
on dev 27b304a with the Studio restyle in. All twelve Photo journeys pass
there, and its `app-builds` artifact holds `PhotoApp.app`. That run's macOS job
is still red, but only for Design's audit counts (#576), so `main` hasn't
moved yet. Once #576 is fixed, use the newest green run instead. The
download steps are the same:

```bash
gh run download 38474121045 -R qbtrix/creative-apps -n app-builds
```

## What works

Each tier-1 job is a UI journey in `UITests/PhotoJourneyTests.swift`. A
journey launches the release bundle, works it like a person (menus, keys,
drags, typing), checks the result of every step, and takes a whole-window
screenshot after each one. Every screenshot runs the app audit
(`docs/blueprints/app-audit.md`).

| Job | What you can do | Journey |
|---|---|---|
| Open, save, export | Open a PNG, JPEG or HEIC (File > Open, drop on the canvas). Save writes back to the file; Save As (Shift-Command-S) picks a new one. Export as PNG or JPEG with a quality slider. | `testOpenImagePaintAndSave`, `testSaveAsAndActualSize` |
| Crop, straighten, resize | Crop tool (C) with Apply on Return. Image > Straighten… turns by -45 to 45 degrees with a live preview, a grid and Crop to Fit. Image Size with kept proportions. Rotate by quarter turns. | `testTier1CropResize`, `testStraighten`, `testEveryToolEditsTheImage` |
| Tone | Exposure, Levels, Curves (a point editor over the histogram) and Hue/Saturation, each with an enable switch and Reset. Levels, Curves and the histogram work on display values, so 0.5 is the grey halfway between black and white. | `testTier1Tone`, `testCurvesDragAndNudge` |
| Undo, redo, zoom, pan | Every edit is one named undo step (Edit menu and top bar). Zoom In, Zoom Out, Actual Size (Command-1), Fit (Command-0), pinch. Pan with the trackpad or wheel, Space-drag (pan mode only while Space is held), or the arrow keys. | `testTier1UndoRedoZoomPan`, `testSaveAsAndActualSize` |
| Layers | New, delete, rename, show and hide, opacity, blend mode, reorder (Bring Forward and Send Backward, Command-] and Command-[), and select from the keyboard (Option-Command-] and [). | `testTier1Layers` |

The model logic behind each job has Linux tests in `Tests/PhotoModelTests`
(for example `PhotoStraightenTests`, `PhotoCurvesTests`,
`PhotoToneDisplayValuesTests`, `PhotoSaveAsTests`). The engine work is in
creative-core: `rotated(degrees:filter:)` and `straightenCrop` (Rotate.swift),
and levels, curves and histograms on sRGB-encoded values (`ToneEncoding`).

## Quality bar (docs/review-rubric.md, section 6)

What is measured today, and what isn't yet:

| Row | Status |
|---|---|
| QB-F1 no dead controls | Measured: `PhotoToolsTests` and the every-tool journey. |
| QB-F3 one gesture, one named undo step | Measured: every edit's undo name is asserted in the journeys, and the model tests count steps. Canvas tools, crop, Image Size, Straighten and the layer commands are one step each. A Curves drag, nudge or delete, and a drag, key step or typed value on any tone or layer Opacity slider, closes its step when the gesture ends (`endAdjust`, #540 and #523). |
| QB-F4 keyboard parity | Tools have one-key shortcuts; zoom, layer order and selection, Save As and pan have keys; slider values can be typed; curve points nudge with the arrows. Export's JPEG quality is slider-only. |
| QB-L1, QB-L2 latency | Report-only. Photo has no frame-probe perf journey yet, so no CI gate. The heavy operations stay off the main thread: Straighten applies in the background behind a "Straightening…" note, and the Curves histogram is counted in the background only when its input changes. |
| QB-L9 progress for waits | Export, Save and Straighten show a note while they run. |
| QB-V2, QB-V5 goldens | Not built (#332). Snapshots in `Tests/AppSnapshotTests` are PNGs for eyes; the journeys' screenshots are on the contact sheet. |
| QB-F5 Increase Contrast | The tone curve well draws an outline. The snapshot host can't render the Increase Contrast token colors yet. |
| App audit | Photo's counts on the sign-off run: identifier 28, overlap 0, and 0 for unnamed, contrast, offscreen and disabled-dim. The baseline before v1 was identifier 53 and overlap 1; CI lowers it on the next green dev run. |

## Known gaps

Filed and not part of v1:

- #580 adjustment layers (tier 1's layers line goes past basic layers): the
  adjustments apply to the whole image.
- #544 type the crop size and lock its ratio.
- #545 a clicked layer row's focused highlight fails contrast; the journey
  selects layers by key.
- #575 Command-A in a sheet's text field selects the canvas.
- #289 the controls still missing accessibility identifiers live in SuiteUI
  and the adjustments inspector.
- #255 a Levels field opens its draft at two decimals (cosmetic now; #525
  fixed the value change).
