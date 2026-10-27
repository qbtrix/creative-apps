// HaloStyledRuns.swift (layer-styles HY-7): what the viewer hands SuiteUI's GPU layer view. A draw list splits,
// bottom first, into Canvas runs and styled solids and shapes. A styled layer's content key drops its style, so a
// Glow Size scrub keeps the resident raster; its pixels are LiveFrameRendering's unstyled draw of it.
import CoreRaster
import SuiteImaging

/// A stretch of a draw list: plain layers the Canvas draws, or one styled layer.
public enum HaloStyledRun: Hashable, Sendable {
    case drawn([HaloDrawItem])
    case styled(HaloDrawItem)
}

extension HaloDrawList {
    /// The items in order, each styled solid or shape on its own, the rest in runs between them.
    public var styledRuns: [HaloStyledRun] {
        var runs: [HaloStyledRun] = [], plain: [HaloDrawItem] = []
        for item in items {
            guard Self.isStyled(item) else { plain.append(item); continue }
            if !plain.isEmpty { runs.append(.drawn(plain)) }
            (plain, runs) = ([], runs + [.styled(item)])
        }
        return plain.isEmpty ? runs : runs + [.drawn(plain)]
    }
    /// Whether the GPU view draws `item`: a solid or shape with a non-empty style.
    public static func isStyled(_ item: HaloDrawItem) -> Bool {
        guard item.kind == .solid || item.kind == .shape, let style = item.style else { return false }
        return style != .none
    }
    /// `item`'s pixels key: it with no style, at this list's size.
    public func styleContent(_ item: HaloDrawItem) -> AnyHashable {
        var bare = item
        bare.style = nil
        return AnyHashable([AnyHashable(bare), width, height])
    }

    /// `item`'s fill and stroke merged unstyled, linear premultiplied, at this list's size; nil when it is empty.
    public func stylePixels(_ item: HaloDrawItem) -> PixelBuffer? {
        guard var merged = try? PixelBuffer(width: width, height: height) else { return nil }
        let fill = LiveFrameRendering.placedFill(item, width: width, height: height, scaleX: 1, scaleY: 1)
            ?? LiveFrameRendering.coverageFill(item, width: width, height: height, scaleX: 1, scaleY: 1)
        let stroke = LiveFrameRendering.strokeFill(item, width: width, height: height, scaleX: 1, scaleY: 1)
        for layer in [fill, stroke] {
            if let layer, let next = try? composite(layer, onto: merged, mode: .normal, opacity: 1) { merged = next }
        }
        return merged
    }
}
