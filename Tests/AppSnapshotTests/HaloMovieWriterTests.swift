// HaloMovieWriterTests.swift: the movie sink (render-out RO-7, #1505, HF-8).
// `keyed` (1920 × 1080, 24 fps, 48 frames) rendered at full size through
// HaloMovieWriter: the movie loads as exactly 2 s, an asset reader counts 48
// video samples, and frame 0 decoded matches LiveFrameRendering's frame 0
// (HaloFrameImage's sRGB bytes composited over black here) within 4/255 per
// channel on at least 99% of pixels. A render cancelled after 3 frames leaves
// no file. Uses only the macOS 26 reader API (outputProvider, start, next).
// Writes no snapshot PNGs. macOS only.
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import HaloModel
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

        let (count, first) = try await readFrames(asset)
        #expect(count == 48)
        let decoded = try #require(first)
        let expected = try oracle(composition, width: plan.width, height: plan.height)
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

    /// The number of video samples in `asset`, and the first one decoded as
    /// R, G, B, A bytes with no row padding.
    private func readFrames(_ asset: AVURLAsset) async throws -> (Int, [UInt8]?) {
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try #require(tracks.first)
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        var count = 0
        var first: [UInt8]?
        while let sample = try await provider.next() {
            let decoded: [UInt8]? = sample.withUnsafeSampleBuffer { buffer in
                count += CMSampleBufferGetNumSamples(buffer)
                guard first == nil, let image = CMSampleBufferGetImageBuffer(buffer) else { return nil }
                return Self.rgba(image)
            }
            if first == nil, let decoded { first = decoded }
        }
        #expect(reader.status == .completed)
        return (count, first)
    }

    /// A BGRA image buffer's pixels as tightly packed R, G, B, A bytes.
    private static func rgba(_ image: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
        guard CVPixelBufferGetPixelFormatType(image) == kCVPixelFormatType_32BGRA,
              let base = CVPixelBufferGetBaseAddress(image)
        else { return nil }
        let width = CVPixelBufferGetWidth(image), height = CVPixelBufferGetHeight(image)
        let rowBytes = CVPixelBufferGetBytesPerRow(image)
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var out = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let s = y * rowBytes + x * 4, d = (y * width + x) * 4
                out[d] = bytes[s + 2]
                out[d + 1] = bytes[s + 1]
                out[d + 2] = bytes[s]
                out[d + 3] = bytes[s + 3]
            }
        }
        return out
    }
}
