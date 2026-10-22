# Feature packet: adopt-kernel-eyedropper-photo

**Feature:** after photo/eyedropper makes Photo's Eyedropper work, Photo
keeps one sampling path: the kernel's. Photo's own `ColorSampling` contract,
its `SampledColor` type, its fake sampler, the square-clipping math in
`PhotoEyedropper.swift` and the `LiveSampling` service go; a click and
`color.sample` both call `SampleRules.mean` through `PhotoSample+Kernel.swift`
and set the brush from the kernel's `FillColor`.
**Line:** `line:suiteui` · **Wave:** XK3 (`waves.md`, the canonical burn-down) · **Lead branch:** `lead/adopt-kernel-eyedropper-photo`
**Beta:** captain, 2026-10-20 (canonical burn-down, audit rank 14). Labels `beta` and `p2` when filed.

**Covers:** the canonical duplicates audit
(`paw-workspace/docs/design/drafts/2026-10-20-canonical-duplicates-audit.md`),
top-15 #14; feature map row `suiteui/adopt-kernel-eyedropper-photo`; real job
RJ-X49 (new).

**Most of audit #14 is already planned.** photo/eyedropper (beta, wave 3,
`line:photo`) fills PV-9: the live `ColorSampling` body becomes
`SampleRules.mean`, the tool gets SuiteUI's `SampleLoupe` and
`SampleSizeChips`, and `color.sample` is registered. That packet keeps
Photo's `ColorSampling` protocol as an adapter. This packet is only the
remainder: one sampling contract instead of two. It is small (two slices) and
starts after PE-z; if photo/eyedropper is re-cut to drop the protocol itself,
this packet closes with nothing to do.

**Depends on:** photo/eyedropper PE-z (cross-line). editor-kernel (built:
`SampleRules`, `SampleTarget`, `FillColor`). adopt-kernel-export's AX-photo
also edits `OutputContracts.swift` (EP-2 waits on it).

**Rule 20.** One sampler (`SampleRules.mean`), one colour (`FillColor`), one
target protocol (`SampleTarget`). The adapter `PhotoSample+Kernel.swift`
(photo/eyedropper's) is the only Photo sampling file left.

**Deleted app-local files:** `Sources/PhotoModel/PhotoEyedropper.swift` and
`Sources/PhotoModel/Live/LiveSampling.swift`, with `LiveSamplingTests.swift`
and `Tests/mutations/PhotoModel.LiveSampling.json` (EP-3), and the
`ColorSampling` protocol, `SampledColor` and `FakeSampling` inside
`OutputContracts.swift` and `FakeOutput.swift` (EP-2). EP-3 runs
`scripts/check-dup-logic --update-baseline` in the same PR so
`Tests/canonical-baseline.txt` drops the two files' lines (#3642's
"Eyedropper" concept).

**Clean-room.** The kernel's own sampling rule; Photo's existing tests.

Blueprint sections: photo.md 5 (tools).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| EP-m | A click and `color.sample` both read `SampleRules.mean` through Photo's kernel adapter, at the image edge too, and Photo's own sampling contract, colour type and fake are gone. | EP-1, EP-2 | MJ-EP | photo/eyedropper PE-z (cross-line); adopt-kernel-export:AX-photo (EP-2, `OutputContracts.swift`); adopt-kernel-brush:AB-photo (EP-2, `PhotoStroke.swift`) |
| EP-z | `PhotoEyedropper.swift` and `LiveSampling.swift` are deleted with the baseline shrunk, the Eyedropper journey stays green, and the feature is built. | EP-3, EP-4 | MJ-EP, PJ-EP | EP-m; adopt-kernel-unsaved-prompt:UP-z (EP-3, `canonical-baseline.txt`, A/C first) |

No new screen (`"ui_slice": "none"`): the tool's UI is photo/eyedropper's.

**Shared-file chain:** `Tests/canonical-baseline.txt`:
adopt-kernel-unsaved-prompt UP-z → EP-3 → suite-imaging IM-8d.

## Journey steps

- `MJ-EP` (EP-1, Linux): `PhotoSampleKernelTests`: for each sample size, a
  click at the centre, at a corner and one pixel past the edge gives
  `SampleRules.mean`'s colour, the same as `color.sample`; past the edge
  changes nothing.
