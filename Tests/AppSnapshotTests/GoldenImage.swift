// GoldenImage.swift: the live golden compare (QH-2, #331). `GoldenImage`
// conforms to SuiteUI's `GoldenComparing` (UC19): a per-channel tolerance and
// a share of differing pixels, with a diff image that paints the differing
// pixels magenta over a grey copy of the baseline.
//
// Baselines sit next to the test file that asserts them, found by #filePath:
// `<dir of the test file>/Golden/<area>/<name>-<appearance>.png`. A missing
// baseline writes the actual to `.build/snapshots/golden-new/<area>/` and
// records a known issue; a baseline that differs writes the actual and the
// diff to `.build/snapshots/golden-diff/<area>/` and fails. Golden/README.md
// holds the recording rule. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

/// The compare: different sizes or a malformed buffer fail with share 1.
struct GoldenImage: GoldenComparing, Sendable {
    func compare(_ actual: RGBAImage, to baseline: RGBAImage, tolerance: GoldenTolerance) -> GoldenResult {
        let pixels = Self.pixelCount(actual)
        guard pixels > 0, actual.width == baseline.width, actual.height == baseline.height,
              actual.bytes.count == pixels * 4, baseline.bytes.count == pixels * 4
        else { return GoldenResult(passes: false, differing: max(pixels, 1), share: 1, diff: nil) }
        let limit = Int(tolerance.channel)
        var differing = 0
        actual.bytes.withUnsafeBufferPointer { a in
            baseline.bytes.withUnsafeBufferPointer { b in
                var i = 0
                while i < a.count {
                    if Self.differs(a, b, at: i, limit: limit) { differing += 1 }
                    i += 4
                }
            }
        }
        let share = Double(differing) / Double(pixels)
        let diff = differing > 0 ? Self.diffImage(actual, baseline, limit: limit) : nil
        return GoldenResult(passes: share <= tolerance.maxShare, differing: differing, share: share, diff: diff)
    }

    /// width × height, or 0 when either is not positive or the product overflows.
    static func pixelCount(_ image: RGBAImage) -> Int {
        guard image.width > 0, image.height > 0 else { return 0 }
        let (count, overflow) = image.width.multipliedReportingOverflow(by: image.height)
        guard !overflow, count <= Int.max / 4 else { return 0 }
        return count
    }

    private static func differs(_ a: UnsafeBufferPointer<UInt8>, _ b: UnsafeBufferPointer<UInt8>,
                                at i: Int, limit: Int) -> Bool {
        abs(Int(a[i]) - Int(b[i])) > limit || abs(Int(a[i + 1]) - Int(b[i + 1])) > limit
            || abs(Int(a[i + 2]) - Int(b[i + 2])) > limit || abs(Int(a[i + 3]) - Int(b[i + 3])) > limit
    }

    /// Differing pixels in opaque magenta; every other pixel a light grey of the baseline's luma.
    private static func diffImage(_ actual: RGBAImage, _ baseline: RGBAImage, limit: Int) -> RGBAImage {
        var out = [UInt8](repeating: 255, count: baseline.bytes.count)
        actual.bytes.withUnsafeBufferPointer { a in
            baseline.bytes.withUnsafeBufferPointer { b in
                out.withUnsafeMutableBufferPointer { o in
                    var i = 0
                    while i < o.count {
                        if differs(a, b, at: i, limit: limit) {
                            o[i] = 255; o[i + 1] = 0; o[i + 2] = 255
                        } else {
                            let luma = (77 * Int(b[i]) + 150 * Int(b[i + 1]) + 29 * Int(b[i + 2])) >> 8
                            let grey = UInt8(truncatingIfNeeded: 128 + luma / 2)
                            o[i] = grey; o[i + 1] = grey; o[i + 2] = grey
                        }
                        i += 4
                    }
                }
            }
        }
        return RGBAImage(width: baseline.width, height: baseline.height, bytes: out)
    }
}

/// What one golden check found, with the files it wrote.
enum GoldenOutcome: Equatable {
    case matched(GoldenResult)
    case recorded(GoldenResult, actual: URL)
    case mismatched(GoldenResult, actual: URL, diff: URL?)

    var result: GoldenResult {
        switch self {
        case .matched(let r), .recorded(let r, _), .mismatched(let r, _, _): r
        }
    }
}

enum GoldenError: Error {
    case encode(String)
    case decode(String)
}

/// `<dir of filePath>/Golden/<area>/<name>-<appearance>.png`.
func goldenBaselineURL(name: String, area: String, appearance: String, filePath: String = #filePath) -> URL {
    URL(fileURLWithPath: filePath).deletingLastPathComponent()
        .appending(path: "Golden").appending(path: area).appending(path: "\(name)-\(appearance).png")
}

