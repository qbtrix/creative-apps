// HaloMovieWriter.swift: the movie sink of Render Out (render-out RO-7,
// #1505). A RenderSink that writes one H.264 `.mp4` at the plan's size and
// exact frame rate, tagged BT.709 (primaries, transfer function and YCbCr
// matrix). The plan's `HaloMovieClock` times frame i at i x den / num s and
// ends the session at frames x den / num s, so a 48-frame, 24 fps plan is
// exactly 2 s long and 300 frames at 29.97 are 10.01 s (frame-rates FR-8b);
// the track counts in the clock's track timescale. Each frame is
// HaloFrameImage's sRGB image drawn over opaque black (transparent areas
// become black) by MovieWriter's `taggedBuffer`, which converts it into the
// BT.709 colour space the tags name, so a player shows the frame's own
// colours rather than 709-tagged sRGB values about 12/255 too bright.
// `finish(cancelled: true)` cancels the writer, which deletes the file it
// created.
//
// MovieWriter, SuiteShell's canonical writer, was moved from this type and
// replaces it at Halo's `services.media` adoption. Not yet: it times frames
// at a whole-number rate, and Halo renders exact rates such as 29.97.
//
// It uses the macOS 26 receiver API (`inputPixelBufferReceiver(for:)`,
// `start()`, `appendImmediately(_:with:)`): the pixel buffer adaptor,
// `add(_:)`, `startWriting()` and `isReadyForMoreMediaData` are deprecated
// at the deployment target. RenderSink is synchronous, so a frame that the
// input isn't ready for is retried after a short sleep, and the end of
// `finishWriting` is awaited on a semaphore its completion handler signals
// from AVFoundation's own queue.
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import HaloModel
import SuiteShell

/// Why a movie couldn't be written; its description is what Render Out shows.
struct HaloMovieWriterError: Error, CustomStringConvertible {
    let description: String
}

struct HaloMovieWriter: RenderSink {
    /// Where the movie goes. `begin` refuses a URL that already has a file.
    let url: URL
    /// How long one frame may wait for the encoder before the render fails.
    var frameTimeout: TimeInterval = 30

    private var writer: AVAssetWriter?
    private var receiver: AVAssetWriterInput.PixelBufferReceiver?
    private var width = 0
    private var height = 0
    private var clock: HaloMovieClock?
    private var space: CGColorSpace?
    private var written = 0

    init(url: URL) {
        self.url = url
    }

    mutating func begin(_ plan: HaloRenderPlan) throws {
        guard plan.width > 0, plan.height > 0, plan.framesPerSecond > 0, let clock = plan.movieClock else {
            throw HaloMovieWriterError(description: "The movie needs a size and a frame rate.")
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw HaloMovieWriterError(description: "A file named \(url.lastPathComponent) already exists.")
        }
        guard let space = MovieWriter.bt709Space() else {
            throw HaloMovieWriterError(description: "The movie's BT.709 colour space couldn't be made.")
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: Self.outputSettings(plan))
        input.mediaTimeScale = clock.trackTimescale
        writer.movieTimeScale = clock.trackTimescale
        guard writer.canAdd(input) else {
            throw HaloMovieWriterError(description: "The movie writer refused an H.264 video track.")
        }
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: nil)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        self.writer = writer
        self.receiver = receiver
        width = plan.width
        height = plan.height
        self.clock = clock
        self.space = space
        written = 0
    }

    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        guard let writer, let receiver else {
            throw HaloMovieWriterError(description: "The movie was written before it began.")
        }
        let buffer = try pixelBuffer(frame)
        let time = try Self.time(ofFrame: written, clock)
        let deadline = Date().addingTimeInterval(frameTimeout)
        while try !receiver.appendImmediately(buffer, with: time) {
            if writer.status == .failed { throw Self.failure(writer) }
            guard Date() < deadline else {
                throw HaloMovieWriterError(description: "The movie encoder stopped taking frames.")
            }
            Thread.sleep(forTimeInterval: 0.002)
        }
        written += 1
    }

    mutating func finish(cancelled: Bool) throws {
        guard let writer, let receiver else { return }
        self.writer = nil
        self.receiver = nil
        if cancelled {
            writer.cancelWriting()
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            return
        }
        receiver.finish()
        writer.endSession(atSourceTime: try Self.time(ofFrame: written, clock))
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw Self.failure(writer) }
    }

    /// Where frame `frame` starts on `clock`, as the writer takes a time.
    private static func time(ofFrame frame: Int, _ clock: HaloMovieClock?) throws -> CMTime {
        guard let tick = clock?.time(ofFrame: frame) else {
            throw HaloMovieWriterError(description: "Frame \(frame) is past the movie's clock.")
        }
        return CMTime(value: tick.value, timescale: tick.timescale)
    }

    /// H.264 at the plan's size, BT.709 throughout, at a bit rate generous
    /// enough that flat areas come back within a few levels.
    private static func outputSettings(_ plan: HaloRenderPlan) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: plan.width,
            AVVideoHeightKey: plan.height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: plan.width * plan.height * plan.framesPerSecond / 2,
            ],
        ]
    }

    /// `frame` as a BGRA buffer of the plan's size, tagged BT.709 like the
    /// track: opaque black, then the frame's sRGB image drawn over it.
    private func pixelBuffer(_ frame: HaloRenderedFrame) throws -> CVReadOnlyPixelBuffer {
        guard let image = HaloFrameImage.cgImage(frame), let space else {
            throw HaloMovieWriterError(description: "Frame \(frame.frame) has no pixels to write.")
        }
        do {
            return try MovieWriter.taggedBuffer(image, width: width, height: height, space: space, keepAlpha: false)
        } catch {
            throw HaloMovieWriterError(description: "Frame \(frame.frame) couldn't be drawn: \(error.message)")
        }
    }

    private static func failure(_ writer: AVAssetWriter) -> HaloMovieWriterError {
        HaloMovieWriterError(
            description: "The movie couldn't be written: \(writer.error?.localizedDescription ?? "unknown error").")
    }
}