- `PJ-EP` (`PhotoEyedropperJourneyTests.testPickSkyColor`, photo/eyedropper's):
  green unchanged after EP-3.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-X49 | adds, closes with `suiteui/adopt-kernel-eyedropper-photo` | C | `Tests/RealJobs/photo/sample-edge/sample-edge.jobs.json`: `file.open` the fixture, `tool.eyedropper`, `color.sample {"x": 0, "y": 0, "size": 5}`, then the same at the centre | `input/checker-red-blue.png` |

Trap: Photo's own square math counts the off-image pixels of a 5 × 5 square
at the corner as black, so the corner reads darker than the kernel's mean.
Assertion: the corner reads the mean of its 9 in-image pixels (`#FF0000`
on the red corner), and the centre reads the 25-pixel mean, both equal to
`SampleRules.mean`'s hex. Mutations: `PhotoModel.PhotoSample+Kernel.json`
(off-image pixels read as black → `.edgeSkipsOffImage`; size ignored →
`.sizeHonoured`). Written by EP-1 (`waits_on: EP-1`); it passes once EP-2 lands.

## Screens and states

None new. photo/eyedropper's `photo-eyedropper-*` shots must not change.

## Contract slice

Nothing new: the kernel's `SampleRules.mean(x:y:size:read:) -> FillColor?` and
`SampleTarget`, and photo/eyedropper's `extension PhotoWorkspace: SampleTarget`
in `PhotoSample+Kernel.swift`. What goes:

```swift
// Sources/PhotoModel/Contracts/OutputContracts.swift (EP-2 removes)
public protocol ColorSampling: PhotoUseCase { func sample(_ picture: PixelBuffer, center: (x: Int, y: Int), size: SampleSize) -> SampledColor? }
public struct SampledColor { ... }
// Sources/PhotoModel/PhotoServices.swift (EP-2 removes the `sampling` member)
```

## Pseudocode

- **Click.** `sampleDrag(at:)` moves into `PhotoSample+Kernel.swift`:
  round the point down, build a reader over the composite's visible tile
  (photo/eyedropper's), call `SampleRules.mean(x:y:size:read:)` (which skips
  off-image and transparent pixels), and set the brush colour from the
  `FillColor`. No undo step, as before.
- **Services.** `PhotoServices.sampling` goes: the kernel's mean is pure, so
  no live or fake service stands in front of it.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| EP-1 | – | **Tests first.** `PhotoSampleKernelTests`, disabled (`waits on EP-2`); RJ-X49's job folder | `Tests/PhotoModelTests/PhotoSampleKernelTests.swift`, `Tests/RealJobs/photo/sample-edge/sample-edge.jobs.json`, `Tests/RealJobs/photo/sample-edge/input/checker-red-blue.png`, `Tests/mutations/PhotoModel.PhotoSample+Kernel.json` | photo/eyedropper PE-z | ~180, 4 |
| EP-2 | – | **One path.** `sampleDrag` on `SampleRules.mean` in `PhotoSample+Kernel.swift`; `ColorSampling`, `SampledColor`, `FakeSampling` and `PhotoServices.sampling` removed; turns on `PhotoSampleKernelTests` | `Sources/PhotoModel/PhotoSample+Kernel.swift`, `Sources/PhotoModel/Contracts/OutputContracts.swift`, `Sources/PhotoModel/Fakes/FakeOutput.swift`, `Sources/PhotoModel/PhotoServices.swift`, `Sources/PhotoModel/PhotoStroke.swift`, `Tests/PhotoModelTests/PhotoSampleKernelTests.swift`, `Tests/PhotoModelTests/PhotoSampleTests.swift`, `Tests/mutations/PhotoModel.PhotoSample+Kernel.json` | EP-1 | ~260, 8 |
| EP-3 | – | **Delete.** `PhotoEyedropper.swift`, `Live/LiveSampling.swift`, `LiveSamplingTests.swift`, `PhotoModel.LiveSampling.json` and `NotBuilt`'s sampler entry; `scripts/check-dup-logic --update-baseline` drops the two files' lines | `Sources/PhotoModel/PhotoEyedropper.swift`, `Sources/PhotoModel/Live/LiveSampling.swift`, `Sources/PhotoModel/Live/NotBuilt.swift`, `Tests/PhotoModelTests/LiveSamplingTests.swift`, `Tests/mutations/PhotoModel.LiveSampling.json`, `Tests/canonical-baseline.txt` | EP-2 | ~150, 6 |
| EP-4 | – | `status: built`; `feature-done` | `docs/blueprints/suiteui/features/adopt-kernel-eyedropper-photo.wave.json` | EP-3 | ~10, 1 |

## Build waves

- Wave 1: EP-1. Independent in this wave: EP-1 alone.
- Wave 2: EP-2. Independent in this wave: EP-2 alone.
- Wave 3: EP-3. Independent in this wave: EP-3 alone.
- Wave 4: EP-4. Independent in this wave: EP-4 alone.

Longest chain: EP-1 → EP-2 → EP-3 → EP-4 (4). Chain of 4: the test before the path it checks, the path before the files it replaces can go, and the status task last; each link edits or deletes what the one before replaced.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| EP-1 | compiles, disabled by name; `scripts/jobs check` | – | – (tests; EP-2 fills the plan's entries) |
| EP-2 | `PhotoSampleKernelTests`; Photo's existing Model tests unchanged but `PhotoSampleTests`' fake-service cases, which move to the kernel path; RJ-X49 on Linux | a click and `color.sample` disagree, or the edge reads off-image pixels | `PhotoModel.PhotoSample+Kernel`: off-image pixels read as black → `.edgeSkipsOffImage`; size ignored → `.sizeHonoured` |
| EP-3 | Photo's Model tests; `scripts/check-dup-logic`; `scripts/mutate --validate`; `PJ-EP` on the scoped run | a deleted symbol is referenced, or the baseline names a gone file | – (deletion) |
| EP-4 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| one sampler | no averaging code under `Sources/PhotoModel/` outside the kernel adapter | `scripts/check-dup-logic` (the Eyedropper concept, baseline shrunk) |
| same colour by click and by command | identical hex at the centre, a corner and the edge | `PhotoSampleKernelTests`, RJ-X49 |
| behaviour preserved | photo/eyedropper's journey and snapshots unchanged | `PJ-EP` |

## Done check

EP-m green on the Linux job with `Mutate:` clean and RJ-X49 green; EP-z with
the two files gone, the baseline shrunk and `PJ-EP` green on the scoped run.
No contact sheet: no screen changes.
