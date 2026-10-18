# Feature packet: shell-media

**Feature:** one media I/O service for the whole suite: write movies (H.264,
HEVC, HEVC with alpha, ProRes 4444 with alpha), animated images (GIF, APNG)
and stills (PNG, JPEG, HEIC, TIFF), and read images and footage (info, a
still, the frame at a time). The contract and its values live in
SuiteModel (Linux-safe: frames are 8-bit sRGB bytes, settings are values
with their rules); the AVFoundation and ImageIO code lives in SuiteShell as
the new `shell-media` component, reached through `SuiteServices.media`.
Halo's H.264 writer and Photo's ImageIO codec move here, so no third app
writes its own.
**Line:** `line:suite` · **Wave:** 5 (`waves.md`) · **Lead branch:** `lead/shell-media`
**Beta:** beta-80 plan W1 (row E9). Labels `beta` and `p1` when filed.

**Covers:** beta-80 plan row E9 ("Media I/O: H.264, HEVC, ProRes 4444, GIF,
APNG, image and footage decode"), its section 8 note (AVFoundation and
ImageIO are macOS-only, so the live code is `suite-shell` with the contract
in `suite-model`, not a SuiteModel wrapper), and the ⚠ guard "Halo's
render-out H.264 writer moves into `shell-media`". Halo map rows 10
(ProRes 4444, HEVC, GIF) and 13 (footage layers, decode half); Flare's
GIF and video export rows.

