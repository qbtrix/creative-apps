// HaloMovieWriter.swift: the movie sink of Render Out (render-out RO-7,
// #1505). A RenderSink that writes one H.264 `.mp4` at the plan's size and
// frame rate, tagged BT.709 (primaries, transfer function and YCbCr matrix).
// Frame i of the movie is presented at i / fps and the session ends at
// frames / fps, so a 48-frame, 24 fps plan is exactly 2 s long. Each frame is
// HaloFrameImage's sRGB image drawn over opaque black, so transparent areas
// become black. `finish(cancelled: true)` cancels the writer, which deletes
// the file it created.
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
    private var framesPerSecond = 1
    private var written = 0

    init(url: URL) {
        self.url = url
    }

    mutating func begin(_ plan: HaloRenderPlan) throws {
        guard plan.width > 0, plan.height > 0, plan.framesPerSecond > 0 else {
            throw HaloMovieWriterError(description: "The movie needs a size and a frame rate.")
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw HaloMovieWriterError(description: "A file named \(url.lastPathComponent) already exists.")
        }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: Self.outputSettings(plan))
        let timeScale = CMTimeScale(plan.framesPerSecond * 100)
        input.mediaTimeScale = timeScale
        writer.movieTimeScale = timeScale
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
        framesPerSecond = plan.framesPerSecond
        written = 0
    }

    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        guard let writer, let receiver else {
            throw HaloMovieWriterError(description: "The movie was written before it began.")
        }
        let buffer = try pixelBuffer(frame)
        let time = CMTime(value: CMTimeValue(written), timescale: CMTimeScale(framesPerSecond))
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
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(written), timescale: CMTimeScale(framesPerSecond)))
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw Self.failure(writer) }
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

    /// `frame` as a BGRA buffer of the plan's size: opaque black, then the
    /// frame's sRGB image over it, tagged BT.709 like the track.
    private func pixelBuffer(_ frame: HaloRenderedFrame) throws -> CVReadOnlyPixelBuffer {
        guard let image = HaloFrameImage.cgImage(frame) else {
            throw HaloMovieWriterError(description: "Frame \(frame.frame) has no pixels to write.")
        }
        let attributes: [String: Any] = [
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ]
        var created: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &created)
        guard status == kCVReturnSuccess, let buffer = created else {
            throw HaloMovieWriterError(description: "No memory for a \(width) × \(height) movie frame.")
        }
        guard Self.draw(image, into: buffer, width: width, height: height) else {
            throw HaloMovieWriterError(description: "Frame \(frame.frame) couldn't be drawn.")
        }
        CVBufferSetAttachment(
            buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(
            buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(
            buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        // The buffer is never touched again: the read-only wrapper owns it.
        return CVReadOnlyPixelBuffer(unsafeBuffer: buffer)
    }

    /// Fills `buffer` with opaque black and draws `image` over it; false
    /// when its memory can't be drawn into. Unlocked again before returning.
    private static func draw(_ image: CGImage, into buffer: CVPixelBuffer, width: Int, height: Int) -> Bool {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: base, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return false }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(bounds)
        context.draw(image, in: bounds)
        return true
    }

    private static func failure(_ writer: AVAssetWriter) -> HaloMovieWriterError {
        HaloMovieWriterError(
            description: "The movie couldn't be written: \(writer.error?.localizedDescription ?? "unknown error").")
    }
}
