// FakeRawDecoder.swift: a fixed RAW table for tests on every platform
// (shared-raw SR-2). Photo's and Library's slices, and SuiteRaw's own tests,
// run on it where Core Image doesn't exist. By the file name's extension, any
// case:
//   .DNG  "AfterGlow Test", 64 x 48 with a 32 x 24 preview, baseline +1 stop;
//   .ARW  "Unreleased X1", undevelopable, preview only (32 x 24);
//   .NEF  (holding non-RAW bytes) and anything else: unreadable.
// A develop is `RawHeadroomFixture`'s scene, two highlight patches at 0.70 and
// 0.90 linear, before the baseline (SuiteRaw applies it); a preview is the
// marker colour, which the scene never holds. Linux-safe.
import CoreRaster

/// The fake's picture: the tiny test DNG's scene, upright, linear, alpha 1.
public enum RawHeadroomFixture {
    public static let width = 64, height = 48, previewWidth = 32, previewHeight = 24
    /// The two 16 x 16 highlight patches' top-left corners, and their linear level.
    public static let patches: [(x: Int, y: Int)] = [(8, 8), (40, 8)]
    public static let highlights: [Double] = [0.70, 0.90]
    /// The preview's fill, magenta, which the neutral scene never holds.
    public static let marker = RGBA(r: 1, g: 0, b: 1, a: 1)

    /// A patch's level, or the grey ramp from 0 to 0.5 left to right, one level per two columns.
    public static func scene(x: Int, y: Int) -> Double {
        for (p, level) in zip(patches, highlights) where (p.x..<p.x + 16).contains(x) && (p.y..<p.y + 16).contains(y) {
            return level
        }
        return 0.5 * Double(x / 2) / Double(width / 2 - 1)
    }
}

public struct FakeRawDecoder: RawDecoding {
    public init() {}

    struct Row {
        var camera: String
        var developable: Bool
        var baselineStops: Double
    }

    /// The table row for `source`, or `.unreadable` for a name it doesn't list.
    func row(_ source: RawSource) throws(RawRefusal) -> (RawFormat, Row) {
        let name = source.fileName
        let ext = name.lastIndex(of: ".").map { String(name[name.index(after: $0)...]) } ?? ""
        let format = RawFormat(checkedExtension: ext)
        switch format.fileExtension {
        case "DNG": return (format, Row(camera: "AfterGlow Test", developable: true, baselineStops: 1))
        case "ARW": return (format, Row(camera: "Unreleased X1", developable: false, baselineStops: 0))
        default: throw .unreadable(format)
        }
    }

    public func info(_ source: RawSource) throws(RawRefusal) -> RawFileInfo {
        let (format, row) = try row(source)
        typealias F = RawHeadroomFixture
        return RawFileInfo(format: format, camera: row.camera, developable: row.developable,
                           size: RawSize(width: F.width, height: F.height),
                           previewSize: RawSize(width: F.previewWidth, height: F.previewHeight),
                           baselineStops: row.baselineStops)
    }

    /// The marker colour at `longestSide`, never enlarged past the preview's 32 x 24.
    public func embeddedPreview(_ source: RawSource, longestSide: Int) throws(RawRefusal) -> PixelBuffer {
        let (format, _) = try row(source)
        typealias F = RawHeadroomFixture
        let width = max(1, min(longestSide, F.previewWidth))
        let height = max(1, Int((Double(width * F.previewHeight) / Double(F.previewWidth)).rounded()))
        do {
            return try PixelBuffer(width: width, height: height, fill: F.marker)
        } catch {
            throw .unreadable(format)
        }
    }

    /// The scene at `scale` (0 < scale <= 1, nearest sample), before the baseline.
    public func develop(_ source: RawSource, scale: Double, draft: Bool) throws(RawRefusal) -> PixelBuffer {
        let (format, row) = try row(source)
        guard row.developable else { throw .undevelopable(camera: row.camera) }
        typealias F = RawHeadroomFixture
        let s = scale.isFinite && scale > 0 ? min(scale, 1) : 1
        let width = max(1, Int((Double(F.width) * s).rounded()))
        let height = max(1, Int((Double(F.height) * s).rounded()))
        do {
            var buffer = try PixelBuffer(width: width, height: height)
            for y in 0..<height {
                for x in 0..<width {
                    let v = Float(F.scene(x: min(F.width - 1, Int(Double(x) / s)), y: min(F.height - 1, Int(Double(y) / s))))
                    try buffer.setPixel(x: x, y: y, RGBA(r: v, g: v, b: v, a: 1))
                }
            }
            return buffer
        } catch {
            throw .unreadable(format)
        }
    }
}
