// HaloMovieWriterTests.swift: the movie sink (render-out RO-7, #1505, HF-8).
// `keyed` (1920 × 1080, 24 fps, 48 frames) rendered at full size through
// HaloMovieWriter: the movie loads as exactly 2 s, an asset reader counts 48
// video samples, and frame 0 read back colour-managed (FootageReader, through
// the BT.709 tags, as a player shows it) matches LiveFrameRendering's frame 0
// (HaloFrameImage's sRGB bytes composited over black here) within 4/255 per
// channel on at least 99% of pixels. A render cancelled after 3 frames leaves
// no file. Keyed's floor stretched over the frame in a mid-tone (120, 135,
// 128), the colour #4640 caught MovieWriter brightening, written at 1280 x 720
// comes back within 6/255 mean error of its sRGB source, the tolerance
// ShellMediaFootageTests holds MovieWriter to. Uses only the macOS 26 reader
// API (outputProvider, start, next). Writes no snapshot PNGs. macOS only.
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import HaloModel
import SuiteKernel
import SuiteModel
import SuiteShell
import Testing

@testable import HaloApp

@Suite(.timeLimit(.minutes(10))) struct HaloMovieWriterTests {
    private func keyed() throws -> HaloComposition {
        try #require(HaloFixtures.project("keyed")?.compositions.first)
    }

    /// A fresh, empty folder for one test's movie.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HaloMovieWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func keyedRendersAsATwoSecondMovieMatchingFrameZero() async throws {
        let composition = try keyed()
        let rendering = LiveCompositionRendering()
        let plan = try rendering.plan(composition, settings: HaloRenderSettings(format: .movie))
        #expect(plan.width == 1920 && plan.height == 1080 && plan.framesPerSecond == 24 && plan.frames.count == 48)
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(try #require(plan.fileNames.first))
        var writer = HaloMovieWriter(url: url)
        let outcome = rendering.run(plan, of: composition, text: nil, into: &writer, isCancelled: { false })
        #expect(outcome == .finished(frames: 48))

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        #expect(CMTimeCompare(duration, CMTime(value: 48, timescale: 24)) == 0)

        #expect(try await sampleCount(asset) == 48)
        let expected = try oracle(composition, width: plan.width, height: plan.height)
        let decoded = try await FootageReader().frame(ofMovieAt: url.path, seconds: 0, longestSide: nil).rgba
        #expect(decoded.count == expected.count)
        let pixels = min(decoded.count, expected.count) / 4
        var close = 0
        for p in 0..<pixels {
            let i = p * 4
            let near = (0..<3).allSatisfy { c in abs(Int(decoded[i + c]) - Int(expected[i + c])) <= 4 }
            if near { close += 1 }
        }
        #expect(pixels > 0 && close * 100 >= pixels * 99, "\(close) of \(pixels) pixels within 4/255")
    }

    @Test func cancelAfterThreeFramesLeavesNoFile() throws {
        let composition = try keyed()
        let plan = try LiveCompositionRendering().plan(composition, settings: HaloRenderSettings(format: .movie))
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(try #require(plan.fileNames.first))
        var writer = HaloMovieWriter(url: url)
        try writer.begin(plan)
        for f in 0..<3 {
            let list = LiveFrameDrawing().drawList(composition, at: f)
            let frame = try LiveFrameRendering().render(list, width: plan.width, height: plan.height, text: nil)
            try writer.write(frame, named: url.lastPathComponent)
        }
        try writer.finish(cancelled: true)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    /// A player decodes the movie through its BT.709 tags; the frame must come
    /// back as the sRGB colours it was given, not about 12/255 bright.
    @Test func movieReadsBackAsItsSourceColours() async throws {
        var composition = try keyed()
        var floor = try #require(composition.layers.last)
        floor.rect = HaloLayerRect(x: 0, y: 0, width: 1920, height: 1080)
        floor.color = HaloLayerColor(red: 120 / 255, green: 135 / 255, blue: 128 / 255)
        composition.layers = [floor]
        let rendered = try LiveFrameRendering().render(
            LiveFrameDrawing().drawList(composition, at: 0), width: 1280, height: 720, text: nil)
        let image = try #require(HaloFrameImage.cgImage(rendered))
        let bytes = try #require(image.dataProvider?.data)
        let source = try MediaFrame(width: 1280, height: 720, rgba: [UInt8](bytes as Data))
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("colour.mp4")
        var writer = HaloMovieWriter(url: url)
        try writer.begin(HaloRenderPlan(width: 1280, height: 720, framesPerSecond: 24, frames: Array(0..<12),
                                        fileNames: [url.lastPathComponent]))
        for _ in 0..<12 { try writer.write(rendered, named: url.lastPathComponent) }
        try writer.finish(cancelled: false)
        let frame = try await FootageReader().frame(ofMovieAt: url.path, seconds: 0.25, longestSide: nil)
        let error = ShellMediaFootageTests.meanError(frame, source)
        print("HaloMovieWriterTests.colour: frame reads back \(error)/255 off its source")
        #expect(error <= 6, "frame reads back \(error)/255 off its source")
    }

    /// FR-8b: keyed at 29.97 for 30 frames, half size, is 30 x 1001 / 30000 s on a 30000 track, not 1 s.
    @Test func ntscMovieRunsAtTheExactRate() async throws {
        var composition = try keyed()
        composition.frameRate = FrameRate(numerator: 30000, denominator: 1001)
        composition.durationFrames = 30
        let rendering = LiveCompositionRendering()
        let plan = try rendering.plan(composition, settings: HaloRenderSettings(format: .movie, halfSize: true))
        let dir = try folder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(try #require(plan.fileNames.first))
        var writer = HaloMovieWriter(url: url)
        #expect(rendering.run(plan, of: composition, text: nil, into: &writer, isCancelled: { false }) == .finished(frames: 30))
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        #expect(CMTimeCompare(duration, CMTime(value: 30_030, timescale: 30000)) == 0, "\(duration.seconds) s")
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        #expect(try await track.load(.naturalTimeScale) == 30000)
    }

    /// LiveFrameRendering's frame 0 as HaloFrameImage's straight-alpha sRGB
    /// bytes, composited over black (c × a / 255), in R, G, B, 255 order.
    private func oracle(_ composition: HaloComposition, width: Int, height: Int) throws -> [UInt8] {
        let list = LiveFrameDrawing().drawList(composition, at: 0)
        let frame = try LiveFrameRendering().render(list, width: width, height: height, text: nil)
        let image = try #require(HaloFrameImage.cgImage(frame))
        let data = try #require(image.dataProvider?.data)
        let rgba = [UInt8](data as Data)
        try #require(rgba.count == width * height * 4)
        var out = [UInt8](repeating: 255, count: rgba.count)
        for i in stride(from: 0, to: rgba.count, by: 4) {
            let a = Int(rgba[i + 3])
            for c in 0..<3 { out[i + c] = UInt8((Int(rgba[i + c]) * a + 127) / 255) }
        }
        return out
    }

    /// The number of video samples in `asset`.
    private func sampleCount(_ asset: AVURLAsset) async throws -> Int {
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let reader = try AVAssetReader(asset: asset)
        let provider = reader.outputProvider(for: AVAssetReaderTrackOutput(track: track, outputSettings: nil))
        try reader.start()
        var count = 0
        while let sample = try await provider.next() {
            count += sample.withUnsafeSampleBuffer { CMSampleBufferGetNumSamples($0) }
        }
        #expect(reader.status == .completed)
        return count
    }
}
