# Feature packet: export-pack (Library)

**Feature:** Library's Export sheet gets the shared Metadata row: All, All
but location (the default) or None. Exports now carry the original's camera
details, capture date and copyright (they carry nothing today), minus what
the policy drops: under All but location no GPS, no body or lens serial, no
maker note, in the JPEG, the HEIC and the XMP sidecar alike.
**Line:** `line:library` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/export-pack`
**Beta:** captain, 2026-10-20 (everyday gaps audit: "export without
location", RJ-L16 high, no plan before). Labels `beta` and `p1` when filed.

**Covers:** feature map `library/export-pack` (adopter of S11); real jobs
RJ-L16 (export for sharing without location) and RJ-X03 (privacy: no GPS in
the JPEG, the HEIC or the sidecar).

**Depends on:** `suiteui/export-pack` **XP-a** (cross-line: `ExportMetadata`,
`ExportRules.dropped`, `MetadataCarrying`); LX-3 needs **XP-6**, LX-4
**XP-7** (the live copy). Same line: `export` (planned, wave 4) owns
`LibraryContracts.swift`, `ExportSidecar.swift`, `LiveExporter.swift`,
`JPEGWriter.swift` and the sheet, so every slice waits on it.

**Rule 20.** No Library metadata rule: the policy is `ExportMetadata`, the
tags are `ExportRules.dropped`, and the copy is `services.metadata`.

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| LX-a | Library's export options hold a metadata policy (default All but location) on stubs, and the sheet shows the shared Metadata row. | LX-1, LX-2 | MX-LX | XP-a (cross-line); export |
| LX-u | The sheet has snapshots and a render budget, and the journey is written. | LX-5, LX-6 | LJ-X1 | LX-a |
| LX-m | The sidecar leaves out what the policy drops, and the writer carries the original's metadata minus the dropped tags into JPEG and HEIC. | LX-3, LX-4 | MX-LX, `LibraryExportMetadataWriteTests` (macOS) | LX-a; XP-6, XP-7 (cross-line) |
| LX-z | Export without location runs on live services, the journey passes, and the feature is built. | LX-7, LX-8 | LJ-X1 | LX-u, LX-m |

LX-u waits only on LX-a (rule 18); LX-m never waits on LX-u. LX-m is marked `"ui": true` because LX-4 changes `JPEGWriter` in LibraryApp. MX-LX is the Model walk in `LibraryExportMetadataTests` (Linux).

## Journey steps

1. Import the GPS-tagged phone sample, select it, File > Export… (LX-2,
   `LibraryExportPackJourneyTests.testExportWithoutLocation`): Metadata reads
   All but location.
2. Turn Write Sidecar on, Export: the JPEG and its `.xmp` are written.
3. Get Info on the JPEG (the test reads its properties): camera model and
   capture date present, no GPS.
4. Export again with None: neither file has a capture date.

## Jobs

| job | closes or adds | run | check | fixture |
|---|---|---|---|---|
| RJ-L16 | closes (now `library/export-pack`) | Cm | `Tests/RealJobs/library/no-location/no-location.jobs.json`: import, export JPEG with `{"metadata":"noLocation"}` and a sidecar | `input/gps-phone.jpg` (GPS, serials, maker note, copyright) |
| RJ-X03 | closes (now `library/export-pack`) | Cm | the same folder's HEIC run with a sidecar | the same fixture |

Trap: the JPEG is clean but the XMP sidecar or a property copy carries GPS
and serials beside it; or "clean" also drops the copyright the person
wanted kept. Assertion: neither the JPEG, the HEIC nor the sidecar has any
`{GPS}` path, serial or maker note; the JPEG keeps `{TIFF}.Model`,
`{Exif}.DateTimeOriginal` and `{TIFF}.Copyright`. Mutations:
`LibraryModel.ExportSidecar.json`, GPS written under `.noLocation` →
`.sidecarDropsGPS`; `LibraryModel.LiveExporter.json`, the policy not passed
→ `.writerDrops`.

## Screens and states

`library-export-metadata` (light and dark).

## Contract slice

```swift
// Sources/LibraryModel/Contracts/LibraryContracts.swift (LX-1)
public struct ExportOptions { ...; public var metadata: ExportMetadata = .noLocation }   // key "metadata"; old files read the default
// Sources/LibraryModel/Contracts/ExportSidecar.swift (LX-1 signature, LX-3 body)
public static func xmp(for photo: PhotoItem, metadata: ExportMetadata) -> Data?
```

## Pseudocode

- **sidecar.** Drop every attribute whose name is in
  `ExportRules.dropped(policy).xmp`; Library's own namespace (rating, label,
  develop) always stays.
- **writer.** Encode as today, then `services.metadata.carrying(encoded,
  from: original bytes, dropping: ExportRules.dropped(policy).properties)`.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| LX-1 | – | `ExportOptions.metadata` (coded, default All but location) and the sidecar's new signature; `LibraryExportMetadataTests` written, disabled | `Sources/LibraryModel/Contracts/LibraryContracts.swift`, `Sources/LibraryModel/Contracts/ExportSidecar.swift`, `Tests/LibraryModelTests/LibraryExportMetadataTests.swift` | XP-a, export | ~120, 3 |
| LX-2 | – | The sheet's Metadata row (the shared row through `ExportPick.metadata`) | `Sources/LibraryApp/LibraryExportSheet.swift` | LX-1 | ~60, 1 |
| LX-3 | – | The sidecar's policy and `LiveExporter` passing the policy to the writer; RJ-L16's and RJ-X03's job folder; turns on `LibraryExportMetadataTests` | `Sources/LibraryModel/Contracts/ExportSidecar.swift`, `Sources/LibraryModel/Live/LiveExporter.swift`, `Tests/LibraryModelTests/LibraryExportMetadataTests.swift`, `Tests/mutations/LibraryModel.ExportSidecar.json`, `Tests/mutations/LibraryModel.LiveExporter.json`, `Tests/RealJobs/library/no-location/` | LX-1, XP-6 | ~200, 6 |
| LX-4 | – | `JPEGWriter` carries the original's metadata through `services.metadata` minus the dropped tags | `Sources/LibraryApp/Platform/JPEGWriter.swift`, `Tests/AppSnapshotTests/LibraryExportMetadataWriteTests.swift` | LX-1, XP-7 | ~120, 2 |
| LX-5 | – | Snapshots and the render budget test | `Tests/AppSnapshotTests/LibraryExportPackSnapshots.swift`, `Tests/AppSnapshotTests/RenderBudgetLibraryExportPackTests.swift` | LX-2 | ~120, 2 |
| LX-6 | – | The journey written and skipped (`XCTSkip("waits on LX-7")`) | `UITests/LibraryJourneyTests+ExportPack.swift` | LX-2 | ~100, 1 |
| LX-7 | – | Live: the journey turned on, on live services | `UITests/LibraryJourneyTests+ExportPack.swift` | LX-6, LX-3, LX-4 | ~40, 1 |
| LX-8 | – | `status: built`; `feature-done` (no library.md edit: export's EX-17 owns that section) | `docs/blueprints/library/features/export-pack.wave.json` | LX-7, LX-5 | ~10, 1 |

## Build waves

- Wave 1: LX-1. Independent in this wave: LX-1 alone.
- Wave 2: LX-2, LX-3, LX-4. Independent in this wave: all three.
- Wave 3: LX-5, LX-6. Independent in this wave: both.
- Wave 4: LX-7. Independent in this wave: LX-7 alone.
- Wave 5: LX-8 (`feature-done`, final). Independent in this wave: LX-8 alone.

Longest chain: LX-1 → LX-2 → LX-6 → LX-7 → LX-8 (5). Chain of 4: the journey drives the row, LX-7 turns it on live, LX-8 is the status task.

## Acceptance test per task

| id | test | fails when | mutations |
|---|---|---|---|
| LX-1 | an export options file without `metadata` reads All but location; `LibraryExportMetadataTests` disabled by name | an old file fails or reads another default | – (stub) |
| LX-2 | `LibraryExportPackSnapshots.metadata` (LX-5's, first in the slice PR) | the row is missing | – (UI) |
| LX-3 | `LibraryExportMetadataTests`: under All but location the sidecar has rating, label and develop but no `exif:GPS*`; under None no `xmp:CreateDate`; the writer receives the dropped set; RJ-L16's sidecar half passes on Linux | a dropped field survives or a kept one goes | `LibraryModel.ExportSidecar`: GPS written → `.sidecarDropsGPS`; Library namespace dropped under None → `.keepsLibraryFields`; `LibraryModel.LiveExporter`: policy not passed → `.writerDrops` |
| LX-4 | `LibraryExportMetadataWriteTests` (macOS): the exported JPEG and HEIC have no GPS, serial or maker note and keep model, capture date and copyright | a dropped tag survives | – (macOS) |
| LX-5 | `LibraryExportPackSnapshots`; `RenderBudgetLibraryExportPackTests.metadataPickInTwoBodies` | budget over | – (UI) |
| LX-6 | compiles, skipped | – | – |
| LX-7 | `LibraryExportPackJourneyTests.testExportWithoutLocation` steps 1 to 4; RJ-L16 and RJ-X03 green on macOS | a step fails | – |
| LX-8 | `scripts/waves render --dry-run` | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| render: picking a metadata policy | ≤ 2 window bodies | `RenderBudgetLibraryExportPackTests.metadataPickInTwoBodies` |
| Privacy | no GPS in any written file under the default | RJ-X03 |
| Audit | zero new over Library's baseline | `audit-library-*.json` |

## Done check

Per slice (rules 6, 15, 17, 21): LX-m merged-done; LX-u's and LX-m's feel gate and `Mac-Finish:`; LX-z's journey on live and RJ-L16, RJ-X03 green on macOS. Then `Belt-Contact-Sheet:` with `library-export-*`.

## Not in this packet

Per-field metadata choices, keywords and captions editing (metadata-more), watermarks (RJ-L17).