/// Compares `actual` with its baseline and writes the files the outcome names.
/// `output` defaults to `<package root>/.build/snapshots`.
func checkGolden(_ actual: RGBAImage, name: String, area: String, appearance: String,
                 tolerance: GoldenTolerance = .standard, filePath: String = #filePath,
                 output: URL? = nil) throws -> GoldenOutcome {
    let root = try output ?? packageRoot().appending(path: ".build/snapshots")
    let file = "\(name)-\(appearance)"
    let baselineURL = goldenBaselineURL(name: name, area: area, appearance: appearance, filePath: filePath)
    guard let data = try? Data(contentsOf: baselineURL) else {
        let url = try writePNG(actual, to: root.appending(path: "golden-new").appending(path: area), file: file)
        return .recorded(GoldenResult(passes: false, differing: max(GoldenImage.pixelCount(actual), 1), share: 1, diff: nil),
                         actual: url)
    }
    guard let baseline = RGBAImage(png: data) else { throw GoldenError.decode(baselineURL.path) }
    let result = GoldenImage().compare(actual, to: baseline, tolerance: tolerance)
    if result.passes { return .matched(result) }
    let folder = root.appending(path: "golden-diff").appending(path: area)
    let actualURL = try writePNG(actual, to: folder, file: file)
    let diffURL = try result.diff.map { try writePNG($0, to: folder, file: "\(file)-diff") }
    return .mismatched(result, actual: actualURL, diff: diffURL)
}

/// The test-facing check: passes on a match, records a known issue when the
/// baseline is missing, and fails on a mismatch or an I/O error.
func assertGolden(_ actual: RGBAImage, name: String, area: String, appearance: String,
                  tolerance: GoldenTolerance = .standard, filePath: String = #filePath, output: URL? = nil,
                  sourceLocation: SourceLocation = #_sourceLocation) {
    do {
        switch try checkGolden(actual, name: name, area: area, appearance: appearance,
                               tolerance: tolerance, filePath: filePath, output: output) {
        case .matched:
            return
        case .recorded(_, let url):
            withKnownIssue("no golden for \(area)/\(name)-\(appearance) yet; recorded \(url.path)",
                           sourceLocation: sourceLocation) {
                Issue.record("missing baseline \(area)/\(name)-\(appearance).png", sourceLocation: sourceLocation)
            }
        case .mismatched(let result, let url, _):
            Issue.record("\(area)/\(name)-\(appearance) differs: \(result.differing) pixels, share \(result.share); actual at \(url.path)",
                         sourceLocation: sourceLocation)
        }
    } catch {
        Issue.record(error, "golden \(area)/\(name)-\(appearance)", sourceLocation: sourceLocation)
    }
}

/// Renders `view` through the snapshot helper and checks it as `<name>-light` or `<name>-dark`.
@MainActor
func assertGolden(_ view: some View, name: String, area: String, scheme: ColorScheme,
                  tolerance: GoldenTolerance = .standard, filePath: String = #filePath,
                  sourceLocation: SourceLocation = #_sourceLocation) {
    guard let rep = render(view, scheme: scheme), let cg = rep.cgImage, let image = RGBAImage(cgImage: cg) else {
        Issue.record("could not render \(area)/\(name)", sourceLocation: sourceLocation)
        return
    }
    assertGolden(image, name: name, area: area, appearance: scheme == .dark ? "dark" : "light",
                 tolerance: tolerance, filePath: filePath, sourceLocation: sourceLocation)
}

private func writePNG(_ image: RGBAImage, to folder: URL, file: String) throws -> URL {
    guard let png = image.pngData() else { throw GoldenError.encode(file) }
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appending(path: "\(file).png")
    try png.write(to: url)
    return url
}

extension RGBAImage {
    /// Decodes a PNG into 8-bit sRGB RGBA. Opaque pixels round-trip exactly.
    init?(png: Data) {
        guard let cg = NSBitmapImageRep(data: png)?.cgImage else { return nil }
        self.init(cgImage: cg)
    }

    /// Draws `cgImage` into an 8-bit sRGB RGBA buffer, top row first.
    init?(cgImage: CGImage) {
        let w = cgImage.width, h = cgImage.height
        guard w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        self.init(width: w, height: h, bytes: bytes)
    }

    /// PNG bytes for this image, tagged sRGB; nil for a malformed buffer.
    func pngData() -> Data? {
        let pixels = GoldenImage.pixelCount(self)
        guard pixels > 0, bytes.count == pixels * 4,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: space,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent)
        else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
