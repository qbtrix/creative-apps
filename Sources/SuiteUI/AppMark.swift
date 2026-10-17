// AppMark.swift: the suite's app marks, the one place in code that draws one.
// `AppMark(app:style:)` draws the mark of a SuiteApp (nil or .launcher: the
// AfterGlow suite mark) from AppMarkArt, the path data scripts/render-marks
// generates from Bundle/Marks/<App>.svg, the same SVGs the .icns PNGs come
// from. Never hand-draw a mark or name an SF Symbol for an app elsewhere;
// scripts/check-app-marks fails on that.
//
//   .icon   the dark tile and the coloured glyph: the app icon in a window
//   .glyph  the coloured glyph alone, filling the frame
//   .line   the monoline form in the foreground style: the switcher, sidebar
//           rows, New tiles and chips (`symbolSized()` lays it out like an
//           SF Symbol in the current font); its stroke never drops under
//           1 pt, so a chip-sized mark doesn't turn to a hairline
//
// At an icon size of 32 pt and under, .icon and .glyph draw the SVG's -small
// groups (a heavier rim, a simpler, lighter glyph) so each mark keeps its own
// silhouette in grayscale at 16 px; Bundle/Icons switches at the same size.
// The mark is decorative to accessibility: the control around it names the app.
import SuiteModel
import SwiftUI

public struct AppMark: View {
    public enum Style: Sendable, CaseIterable { case icon, glyph, line }

    private let app: SuiteApp
    private let style: Style

    /// nil draws the AfterGlow suite mark, as `.launcher` does.
    public init(app: SuiteApp?, style: Style = .icon) {
        self.app = app ?? .launcher
        self.style = style
    }

