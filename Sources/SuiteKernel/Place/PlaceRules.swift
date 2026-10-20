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

    /// PNG by its signature, JPEG by `FF D8 FF`, SVG by `<?xml` or `<svg` after a BOM and whitespace; else nil.
    public static func format(of data: Data) -> PlacedFormat? { nil }
    /// FNV-1a 64 of the bytes in hex plus their count: equal bytes, equal ids.
    public static func assetID(of data: Data) -> String { "" }
    /// `natural` inside `canvas` by contain, never upscaled, centred on `point` (else the canvas centre), kept inside.
    public static func fitted(natural: Size, in canvas: Rect, at point: Point?) -> Rect { canvas }
    /// Where the asset draws for `image`: cover around the focus, clamped to cover the box; may exceed it.
    public static func drawnRect(_ image: PlacedImage, natural: Size) -> Rect { image.box }
    /// The box at the asset's natural aspect, the same width and centre.
    public static func resetBox(_ image: PlacedImage, natural: Size) -> Rect { image.box }
}
