// FootageReader.swift: shell-media's footage reader (SM-8), the movie half of
// MediaDecoding: what a movie file is, and the exact frame it shows at a time.
//
// `info` reads the first video track: its natural size with the preferred
// transform applied (so a portrait phone clip reports portrait), its nominal
// frame rate, the asset's duration, and a frame count of round(seconds x fps).
// Alpha comes from the track's format description (the alpha extension, or the
// HEVC-with-alpha codec), audio from whether an audio track exists, and the
// codec is the format's four-character code ("avc1", "hvc1", "ap4h").
//
// `frame` asks an image generator for the frame at `seconds` with zero
// tolerance on both sides, so it is frame-accurate rather than the nearest
// keyframe, upright, and fitted to `longestSide` with its aspect kept. The
// image is drawn into sRGB and handed back as straight-alpha RGBA, top row
// first, the MediaFrame rule.
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation
import SuiteModel

public struct FootageReader: Sendable {
    public init() {}

    /// What the movie at `path` is: size, rate, length, alpha, audio, codec.
    public func info(ofMovieAt path: String) async throws(SuiteError) -> MediaInfo {
        let url = try Self.existing(path)
        do {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                throw SuiteError.readFailed("\(url.lastPathComponent) has no video")
            }
            let (size, transform, rate, formats) = try await track.load(
                .naturalSize, .preferredTransform, .nominalFrameRate, .formatDescriptions)
            let upright = size.applying(transform)
            let seconds = duration.seconds.isFinite ? max(duration.seconds, 0) : 0
            let fps = rate.isFinite ? max(Double(rate), 0) : 0
            let hasAudio = try await !asset.loadTracks(withMediaType: .audio).isEmpty
            return MediaInfo(
                width: Int(abs(upright.width).rounded()), height: Int(abs(upright.height).rounded()),
                seconds: seconds, fps: fps, frameCount: Int((seconds * fps).rounded()),
                hasAlpha: formats.contains(where: Self.hasAlpha), hasAudio: hasAudio,
                codec: formats.first.map { Self.fourCC(CMFormatDescriptionGetMediaSubType($0)) } ?? "")
        } catch {
            throw Self.suiteError(error, url)
        }
    }

    /// The exact frame shown at `seconds`, upright, shrunk to fit
    /// `longestSide` by `longestSide` when given.
    public func frame(ofMovieAt path: String, seconds: Double, longestSide: Int?) async throws(SuiteError) -> MediaFrame {
        let url = try Self.existing(path)
        guard seconds.isFinite, seconds >= 0 else { throw .notAvailable("A frame's time must be 0 s or later.") }
        if let longestSide, longestSide < 1 { throw .notAvailable("A frame must be at least 1 pixel on a side.") }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        if let longestSide { generator.maximumSize = CGSize(width: longestSide, height: longestSide) }
        let image: CGImage
        do {
            image = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        } catch {
            throw Self.suiteError(error, url)
        }
        guard let rgba = Self.straight(image) else {
            throw .readFailed("the frame of \(url.lastPathComponent) couldn't be read")
        }
        return try MediaFrame(width: image.width, height: image.height, rgba: rgba)
    }

    // MARK: Helpers

    private static func existing(_ path: String) throws(SuiteError) -> URL {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { throw .fileMissing(name: url.lastPathComponent) }
        return url
    }

    private static func suiteError(_ error: any Error, _ url: URL) -> SuiteError {
        if let error = error as? SuiteError { return error }
        if error is CancellationError { return .cancelled }
        return .readFailed("\(url.lastPathComponent) couldn't be read: \(error.localizedDescription)")
    }

    private static func hasAlpha(_ format: CMFormatDescription) -> Bool {
        if CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_HEVCWithAlpha { return true }
        let flag = CMFormatDescriptionGetExtension(format, extensionKey: kCMFormatDescriptionExtension_ContainsAlphaChannel)
        return (flag as? Bool) == true
    }

    /// The four characters of `code`, most significant byte first.
    private static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: code >> $0) }
        return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }

    /// `image` drawn into sRGB, its premultiplied bytes divided back out by
    /// alpha (an opaque or empty pixel is left as drawn).
    private static func straight(_ image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        for pixel in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Int(bytes[pixel + 3])
            guard alpha > 0, alpha < 255 else { continue }
            for channel in pixel..<(pixel + 3) {
                bytes[channel] = UInt8(min(255, (Int(bytes[channel]) * 255 + alpha / 2) / alpha))
            }
        }
        return bytes
    }
}
