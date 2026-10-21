// AnimatedImageWriter.swift: shell-media's GIF and APNG writer (SM-6), the
// suite's one way to turn frames into an animated image file.
//
// A FrameSink for one file at the settings' size. An ImageIO destination needs
// its frame count when it is created, so `append` keeps each frame as an image
// and `finish()` writes them all through one `CGImageDestination`: the loop
// count (0 loops forever) in the file properties, and each frame's delay in its
// own. GIF delays are FrameClock's whole centiseconds, which carry the
// rounding so n frames last exactly round(100 n / fps) cs; APNG delays are
// 1 / fps. Palette reduction for GIF is ImageIO's. Both keep alpha (GIF as one
// transparent palette entry). The file isn't touched until `finish()`;
// `cancel()` drops the frames and deletes any file written so far.
import CoreGraphics
import Foundation
import ImageIO
import SuiteModel
import UniformTypeIdentifiers

public final class AnimatedImageWriter: FrameSink, @unchecked Sendable {
    private let url: URL
    private let settings: AnimatedImageSettings
    // Every access to the two below holds `lock`; that is what makes the
    // unchecked Sendable conformance sound.
    private let lock = NSLock()
    private var frames: [CGImage] = []
    private var open = true

    /// Starts a GIF or APNG at `path`; refuses a path that already has a file
    /// and settings the format can't hold.
    public init(path: String, _ settings: AnimatedImageSettings) throws(SuiteError) {
        let url = URL(fileURLWithPath: path)
        guard settings.width > 0, settings.height > 0, settings.fps > 0 else {
            throw .notAvailable("The animation needs a size and a frame rate.")
        }
        guard (0...65_535).contains(settings.loopCount) else {
            throw .notAvailable("The loop count must be from 0 (forever) to 65,535.")
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw .notAvailable("A file named \(url.lastPathComponent) already exists.")
        }
        self.url = url
        self.settings = settings
    }

    public func append(_ frame: MediaFrame) throws(SuiteError) {
        guard frame.width == settings.width, frame.height == settings.height else {
            throw .notAvailable(
                "A \(frame.width) by \(frame.height) frame doesn't fit a \(settings.width) by \(settings.height) animation.")
        }
        guard let image = StillEncoder.image(frame) else {
            throw .notAvailable("The frame's pixels couldn't be read.")
        }
        lock.lock()
        defer { lock.unlock() }
        guard open else { throw .notAvailable("The animation is already finished or cancelled.") }
        frames.append(image)
    }

    public func finish() async throws(SuiteError) {
        lock.lock()
        let frames = self.frames, wasOpen = open
        self.frames = []
        open = false
        lock.unlock()
        guard wasOpen else { return }
        guard !frames.isEmpty else { throw .notAvailable("The animation has no frames.") }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, Self.type(settings.format), frames.count, nil)
        else { throw .ioFailed("\(url.lastPathComponent) couldn't be created") }
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        var clock = try FrameClock(fps: settings.fps)
        for image in frames {
            CGImageDestinationAddImage(destination, image, frameProperties(&clock) as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: url)
            throw .ioFailed("\(url.lastPathComponent) couldn't be written")
        }
    }

    public func cancel() {
        lock.lock()
        frames = []
        open = false
        lock.unlock()
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: Properties

    private static func type(_ format: AnimatedImageFormat) -> CFString {
        (format == .gif ? UTType.gif : UTType.png).identifier as CFString
    }

    /// The loop count, under the format's dictionary.
    private var fileProperties: [CFString: Any] {
        switch settings.format {
        case .gif: [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: settings.loopCount]]
        case .apng: [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: settings.loopCount]]
        }
    }

    /// The next frame's delay, under the format's dictionary: the clock's
    /// carried centiseconds for GIF, 1 / fps for APNG.
    private func frameProperties(_ clock: inout FrameClock) -> [CFString: Any] {
        switch settings.format {
        case .gif:
            let delay = Double(clock.nextGIFDelay()) / 100
            return [kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay,
            ]]
        case .apng:
            let delay = 1 / Double(settings.fps)
            return [kCGImagePropertyPNGDictionary: [
                kCGImagePropertyAPNGDelayTime: delay, kCGImagePropertyAPNGUnclampedDelayTime: delay,
            ]]
        }
    }
}