    public var body: some View {
        Canvas { context, size in
            if let art = AppMarkArt.all[app.rawValue] { Self.draw(art, style, in: context, size: size) }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// Sized like an SF Symbol in the current font and image scale: a hidden
    /// symbol takes the room, the mark draws over it. For a Label's icon.
    public func symbolSized() -> some View {
        Image(systemName: "square").hidden().overlay { self }
    }

    /// The part of the 1024 grid a style fills its frame with: the whole icon,
    /// the glyph's box (the -small glyph reaches 180...844), or the line's 24-unit box.
    nonisolated static func box(_ style: Style) -> CGRect {
        switch style {
        case .icon: CGRect(x: 0, y: 0, width: AppMarkArt.grid, height: AppMarkArt.grid)
        case .glyph: CGRect(x: 180, y: 180, width: 664, height: 664)
        case .line: CGRect(x: 232, y: 232, width: 560, height: 560)
        }
    }

    /// Whether a mark `side` points wide in `style` draws the -small groups:
    /// when the icon it stands for is `AppMarkArt.smallSide` or under.
    nonisolated static func drawsSmall(_ style: Style, side: CGFloat) -> Bool {
        style != .line && side * AppMarkArt.grid / box(style).width <= AppMarkArt.smallSide
    }

    /// The elements `style` draws at `side` points, back to front.
    nonisolated static func elements(_ art: AppMarkArt, _ style: Style, side: CGFloat) -> [AppMarkArt.Element] {
        let small = drawsSmall(style, side: side)
        switch style {
        case .icon: return art.tile + (small ? art.tileSmall + art.glyphSmall : art.glyph)
        case .glyph: return small ? art.glyphSmall : art.glyph
        case .line: return art.line
        }
    }

    /// The thinnest .line stroke, in points: the art's 1.6 of 24 units is
    /// 0.6 pt in a 10 pt chip, a hairline beside its label.
    nonisolated static let minLineWidth: CGFloat = 1

    /// The stroke width, in grid units, an element of art width `width` draws
    /// with in `style` at `side` points: .line holds `minLineWidth`.
    nonisolated static func lineWidth(_ width: Double, _ style: Style, side: CGFloat) -> Double {
        guard style == .line, side > 0 else { return width }
        return max(width, Double(minLineWidth * box(style).width / side))
    }

    static func draw(_ art: AppMarkArt, _ style: Style, in context: GraphicsContext, size: CGSize) {
        let side = min(size.width, size.height)
        guard side > 0 else { return }
        let box = box(style)
        var context = context
        context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
        context.scaleBy(x: side / box.width, y: side / box.height)
        context.translateBy(x: -box.minX, y: -box.minY)
        for element in elements(art, style, side: side) {
            element.draw(in: context, monochrome: style == .line, width: lineWidth(element.width, style, side: side))
        }
    }
}

/// One mark's art on the 1024 icon grid, as scripts/render-marks writes it in
/// AppMarkArt.swift: the SVG's tile, tile-small, glyph, glyph-small and line groups.
struct AppMarkArt: Sendable {
    /// The icon grid: the SVGs' viewBox.
    static let grid: CGFloat = 1024
    /// The largest icon size that draws the -small groups (render-marks' SMALL).
    static let smallSide: CGFloat = 32

    struct Stop: Sendable {
        let at: Double, rgb: UInt32, alpha: Double
        init(_ at: Double, _ rgb: UInt32, _ alpha: Double) {
            self.at = at
            self.rgb = rgb
            self.alpha = alpha
        }
    }

    enum Paint: Sendable {
        case solid(UInt32, Double)
        /// Stops, then the start and end points.
        case linear([Stop], Double, Double, Double, Double)
        /// Stops, then the center and radius (the focus is the center).
        case radial([Stop], Double, Double, Double)
    }

    /// Absolute path operations: move, line, cubic, close.
    enum Op: Sendable {
        case m(Double, Double), l(Double, Double), c(Double, Double, Double, Double, Double, Double), z
    }

    struct Element: Sendable {
        let ops: [Op]
        let fill: Paint?
        let stroke: Paint?
        let width: Double
        let roundCap: Bool
        let roundJoin: Bool
        let opacity: Double
    }

    let tile: [Element], tileSmall: [Element], glyph: [Element], glyphSmall: [Element], line: [Element]
}

extension AppMarkArt.Element {
    var path: Path {
        var path = Path()
        for op in ops {
            switch op {
            case let .m(x, y): path.move(to: CGPoint(x: x, y: y))
            case let .l(x, y): path.addLine(to: CGPoint(x: x, y: y))
            case let .c(x1, y1, x2, y2, x, y):
                path.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
            case .z: path.closeSubpath()
            }
        }
        return path
    }

    /// Fills, then strokes `width` wide; `monochrome` paints in the foreground style instead of the art's colours.
    func draw(in context: GraphicsContext, monochrome: Bool, width: Double) {
        var context = context
        context.opacity *= opacity
        let path = path
        if let fill { context.fill(path, with: fill.shading(monochrome: monochrome)) }
        if let stroke {
            let style = StrokeStyle(lineWidth: width, lineCap: roundCap ? .round : .butt, lineJoin: roundJoin ? .round : .miter)
            context.stroke(path, with: stroke.shading(monochrome: monochrome), style: style)
        }
    }
}

extension AppMarkArt.Paint {
    func shading(monochrome: Bool) -> GraphicsContext.Shading {
        if monochrome { return .foreground }
        switch self {
        case let .solid(rgb, alpha):
            return .color(SuiteHex(rgb, rgb, rgb, rgb).color(alpha: alpha))
        case let .linear(stops, x1, y1, x2, y2):
            return .linearGradient(Self.gradient(stops), startPoint: CGPoint(x: x1, y: y1), endPoint: CGPoint(x: x2, y: y2))
        case let .radial(stops, x, y, radius):
            return .radialGradient(Self.gradient(stops), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: radius)
        }
    }

    private static func gradient(_ stops: [AppMarkArt.Stop]) -> Gradient {
        Gradient(stops: stops.map {
            Gradient.Stop(color: SuiteHex($0.rgb, $0.rgb, $0.rgb, $0.rgb).color(alpha: $0.alpha), location: $0.at)
        })
    }
}
