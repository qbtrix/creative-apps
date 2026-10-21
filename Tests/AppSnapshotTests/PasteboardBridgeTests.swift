// PasteboardBridgeTests.swift: clipboard-interop CB-4b/CB-4c (packet suiteui/features/clipboard-interop.md).
// SuiteShell's PasteboardBridge on a private named pasteboard, never the user's: a written PNG reads back as the
// same pixels with no GPS or MakerNote, with a TIFF beside it; SVG, own layer bytes and a file URL round-trip;
// two writes in a row bump the change count; and nothing in SuiteShell polls on a timer. Here rather than in
// SuiteUITests because only this target links SuiteShell. macOS only.
#if os(macOS)
import AppKit
import Foundation
import ImageIO
import SuiteModel
import Testing
import UniformTypeIdentifiers

@testable import SuiteShell

/// A 2 by 2 PNG with GPS and maker-note metadata, as a phone photo carries.
private func taggedPNG() throws -> Data {
    let pixels: [UInt8] = [255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
    let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
    let image = try #require(CGImage(
        width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    let out = NSMutableData()
    let dest = try #require(CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil))
    let props: [CFString: Any] = [
        kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 51.5, kCGImagePropertyGPSLatitudeRef: "N"],
        kCGImagePropertyMakerAppleDictionary: ["1": 7],
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "secret"],
    ]
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    #expect(CGImageDestinationFinalize(dest))
    return out as Data
}

/// The image's pixels as 8-bit RGBA, or nil.
private func pixels(_ data: Data) -> [UInt8]? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let drawn: Bool = buffer.withUnsafeMutableBytes { raw in
        guard let ctx = CGContext(
            data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
    }
    return drawn ? buffer : nil
}

/// The image's properties, or an empty dictionary.
private func properties(_ data: Data) -> [CFString: Any] {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else { return [:] }
    return props
}

@MainActor @Suite(.serialized) struct PasteboardBridgeTests {
    private func scratch() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("org.creativesuite.tests.pasteboard.\(UUID().uuidString)"))
    }

    @Test(.disabled("waits on CB-4c")) func aWrittenPNGReadsBackAsTheSameImageWithNoGPSOrMakerNote() throws {
        let pasteboard = scratch()
        defer { pasteboard.releaseGlobally() }
        let png = try taggedPNG()
        #expect(properties(png)[kCGImagePropertyGPSDictionary] != nil)   // the fixture really is tagged
        PasteboardBridge(pasteboard).write([TypedData(type: .png, data: png)])
        let offered = PasteboardBridge(pasteboard).offered()
        let back = try #require(offered.first { $0.type == .png }?.data)
        #expect(pixels(back) == pixels(png))
        for data in [back, pasteboard.data(forType: .tiff)].compactMap({ $0 }) {
            let props = properties(data)
            #expect(props[kCGImagePropertyGPSDictionary] == nil)
            #expect(props[kCGImagePropertyMakerAppleDictionary] == nil)
            #expect(props[kCGImagePropertyExifDictionary].map { "\($0)".contains("secret") } != true)
        }
        #expect(pasteboard.data(forType: .tiff) != nil)
    }

    @Test(.disabled("waits on CB-4c")) func svgOwnLayersAndAFileURLRoundTrip() {
        let pasteboard = scratch()
        defer { pasteboard.releaseGlobally() }
        let items = [
            TypedData(type: .designLayers, data: Data("{\"layers\":[]}".utf8)),
            TypedData(type: .svg, data: Data("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8)),
            TypedData(type: .fileURL, data: Data("file:///tmp/Poster.design".utf8)),
        ]
        PasteboardBridge(pasteboard).write(items)
        #expect(pasteboard.data(forType: NSPasteboard.PasteboardType("public.svg-image")) == items[1].data)
        let offered = PasteboardBridge(pasteboard).offered()
        for item in items { #expect(offered.contains(item)) }
    }

    @Test(.disabled("waits on CB-4c")) func twoWritesInARowBumpTheChangeCount() {
        let pasteboard = scratch()
        defer { pasteboard.releaseGlobally() }
        let bridge = PasteboardBridge(pasteboard)
        let start = bridge.changeCount
        bridge.write([TypedData(type: .plainText, data: Data("one".utf8))])
        let first = bridge.changeCount
        bridge.write([TypedData(type: .plainText, data: Data("two".utf8))])
        #expect(first > start)
        #expect(bridge.changeCount > first)
        #expect(bridge.offered() == [TypedData(type: .plainText, data: Data("two".utf8))])
    }

    @Test(.disabled("waits on CB-4c")) func nothingInSuiteShellPollsOnATimer() throws {
        let shell = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Sources/SuiteShell")
        let files = try #require(FileManager.default.enumerator(at: shell, includingPropertiesForKeys: nil))
        var sources = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            sources += 1
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(!text.contains("Timer."), "\(url.lastPathComponent) polls on a timer")
            #expect(!text.contains("Timer("), "\(url.lastPathComponent) polls on a timer")
        }
        #expect(sources > 0)
    }
}
#endif