**Depends on:** suite-contracts (built: `SuiteServices`, the slot pattern,
`SuiteError`). Nothing in creative-core. The code it moves is on `dev`:
`Sources/HaloApp/HaloMovieWriter.swift` (render-out RO-7) and
`Sources/PhotoApp/ImageIOCodec.swift` (Photo's `PhotoImageCodec`).

**Rule 20 (canonical first).** This is the one media writer and reader.
Export *runs* (progress, cancel, the sheet) stay suite-kernel `ExportRun`
and SuiteUI `ExportSheet` (editor-kernel EK-run, EK-chrome); this feature
only turns frames into files and files into frames. Halo and Photo keep
their copies until their W3 adoption swaps them for `services.media`; no
task here edits an app.

**C4:** container `suite-model`, component `suite-contracts` (the
`MediaEncoding` and `MediaDecoding` protocols, in `Sources/SuiteModel/Contracts/`),
`suite-identity` (the values, in `Values/`), `suite-fakes` (`FakeMedia`),
`suite-services` (the `media` member); container `suite-shell`, ✚ new
component `shell-media` (`docs/c4/parts/creative-apps/suite-shell/shell-media.json`,
`paths: ["Sources/SuiteShell/Media/"]`), added by SM-5 with its first file,
and `shell-live` (`Live/MediaSlot.swift`).

**Clean-room.** Behaviour from Apple's AVFoundation and ImageIO
documentation and the published codec and container rules; no task reads
another product's code.

Blueprint sections: suite.md 2 (targets), 2.3 (components), 5 (contracts).

## Slices

| slice | behavior (one sentence) | tasks | journeys | waits on |
|---|---|---|---|---|
| SM-a | Callers can code against `MediaEncoding`, `MediaDecoding`, the media values and `FakeMedia` through `SuiteServices.media`, with the Linux checks and the macOS live checks written and disabled. | SM-1, SM-2 | MJ-SM0 | – |
| SM-m | `MovieSettings` and `AnimatedImageSettings` refuse what each codec can't write (odd sizes for 4:2:0, alpha without an alpha codec, sizes and rates out of range), and `FrameClock` gives exact presentation times and GIF delays whose rounding never drifts. | SM-3, SM-4 | MJ-SM1 | SM-a |
| SM-w | On a Mac, a movie writes in each of the four codecs at its size and rate with BT.709 tags and alpha where the codec keeps it, GIF and APNG write with their loop count and delays, and stills encode as PNG, JPEG, HEIC and TIFF; cancel deletes the file. | SM-5, SM-6 | MJ-SM2 | SM-a |
| SM-r | On a Mac, any still ImageIO reads decodes upright to 8-bit sRGB (optionally shrunk), and a movie's info and its frame at a time read back. | SM-7, SM-8 | MJ-SM3 | SM-a; SM-w (SM-8) |
| SM-z | The slot is live, a walk writes and reads back every format on the Mac, the shared prose names the service, and the feature is built. | SM-9, SM-10 | MJ-SM4 | SM-m, SM-w, SM-r; onboarding (SM-10: it owns suite.md first) |

`ui_slice: none`: no screen of its own. Its screen is SuiteUI's
`ExportSheet` (S11's export pack and render queue) and each app's import of
images and footage (S20).

## Journey steps

No XCUITest: the service has no control. Model walks (Linux) and live walks
(macOS, `AppSnapshotTests`) prove it.

- **MJ-SM0** (SM-2, `MediaContractTests`): `SuiteServices.fake().media`
  records a 3-frame movie and a still; `pending["media"]` names the reason.
- **MJ-SM1** (SM-3, SM-4): settings rules and the frame clock, on Linux.
- **MJ-SM2** (SM-5, SM-6, `ShellMediaWriteTests`): a 48-frame 24 fps
  1280 × 720 H.264 is 2.000 s with BT.709 tags; ProRes 4444 and HEVC with
  alpha keep a transparent corner; a 10-frame GIF loops forever with 4 cs
  delays at 25 fps; APNG keeps alpha; cancel leaves no file.
- **MJ-SM3** (SM-7, SM-8, `ShellMediaReadTests`): a rotated JPEG decodes
  upright; HEIC decodes; the H.264 from MJ-SM2 reports 48 frames at 24 fps,
  and its frame at 1.0 s equals source frame 24 within 6/255 mean error.
- **MJ-SM4** (SM-9): `SuiteServices.live.media` writes and reads back every
  format; `pending` has no `media` key.

## Screens and states

None.

## Contract slice

```swift
// Sources/SuiteModel/Values/Media.swift (SM-1)
public struct MediaFrame: Sendable, Equatable { public let width: Int, height: Int; public let rgba: [UInt8]   // 8-bit sRGB, straight alpha, top row first
    public init(width: Int, height: Int, rgba: [UInt8]) throws(SuiteError) }                                // count = w × h × 4
public enum MovieCodec: String, Codable, Sendable, CaseIterable { case h264, hevc, hevcAlpha, prores4444
    public var keepsAlpha: Bool { get }; public var needsEvenSize: Bool { get } }
public enum AnimatedImageFormat: String, Codable, Sendable, CaseIterable { case gif, apng }
public enum StillFormat: String, Codable, Sendable, CaseIterable { case png, jpeg, heic, tiff }
public struct MovieSettings: Hashable, Codable, Sendable { public var width: Int, height: Int, fps: Int; public var codec: MovieCodec; public var quality: Double
    public func validated() throws(SuiteError) -> MovieSettings }
public struct AnimatedImageSettings: Hashable, Codable, Sendable { public var width: Int, height: Int, fps: Int; public var format: AnimatedImageFormat; public var loopCount: Int
    public func validated() throws(SuiteError) -> AnimatedImageSettings }
public struct MediaInfo: Hashable, Codable, Sendable { public var width: Int, height: Int; public var seconds: Double; public var fps: Double
    public var frameCount: Int; public var hasAlpha: Bool; public var hasAudio: Bool; public var codec: String }
public struct FrameClock: Hashable, Sendable { public init(fps: Int) throws(SuiteError)
    public func seconds(of frame: Int) -> Double                   // frame / fps, exact as a rational's value
    public mutating func nextGIFDelay() -> Int }                   // centiseconds, error carried so n frames sum to round(100 n / fps)

// Sources/SuiteModel/Contracts/MediaEncoding.swift (SM-1)
public protocol FrameSink: AnyObject, Sendable {
    func append(_ frame: MediaFrame) throws(SuiteError)          // frames in order; a wrong size throws
    func finish() async throws(SuiteError)
    func cancel() }                                               // deletes the partial file
public protocol MediaEncoding: Sendable {
    var movieCodecs: [MovieCodec] { get }                         // what this Mac can write
    func movie(at path: String, _ settings: MovieSettings) throws(SuiteError) -> any FrameSink
    func animatedImage(at path: String, _ settings: AnimatedImageSettings) throws(SuiteError) -> any FrameSink
    func still(_ frame: MediaFrame, as format: StillFormat, quality: Double) throws(SuiteError) -> Data }
// Sources/SuiteModel/Contracts/MediaDecoding.swift (SM-1)
public protocol MediaDecoding: Sendable {
    func still(_ data: Data, longestSide: Int?) throws(SuiteError) -> MediaFrame       // upright
    func info(ofMovieAt path: String) async throws(SuiteError) -> MediaInfo
    func frame(ofMovieAt path: String, seconds: Double, longestSide: Int?) async throws(SuiteError) -> MediaFrame }
public typealias MediaCoding = MediaEncoding & MediaDecoding

// Sources/SuiteModel/Fakes/FakeMedia.swift (SM-1): records every call, returns fixture frames,
//   throws `unavailable` when given one. SuiteServices gains `media: any MediaCoding` (default FakeMedia()).
```

## Pseudocode

- **Rules (SM-3).** Width and height 16...8192; `needsEvenSize` (H.264,
  HEVC: 4:2:0) refuses odd sizes with "Width and height must be even for
  H.264."; fps 1...120 for movies, 1...50 for GIF (centisecond delays) and
  1...120 for APNG; quality 0...1; loop count 0 (forever)...65,535. Every
  refusal is `SuiteError.notAvailable(<the sentence>)`.
- **FrameClock (SM-4).** `seconds(of:)` is `Double(frame) / Double(fps)`;
  GIF delays carry the remainder: delay = `round(100 × (n + 1) / fps) −
  round(100 × n / fps)`, so 30 fps alternates 3 and 4 cs and 30 frames sum
  to exactly 100.
- **Movie writer (SM-5, macOS).** Moved from `HaloMovieWriter`: the macOS 26
  receiver API, BT.709 primaries, transfer and matrix, frame `i` at `i / fps`,
  the session ends at `frames / fps`, retry a frame the input isn't ready
  for, await `finishWriting` on its completion. New: the codec from
  settings (HEVC with alpha and ProRes 4444 keep alpha; H.264 and HEVC draw
  over opaque black, today's rule); `movieCodecs` asks the system which
  codecs this Mac's writer offers and drops HEVC with alpha when it can't.
- **Animated images (SM-6).** One `CGImageDestination` per file, the loop
  count in the file properties and each frame's delay from `FrameClock`
  (GIF) or `1 / fps` (APNG); palette reduction is ImageIO's.
- **Stills (SM-6 encode, SM-7 decode).** Moved from Photo's `ImageIOCodec`:
  decode applies orientation, shrinks to `longestSide`, draws into 8-bit
  sRGB and unpremultiplies; encode writes the format at `quality` (JPEG,
  HEIC) with alpha where the format keeps it.
- **Footage (SM-8).** `info` from the asset's video track (natural size
  with its transform, nominal frame rate, duration, frame count = round(
  seconds × fps)); `frame` from an image generator with zero tolerance
  before and after, so the frame is the exact one at that time.

## Tasks

| id | issue | what | owned files | depends on | size |
|---|---|---|---|---|---|
| SM-1 | – | The contract: values, both protocols, `FakeMedia`, the `media` member with its fake default and `pending` reason, the fake slot; MJ-SM0 | `Sources/SuiteModel/Values/Media.swift`, `Sources/SuiteModel/Contracts/MediaEncoding.swift`, `Sources/SuiteModel/Contracts/MediaDecoding.swift`, `Sources/SuiteModel/Fakes/FakeMedia.swift`, `Sources/SuiteModel/SuiteServices.swift`, `Sources/SuiteShell/SuiteServices+Live.swift`, `Sources/SuiteShell/Live/MediaSlot.swift`, `Tests/SuiteModelTests/MediaContractTests.swift` | – | ~360, 8 |
| SM-2 | – | Checks first: `MediaRulesTests` and `FrameClockTests` (Linux), `ShellMediaWriteTests` and `ShellMediaReadTests` (macOS) disabled by name; fixture stills (a rotated JPEG, a HEIC, a PNG with alpha) | `Tests/SuiteModelTests/MediaRulesTests.swift`, `Tests/SuiteModelTests/FrameClockTests.swift`, `Tests/AppSnapshotTests/ShellMediaWriteTests.swift`, `Tests/AppSnapshotTests/ShellMediaReadTests.swift`, `Tests/AppSnapshotTests/Fixtures/media/` | SM-1 | ~320, 4 + fixtures |
| SM-3 | – | `validated()` for both settings; turns on `MediaRulesTests` | `Sources/SuiteModel/Values/Media+Rules.swift`, `Tests/SuiteModelTests/MediaRulesTests.swift`, `Tests/mutations/SuiteModel.MediaRules.json` | SM-2 | ~180, 3 |
| SM-4 | – | `FrameClock`; turns on `FrameClockTests` | `Sources/SuiteModel/Values/FrameClock.swift`, `Tests/SuiteModelTests/FrameClockTests.swift`, `Tests/mutations/SuiteModel.FrameClock.json` | SM-2 | ~120, 3 |
| SM-5 | – | `MovieWriter` (moved from `HaloMovieWriter`, four codecs) and the `shell-media` C4 part; turns on the movie cases of `ShellMediaWriteTests`; `Unverified API:` lines for the receiver API and the HEVC-alpha check | `Sources/SuiteShell/Media/MovieWriter.swift`, `Tests/AppSnapshotTests/ShellMediaWriteTests.swift`, `docs/c4/parts/creative-apps/suite-shell/shell-media.json` | SM-2 | ~360, 3 |
| SM-6 | – | `AnimatedImageWriter` and `StillEncoder`; turns on the GIF, APNG and still cases in a second suite file | `Sources/SuiteShell/Media/AnimatedImageWriter.swift`, `Sources/SuiteShell/Media/StillEncoder.swift`, `Tests/AppSnapshotTests/ShellMediaImageWriteTests.swift` | SM-2 | ~280, 3 |
| SM-7 | – | `StillDecoder` (moved from Photo's `ImageIOCodec` decode); turns on the still cases of `ShellMediaReadTests` | `Sources/SuiteShell/Media/StillDecoder.swift`, `Tests/AppSnapshotTests/ShellMediaReadTests.swift` | SM-2 | ~220, 2 |
| SM-8 | – | `FootageReader` (`info`, `frame`); its read cases in a second suite file, reading SM-5's H.264 | `Sources/SuiteShell/Media/FootageReader.swift`, `Tests/AppSnapshotTests/ShellMediaFootageTests.swift` | SM-5 | ~220, 2 |
| SM-9 | – | `LiveMedia` joins the four into one `MediaCoding`; the slot goes live (`mediaIsLive = true`); MJ-SM4 | `Sources/SuiteShell/Media/LiveMedia.swift`, `Sources/SuiteShell/Live/MediaSlot.swift`, `Tests/AppSnapshotTests/ShellMediaLiveTests.swift` | SM-3, SM-4, SM-6, SM-7, SM-8 | ~120, 3 |
| SM-10 | – | Shared prose: suite.md names the media service and the rule that no app writes its own; the `shell-media` part's final words; `status: built`; `feature-done` | `docs/blueprints/suite.md`, `docs/c4/parts/creative-apps/suite-shell/shell-media.json`, `docs/blueprints/suite/features/shell-media.wave.json` | SM-9 | ~60, 3 |

SM-1 is the one task that edits shared suite files (`SuiteServices.swift`,
`SuiteServices+Live.swift`); `shell-text`'s ST-1 waits on it for the same
two files. SM-6 and SM-8 take their own test files so the four live tasks
share none.

## Build waves

- Wave 1: SM-1. Independent in this wave: SM-1 alone.
- Wave 2: SM-2. Independent in this wave: SM-2 alone.
- Wave 3: SM-3, SM-4, SM-5, SM-6, SM-7. Independent in this wave: all five.
- Wave 4: SM-8. Independent in this wave: SM-8 alone.
- Wave 5: SM-9. Independent in this wave: SM-9 alone.
- Wave 6: SM-10 (shared prose, `feature-done`, final). Independent in this wave: SM-10 alone.

Longest chain: SM-1 → SM-2 → SM-5 → SM-8 → SM-9 → SM-10 (6). Chain of 6:
the checks code against the contract, footage reads the movie SM-5 writes,
the live service joins all four, SM-10 is the final prose task.

## Acceptance test per task

Mutations go in the plan the task owns (`scripts/mutate --plan
SuiteModel.<File>`). The live AVFoundation and ImageIO code is macOS-only:
its tests run on the `macOS` job and the Mac finisher (rule 17), not under
`scripts/mutate`, so those rows say "none: live (parity by readback)".

| id | test | fails when | mutations |
|---|---|---|---|
| SM-1 | `MediaContractTests` (MJ-SM0): the fake records frames in order and a still; an `unavailable` fake throws its reason; `MediaFrame` refuses a short byte count; `SuiteServices.fake().pending["media"]` is set | a member is missing or a frame of the wrong size is accepted | `SuiteModel.MediaFrame`: count check `<` for `!=` → `MediaContractTests.refusesWrongByteCount` (plan owned by SM-1: `Tests/mutations/SuiteModel.MediaFrame.json`); fake drops the first frame → `.fakeRecordsInOrder` |
| SM-2 | suites compile; disabled by name | – | – |
| SM-3 | `MediaRulesTests`: 1281 × 720 H.264 refused with the even-size sentence, accepted for ProRes 4444; 15 × 15 and 8193 wide refused; GIF at 60 fps refused, APNG accepted; quality 1.2 refused; loop 70,000 refused | a codec's rule is applied to another | `SuiteModel.MediaRules`: even rule applied to ProRes → `MediaRulesTests.proResTakesOddSizes`; GIF cap 50 becomes 60 → `.gifCapsAtFifty`; size bound `<` for `<=` at 8192 → `.eightKAccepted` |
| SM-4 | `FrameClockTests`: 24 fps frame 48 is 2.0 s; 30 fps delays sum to 100 cs over 30 frames and alternate 3 and 4; 25 fps all 4; fps 0 throws | GIF timing drifts | `SuiteModel.FrameClock`: carry dropped (always round(100 / fps)) → `FrameClockTests.thirtyFpsSumsToOneSecond`; delay of frame n uses `n − 1` → `.firstDelayIsThree` |
| SM-5 | `ShellMediaWriteTests` movie cases (MJ-SM2): duration 2.000 s ± 1 ms, BT.709 tags, each codec's track codec; ProRes and HEVC alpha read back a transparent corner; cancel leaves no file | a movie is the wrong length or loses alpha | none: live (readback) |
| SM-6 | `ShellMediaImageWriteTests`: GIF loop count 0 reads as forever, delays as `FrameClock`'s; APNG keeps alpha; each still format reads back its size | delays or alpha lost | none: live (readback) |
| SM-7 | `ShellMediaReadTests`: the rotated JPEG decodes upright (its top-left pixel red); HEIC decodes; shrink to 512 keeps aspect | a still decodes sideways | none: live |
| SM-8 | `ShellMediaFootageTests`: SM-5's H.264 reports 1280 × 720, 24 fps, 48 frames, no alpha, no audio; frame at 1.0 s matches source frame 24 (mean error ≤ 6/255) and not 23 or 25 (theirs differ by > 20/255 by construction) | the wrong frame comes back | none: live |
| SM-9 | `ShellMediaLiveTests` (MJ-SM4): `SuiteServices.live.media` round-trips every format; `pending` has no `media` | the slot stays fake | none: integrate |
| SM-10 | `scripts/waves render --dry-run`; suite.md names the service | status not built | – |

## Quality tests

| quality row | budget | test |
|---|---|---|
| Movie write speed | 1080p H.264 ≥ 60 frames/s on Apple silicon (release) | `ShellMediaWriteTests.throughput` (reported; Mac finisher) |
| GIF timing | n frames sum to round(100 n / fps) cs | `FrameClockTests` |
| No second writer | no `AVAssetWriter` or `CGImageDestination` outside `Sources/SuiteShell/Media/` once the W3 adoptions land | creative-apps' canonical check (`scripts/check-dup-logic`) gets the two names in the adoption PRs |
| Linux-safe contract | `Sources/SuiteModel` imports no AVFoundation, ImageIO or CoreGraphics | `scripts/ci` Linux job |
| Words | every refusal is a sentence a person can act on | `MediaRulesTests` |

## Done check

Per slice (rules 6, 15, 17): its tasks merged, its checks green on the
newest dev run with its last PR, plans scored; SM-w, SM-r and SM-z need the
Mac finisher (`Mac-Finish-Wanted:`) since their tests are macOS-only. Then
`Belt-Contact-Sheet:` with the format table and the write throughput.

## Adopted later

- **W2:** S11 export pack and render queue (Photo, Design, Library, Halo)
  write through `services.media`; S20 placed images and footage decode
  through it; S23 the audio lane (mux is an S23 addition to this service).
- **W3:** Halo render-out swaps `HaloMovieWriter` for `services.media` and
  deletes it; Photo's `ImageIOCodec` becomes a thin adapter or goes; Library's
  `JPEGWriter` goes; Flare's GIF and video export.

## Not in this packet

Audio decode, waveforms and muxing (S23). WebM and AV1 (no system writer).
HDR and 10-bit frames (frames are 8-bit sRGB). Camera raw decode (Library
raw, W3). A progress or cancel UI (the kernel's `ExportRun` and SuiteUI's
`ExportSheet`).
