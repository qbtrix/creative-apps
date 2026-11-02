// PlaceRules.swift (placed-images PL-1 stubs, PL-5 bodies): the sniff, the content id, the fit, the cover crop and
// the reset (contain and cover as in CSS `object-fit`); every draw takes its rect from `drawnRect`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum PlaceRules {
    /// What a place command's run throws until PL-7 builds the bodies.
    public static let notBuilt = CatalogError.notBuilt(id: "place", feature: "placed-images PL-7")
    /// The largest file Place takes (32 MB), and why a file of another kind or over it is refused.
    public static let maxBytes = 32 << 20
    public static let formatHelp = "Place takes PNG, JPEG or SVG files.", sizeHelp = "Place takes files up to 32 MB."
    /// Why a file of another kind is refused by a target that takes `formats`, naming only those:
    /// "Place takes PNG or JPEG files."; all three give `formatHelp`.
    public static func formatHelp(for formats: Set<PlacedFormat>) -> String {
        let names = PlacedFormat.allCases.filter(formats.contains).map { $0.rawValue.uppercased() }
        guard let last = names.last else { return formatHelp }
        let list = names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " or " + last
        return "Place takes \(list) files."
    }

    /// PNG by its signature, JPEG by `FF D8 FF`, SVG by `<?xml` or `<svg` after a BOM and whitespace, with `<svg`
    /// in the first 4 KB; else nil.
    public static func format(of data: Data) -> PlacedFormat? {
        let bytes = [UInt8](data.prefix(4096))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return .png }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return .jpeg }
        var head = bytes[...]
        if head.starts(with: [0xEF, 0xBB, 0xBF]) { head = head.dropFirst(3) }
        let text = head.drop { [0x20, 0x09, 0x0A, 0x0D].contains($0) }
        guard text.starts(with: Array("<?xml".utf8)) || text.starts(with: Array("<svg".utf8)) else { return nil }
        return String(decoding: text, as: UTF8.self).contains("<svg") ? .svg : nil
    }
    /// FNV-1a 64 of the bytes in hex plus their count: equal bytes, equal ids.
    public static func assetID(of data: Data) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let hex = String(hash, radix: 16, uppercase: false)
        return String(repeating: "0", count: max(0, 16 - hex.count)) + hex + "-\(data.count)"
    }
    /// `natural` inside `canvas` by contain, never upscaled, centred on `point` (else the canvas centre), kept inside.
    public static func fitted(natural: Size, in canvas: Rect, at point: Point?) -> Rect {
        guard natural.width > 0, natural.height > 0 else { return canvas }
        let scale = min(1, canvas.width / natural.width, canvas.height / natural.height)
        let (width, height) = (natural.width * scale, natural.height * scale)
        let centre = point ?? Point(x: (canvas.minX + canvas.maxX) / 2, y: (canvas.minY + canvas.maxY) / 2)
        let x = clamp(centre.x - width / 2, canvas.minX, canvas.maxX - width)
        let y = clamp(centre.y - height / 2, canvas.minY, canvas.maxY - height)
        return Rect(minX: x, minY: y, maxX: x + width, maxY: y + height)
    }
    /// Where the asset draws for `image`: cover around the focus, clamped to cover the box; may exceed it.
    public static func drawnRect(_ image: PlacedImage, natural: Size) -> Rect {
        let box = image.box
        guard natural.width > 0, natural.height > 0 else { return box }
        let scale = max(box.width / natural.width, box.height / natural.height)
        let (width, height) = (natural.width * scale, natural.height * scale)
        let fx = box.minX + (box.width - width) * image.focus.x, fy = box.minY + (box.height - height) * image.focus.y
        let x = clamp(fx, box.maxX - width, box.minX), y = clamp(fy, box.maxY - height, box.minY)
        return Rect(minX: x, minY: y, maxX: x + width, maxY: y + height)
    }
    /// The box at the asset's natural aspect, the same width and centre; `box` itself when it is already there, so a
    /// fitted box (whose height rounds differently by a few ulps) reads as reset.
    public static func resetBox(_ image: PlacedImage, natural: Size) -> Rect {
        let box = image.box
        guard natural.width > 0, natural.height > 0 else { return box }
        let height = box.width * natural.height / natural.width, midY = (box.minY + box.maxY) / 2
        if abs(height - box.height) <= 1e-9 * max(1, height) { return box }
        return Rect(minX: box.minX, minY: midY - height / 2, maxX: box.maxX, maxY: midY + height / 2)
    }

    /// `value` within `low...high`; `low` wins when the range is empty.
    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double { max(low, min(value, high)) }
}
