// MovieWriter.swift: shell-media's movie writer (SM-5), the suite's one
// canonical way to turn frames into a movie file. Moved from Halo's
// `HaloMovieWriter` (render-out RO-7), which stays in HaloApp until Halo's W3
// adoption swaps it for `services.media` and deletes it; new code writes
// movies through this type only.
//
// A FrameSink that writes one movie at the settings' size and whole-number
// rate in one of four codecs (H.264, HEVC, HEVC with alpha, ProRes 4444),
// tagged BT.709 (primaries, transfer function and YCbCr matrix). Frame i is
// presented at i / fps and the session ends at frames / fps, so 48 frames at
// 24 fps are exactly 2 s. The alpha codecs keep each frame's alpha; H.264 and
// HEVC draw the frame over opaque black, Halo's rule. `cancel()` cancels the
// writer and deletes the partial file.
//
// It uses the macOS 26 receiver API (`inputPixelBufferReceiver(for:)`,
// `start()`, `appendImmediately(_:with:)`); the pixel buffer adaptor and
// `startWriting()` are deprecated at the deployment target. `append` is
// synchronous, so a frame the input isn't ready for is retried after a short
// sleep; `finish()` awaits `finishWriting`'s completion handler.
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import SuiteModel
import VideoToolbox

public final class MovieWriter: FrameSink, @unchecked Sendable {
    /// The codecs this Mac's writer offers: all four, less HEVC with alpha
    /// when no installed encoder writes it.
    public static var codecs: [MovieCodec] {
        var list: CFArray?
        let found = VTCopyVideoEncoderList(nil, &list) == noErr
            ? (((list as NSArray?) as? [[String: Any]]) ?? []).compactMap {
                ($0[kVTVideoEncoderList_CodecType as String] as? NSNumber)?.uint32Value
            }
            : []
        return MovieCodec.allCases.filter { $0 != .hevcAlpha || found.contains(kCMVideoCodecType_HEVCWithAlpha) }
    }

    /// How long one frame may wait for the encoder before `append` fails.
    private let frameTimeout: TimeInterval = 30

    private let url: URL
    private let settings: MovieSettings
    // Every access to the four below holds `lock`; that is what makes the
    // unchecked Sendable conformance sound.
    private let lock = NSLock()
    private var writer: AVAssetWriter?
    private var receiver: AVAssetWriterInput.PixelBufferReceiver?
    private var written = 0

