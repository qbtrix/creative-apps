// PhotoNewImage+Kernel.swift (document-setup DS-8): Photo on SuiteKernel's DocumentSetup. File > New opens
// SuiteUI's NewDocumentSheet with Photo's presets and limits, and file.new takes the sheet's setup: the size
// in whole pixels at its resolution, the background as the one layer's fill, and the resolution kept on the
// workspace. A setup the limits refuse throws its first problem and leaves the open image as it was.
import CoreColor
import CoreRaster
import SuiteKernel
import SuiteModel

extension PhotoWorkspace {
    /// What Photo's New sheet allows: up to `maxSide` pixels a side, no frame rate or duration.
    public static let documentLimits = DocumentLimits(maxSide: maxSide)

    /// The New sheet's starting values: 1920 × 1080 px at 72 ppi on white.
    public static let newImageSetup = DocumentSetup(width: 1920, height: 1080)

    /// The New sheet's presets, in the parameters NewDocumentForm.pick reads.
    public static let newImagePresets: [NewDocumentPreset] = [
        preset("screen", "Screen", "1920 × 1080 px", ["width": "1920", "height": "1080"]),
        preset("square", "Square", "1080 × 1080 px", ["width": "1080", "height": "1080"]),
        preset("print-4x6", "Print 4 × 6 in", "1200 × 1800 px at 300 ppi",
               ["width": "4", "height": "6", "unit": "in", "resolution": "300"]),
        preset("letter", "Letter", "8.5 × 11 in at 300 ppi", ["width": "8.5", "height": "11", "unit": "in", "resolution": "300"]),
        preset("a4", "A4", "210 × 297 mm at 300 ppi", ["width": "210", "height": "297", "unit": "mm", "resolution": "300"]),
    ]

    static func preset(_ id: String, _ title: String, _ detail: String, _ parameters: [String: String]) -> NewDocumentPreset {
        NewDocumentPreset(id: "photo.\(id)", app: .photo, title: title, detail: detail, parameters: parameters)
    }

    /// Replaces the open image with a new one made to `setup`; throws the first problem `documentLimits` finds.
    public mutating func newImage(_ setup: DocumentSetup) throws {
        if let problem = setup.problems(Self.documentLimits).first { throw PhotoRefusal(problem.text) }
        let (width, height) = setup.pixelSize
        start(with: try TiledPixels(width: width, height: height, fill: Self.fill(setup.background)), name: nil)
        resolution = setup.resolution
    }

    /// The layer's fill for `background`, in the workspace's premultiplied linear sRGB: white, clear, or the hex colour.
    static func fill(_ background: DocumentBackground) -> RGBA {
        switch background {
        case .white: return RGBA(r: 1, g: 1, b: 1, a: 1)
        case .transparent: return .clear
        case .color(let hex):
            let digits = Array(hex.dropFirst())
            let bytes = stride(from: 0, to: digits.count - 1, by: 2).map { UInt8(String(digits[$0...$0 + 1]), radix: 16) ?? 0 }
            guard bytes.count >= 3 else { return RGBA(r: 1, g: 1, b: 1, a: 1) }
            let srgb = Color3(Double(bytes[0]) / 255, Double(bytes[1]) / 255, Double(bytes[2]) / 255)
            let linear = (try? srgb.converted(from: .sRGB, to: .linearSRGB)) ?? srgb
            let alpha = bytes.count > 3 ? Float(bytes[3]) / 255 : 1
            return RGBA(r: Float(linear.c0) * alpha, g: Float(linear.c1) * alpha, b: Float(linear.c2) * alpha, a: alpha) // premultiplied
        }
    }
}
