// SuiteImageIO.swift: the suite's one ImageIO adapter (shared-codecs rule 20).
// No other file under Sources/ imports ImageIO (ImageIOImportRatchetTests).
// Shell-media's writers land the first calls here: one image encoded as a
// registry format, and frames written as an animated GIF or APNG. Shared-codecs'
// SC-2 and SC-4 add decoding, file info and the CoreRaster paths beside them.
// Formats come from SuiteImageFormats, so this file spells out no list of its own.
import CoreGraphics
import Foundation
import ImageIO
import SuiteModel

public enum SuiteImageIO {
    /// `image` as a complete `format` file; `quality` (0 to 1, clamped) sets
    /// lossy compression, nil leaves the format lossless.
    public static func encode(_ image: CGImage, as format: SuiteImageFormat, quality: Double?) throws(SuiteError) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, format.typeID.rawValue as CFString, 1, nil)
        else { throw .notAvailable("This Mac can't write \(format.title) images.") }
        var properties: [CFString: Any] = [:]
        if let quality { properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1) }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw .ioFailed("the \(format.title) image couldn't be encoded")
        }
        return data as Data
    }

    /// `frames` as a GIF at `url`: `loopCount` (0 loops forever) and each
    /// frame's delay in seconds, `delays[i]` for `frames[i]`.
    public static func writeGIF(_ frames: [CGImage], delays: [Double], loopCount: Int, to url: URL) throws(SuiteError) {
        try write(frames, as: SuiteImageFormat.gif, to: url,
                  file: [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]]) { index in
            let delay = delays.indices.contains(index) ? delays[index] : 0
            return [kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay,
            ]]
        }
    }

    /// `frames` as an APNG at `url`, with the same loop count and delays.
    public static func writeAPNG(_ frames: [CGImage], delays: [Double], loopCount: Int, to url: URL) throws(SuiteError) {
        try write(frames, as: SuiteImageFormat.png, to: url,
                  file: [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: loopCount]]) { index in
            let delay = delays.indices.contains(index) ? delays[index] : 0
            return [kCGImagePropertyPNGDictionary: [
                kCGImagePropertyAPNGDelayTime: delay, kCGImagePropertyAPNGUnclampedDelayTime: delay,
            ]]
        }
    }

    /// One destination for every frame: it needs the count when it is made.
    /// A failed write deletes what it wrote.
    private static func write(
        _ frames: [CGImage], as format: SuiteImageFormat, to url: URL, file: [CFString: Any],
        frame: (Int) -> [CFString: Any]
    ) throws(SuiteError) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, format.typeID.rawValue as CFString, frames.count, nil)
        else { throw .ioFailed("\(url.lastPathComponent) couldn't be created") }
        CGImageDestinationSetProperties(destination, file as CFDictionary)
        for (index, image) in frames.enumerated() {
            CGImageDestinationAddImage(destination, image, frame(index) as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: url)
            throw .ioFailed("\(url.lastPathComponent) couldn't be written")
        }
    }
}