    /// Starts a movie at `path`; refuses a path that already has a file and
    /// settings the codec can't write.
    public init(path: String, _ settings: MovieSettings) throws(SuiteError) {
        let url = URL(fileURLWithPath: path)
        guard settings.width > 0, settings.height > 0, settings.fps > 0 else {
            throw .notAvailable("The movie needs a size and a frame rate.")
        }
        if settings.codec.needsEvenSize, settings.width % 2 != 0 || settings.height % 2 != 0 {
            throw .notAvailable("Width and height must be even for \(Self.name(settings.codec)).")
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw .notAvailable("A file named \(url.lastPathComponent) already exists.")
        }
        let output = Self.outputSettings(settings)
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: Self.fileType(url, settings.codec))
        } catch {
            throw .ioFailed("The movie couldn't be created: \(error.localizedDescription).")
        }
        // Checked before the input exists: an input with settings the writer
        // can't apply raises instead of throwing.
        guard writer.canApply(outputSettings: output, forMediaType: .video) else {
            throw .notAvailable("This Mac can't write \(Self.name(settings.codec)) into \(url.lastPathComponent).")
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: output)
        let timeScale = CMTimeScale(settings.fps * 100)
        input.mediaTimeScale = timeScale
        writer.movieTimeScale = timeScale
        guard writer.canAdd(input) else {
            throw .notAvailable("The movie writer refused a \(Self.name(settings.codec)) video track.")
        }
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: nil)
        do {
            try writer.start()
        } catch {
            throw .ioFailed("The movie couldn't start: \(error.localizedDescription).")
        }
        writer.startSession(atSourceTime: .zero)
        self.url = url
        self.settings = settings
        self.writer = writer
        self.receiver = receiver
    }

    public func append(_ frame: MediaFrame) throws(SuiteError) {
        guard frame.width == settings.width, frame.height == settings.height else {
            throw .notAvailable(
                "A \(frame.width) by \(frame.height) frame doesn't fit a \(settings.width) by \(settings.height) movie.")
        }
        lock.lock()
        defer { lock.unlock() }
        guard let writer, let receiver else {
            throw .notAvailable("The movie is already finished or cancelled.")
        }
        let buffer = try pixelBuffer(frame)
        let time = CMTime(value: CMTimeValue(written), timescale: CMTimeScale(settings.fps))
        let deadline = Date().addingTimeInterval(frameTimeout)
        while true {
            let taken: Bool
            do { taken = try receiver.appendImmediately(buffer, with: time) } catch { throw Self.failure(writer) }
            if taken { break }
            if writer.status == .failed { throw Self.failure(writer) }
            guard Date() < deadline else { throw .timedOut }
            Thread.sleep(forTimeInterval: 0.002)
        }
        written += 1
    }

    public func finish() async throws(SuiteError) {
        // `withLock`, not lock()/unlock(): NSLock's pair is unavailable from async code.
        let (writer, receiver, frames) = lock.withLock {
            let taken = (self.writer, self.receiver, written)
            self.writer = nil
            self.receiver = nil
            return taken
        }
        guard let writer, let receiver else { return }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frames), timescale: CMTimeScale(settings.fps)))
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            writer.finishWriting { done.resume() }
        }
        guard writer.status == .completed else { throw Self.failure(writer) }
    }

    public func cancel() {
        lock.lock()
        let writer = self.writer
        self.writer = nil
        self.receiver = nil
        lock.unlock()
        writer?.cancelWriting()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Settings

    private static func name(_ codec: MovieCodec) -> String {
        switch codec {
        case .h264: "H.264"
        case .hevc: "HEVC"
        case .hevcAlpha: "HEVC with alpha"
        case .prores4444: "ProRes 4444"
        }
    }

    /// MPEG-4 for an `.mp4` or `.m4v` path of a codec it carries; QuickTime otherwise.
    private static func fileType(_ url: URL, _ codec: MovieCodec) -> AVFileType {
        switch (url.pathExtension.lowercased(), codec) {
        case ("mp4", .h264), ("mp4", .hevc): .mp4
        case ("m4v", .h264), ("m4v", .hevc): .m4v
        default: .mov
        }
    }

    /// The codec at the settings' size, BT.709 throughout. H.264 and HEVC get
    /// a bit rate from the quality (0.8 is Halo's half a bit a pixel); ProRes
    /// takes no bit rate.
    private static func outputSettings(_ settings: MovieSettings) -> [String: Any] {
        let codec: AVVideoCodecType = switch settings.codec {
        case .h264: .h264
        case .hevc: .hevc
        case .hevcAlpha: .hevcWithAlpha
        case .prores4444: .proRes4444
        }
        var output: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: settings.width,
            AVVideoHeightKey: settings.height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        if settings.codec != .prores4444 {
            let quality = min(max(settings.quality, 0), 1)
            let pixelsPerSecond = Double(settings.width) * Double(settings.height) * Double(settings.fps)
            output[AVVideoCompressionPropertiesKey] = [
                AVVideoAverageBitRateKey: max(100_000, Int(pixelsPerSecond * (0.1 + 0.5 * quality))),
            ]
        }
        return output
    }

    // MARK: Frames

    /// `frame` as a BGRA buffer: cleared (alpha codecs) or opaque black, then
    /// the frame's sRGB pixels over it, tagged BT.709 like the track.
    private func pixelBuffer(_ frame: MediaFrame) throws(SuiteError) -> CVReadOnlyPixelBuffer {
        guard let image = Self.image(frame) else {
            throw .notAvailable("The frame's pixels couldn't be read.")
        }
        let attributes: [String: Any] = [
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ]
        var created: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, frame.width, frame.height, kCVPixelFormatType_32BGRA,
            attributes as CFDictionary, &created)
        guard status == kCVReturnSuccess, let buffer = created else {
            throw .notAvailable("No memory for a \(frame.width) by \(frame.height) movie frame.")
        }
        guard Self.draw(image, into: buffer, keepAlpha: settings.codec.keepsAlpha) else {
            throw .notAvailable("The frame couldn't be drawn.")
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

    /// The frame's straight-alpha sRGB bytes as an image.
    private static func image(_ frame: MediaFrame) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(frame.rgba) as CFData)
        else { return nil }
        return CGImage(
            width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: frame.width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// Clears `buffer` (or fills it with opaque black) and draws `image` over
    /// it; false when its memory can't be drawn into. Unlocked again before returning.
    private static func draw(_ image: CGImage, into buffer: CVPixelBuffer, keepAlpha: Bool) -> Bool {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: base, width: width, height: height, bitsPerComponent: 8,
                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return false }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        if keepAlpha {
            context.clear(bounds)
        } else {
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(bounds)
        }
        context.draw(image, in: bounds)
        return true
    }

    private static func failure(_ writer: AVAssetWriter) -> SuiteError {
        .ioFailed("The movie couldn't be written: \(writer.error?.localizedDescription ?? "unknown error").")
    }
}
