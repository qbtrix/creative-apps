// PhotoPasteboardAdapter.swift (clipboard-interop CB-13, packet docs/blueprints/suiteui/features/clipboard-interop.md,
// slice CB-photo): Photo's side of the suite's pasteboard. Copy offers the pixels as PNG, then TIFF, as PhotoApp's
// PhotoPasteboard wrote them: pixels only, no source rect and no source metadata (RJ-X05). Paste takes the item
// SuitePasteboardCoding picks for Photo (any image, then an SVG last) and decodes it with the codec it was given; an
// SVG is drawn by the given rasterizer to fit the open canvas, keeping its aspect ratio. The encoders and the
// rasterizer are passed in, so the bytes are the app's ImageIO ones on macOS and CoreRaster's here; TIFF and SVG
// drawing wait on shared-codecs SC-photo for a Linux body. SuiteShell's PasteboardBridge carries the items to and
// from the system pasteboard. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel

/// Photo's Copy and Paste over the suite's `TypedData`.
public struct PhotoPasteboardAdapter: Sendable {
    /// An image as one file's bytes.
    public typealias Encode = @Sendable (DecodedImage) throws -> Data
    /// An SVG drawn at `width` x `height` pixels, straight 8-bit RGBA.
    public typealias Rasterize = @Sendable (_ svg: String, _ width: Int, _ height: Int) throws -> DecodedImage

    let codec: any PhotoImageCodec
    let tiff: Encode?
    let rasterize: Rasterize?
    let coder = SuitePasteboardCoding()

    /// `codec` writes the PNG and reads what is pasted; `tiff`, when given, writes the TIFF beside it;
    /// `rasterize`, when given, draws a pasted SVG.
    public init(codec: any PhotoImageCodec = CoreRasterImageCodec(), tiff: Encode? = nil, rasterize: Rasterize? = nil) {
        self.codec = codec; self.tiff = tiff; self.rasterize = rasterize
    }

    /// What Copy offers, richest first: the PNG, then the TIFF when it can be written. Empty if the PNG can't be.
    public func copy(_ image: ClipboardImage) -> [TypedData] {
        guard let png = pngItem(image.image) else { return [] }
        return [png] + (tiffItem(image.image).map { [$0] } ?? [])
    }

    func pngItem(_ image: DecodedImage) -> TypedData? {
        (try? codec.encode(image, as: .png, quality: 1)).map { TypedData(type: .png, data: $0) }
    }

    func tiffItem(_ image: DecodedImage) -> TypedData? {
        guard let tiff, let data = try? tiff(image) else { return nil }
        return TypedData(type: .tiff, data: data)
    }

    /// nil when Paste can take something from `offered`; else the coder's reason.
    public func pasteRefusal(_ offered: [TypedData]) -> SuiteError? {
        coder.pasteRefusal(for: offered, in: .photo)
    }

    /// The best item on offer as pixels with no source rect; an SVG fitted to `canvas` (its own size with none
    /// open). Throws the coder's refusal, or why the item couldn't be read.
    public func paste(_ offered: [TypedData], canvas: CanvasSize?) throws(SuiteError) -> ClipboardImage {
        if let refusal = pasteRefusal(offered) { throw refusal }
        let image: DecodedImage
        switch coder.bestItem(from: offered, for: .photo) {
        case .image(let bytes, _, _):
            do { image = try codec.decode(bytes, longestSide: nil) } catch { throw .damaged("The pasted image couldn't be read.") }
        case .vector(let svg, _): image = try drawn(svg, canvas: canvas)
        case .envelope(let envelope) where envelope.svg != nil: image = try drawn(envelope.svg ?? "", canvas: canvas)
        default: throw .cannotPaste(app: .photo, kind: "this")
        }
        return ClipboardImage(image: image, source: nil)
    }

    /// `svg` drawn at its size fitted to `canvas`.
    func drawn(_ svg: String, canvas: CanvasSize?) throws(SuiteError) -> DecodedImage {
        guard let rasterize else { throw .notAvailable("Pasting vector art as pixels isn't built here yet.") }
        let size = Self.fitted(Self.svgSize(svg), canvas: canvas)
        do { return try rasterize(svg, size.width, size.height) } catch { throw .damaged("The pasted vector art couldn't be drawn.") }
    }

    /// The pixel size to draw at: `own` scaled to fit `canvas` (up or down), `own` with no canvas, the canvas
    /// with no size of its own, 512 x 512 with neither. Never below 1 px.
    static func fitted(_ own: (width: Double, height: Double)?, canvas: CanvasSize?) -> (width: Int, height: Int) {
        guard let own, own.width > 0, own.height > 0 else {
            return canvas.map { (max($0.width, 1), max($0.height, 1)) } ?? (512, 512)
        }
        guard let canvas, canvas.width > 0, canvas.height > 0 else {
            return (max(Int(own.width.rounded()), 1), max(Int(own.height.rounded()), 1))
        }
        let scale = min(Double(canvas.width) / own.width, Double(canvas.height) / own.height)
        return (max(Int((own.width * scale).rounded()), 1), max(Int((own.height * scale).rounded()), 1))
    }

    /// The root `<svg>`'s size: its `width` and `height` in px (or unitless), else its `viewBox`'s; nil for neither.
    static func svgSize(_ svg: String) -> (width: Double, height: Double)? {
        guard let start = svg.firstRange(of: "<svg"), let end = svg[start.upperBound...].firstIndex(of: ">") else { return nil }
        let tag = String(svg[start.upperBound..<end])
        if let w = attribute("width", in: tag).flatMap(length), let h = attribute("height", in: tag).flatMap(length) {
            return (w, h)
        }
        let box = (attribute("viewBox", in: tag) ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        return box.count == 4 ? (box[2], box[3]) : nil
    }

    /// The value of attribute `name` in a tag's text, quoted with " or '.
    static func attribute(_ name: String, in tag: String) -> String? {
        for quote in ["\"", "'"] {
            for space in [" ", "\n", "\t"] {
                guard let open = tag.firstRange(of: space + name + "=" + quote),
                      let close = tag[open.upperBound...].firstRange(of: quote) else { continue }
                return String(tag[open.upperBound..<close.lowerBound])
            }
        }
        return nil
    }

    /// A length in px or with no unit; nil for a percentage or another unit.
    static func length(_ text: String) -> Double? {
        let trimmed = text.filter { $0 != " " }
        return Double(trimmed.hasSuffix("px") ? String(trimmed.dropLast(2)) : trimmed)
    }
}
