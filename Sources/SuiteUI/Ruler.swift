// Ruler.swift: the rulers along the top and left of an editor canvas
// (CanvasViewport), in document pixels. RulerTicks is the tick layout, plain
// math tested on its own: document value v sits at view position
// origin + v * scale, the labelled step is the smallest 1, 2 or 5 times a
// power of ten (at least one pixel) whose spacing clears
// SuiteSize.rulerLabelSpacing, and minor ticks split it while they stay at
// least 5 points apart. Ruler draws them on a flat panel band with a hairline
// on its inner edge, labels in 10 pt monospaced digits; one view serves both
// axes. RulerCorner fills the square where the two rulers meet and names the
// document's unit ("px" by default); its text is hidden from accessibility,
// and a leaf element `suite.canvas.rulerUnit` labelled with the unit lets a
// journey read it. Invariants: every tick lies within the length, and there
// are never more than `maximumMarks` labelled ticks, whatever the scale.
import SwiftUI

public struct RulerTicks: Equatable, Sendable {
    /// One labelled tick: its position along the ruler and its text.
    public struct Mark: Equatable, Sendable {
        public let position: Double
        public let label: String
    }

    /// The most labelled ticks one ruler draws.
    public static let maximumMarks = 500

    /// Document pixels between labelled ticks.
    public let step: Double
    public let major: [Mark]
    /// Positions of the unlabelled ticks between them.
    public let minor: [Double]

    /// The ticks of a ruler `length` points long whose document 0 sits at
    /// `origin`, `scale` points per document pixel. A scale or length that
    /// isn't a positive finite number gives no ticks.
    public init(length: Double, origin: Double, scale: Double, minimumLabelSpacing: Double) {
        guard length.isFinite, length > 0, origin.isFinite, scale.isFinite, scale > 0 else {
            self.init(step: 1, major: [], minor: [])
            return
        }
        let step = Self.niceStep(atLeast: max(minimumLabelSpacing, 1) / scale)
        let leading = (step / pow(10, log10(step).rounded(.down))).rounded()
        let divisions = (leading == 2 ? [4, 2] : leading == 5 ? [5] : [10, 5, 2])
            .first { step * scale / Double($0) >= 5 } ?? 1
        var major: [Mark] = []
        var minor: [Double] = []
        let first = ((0 - origin) / scale / step).rounded(.down)
        let last = ((length - origin) / scale / step).rounded(.up)
        var index = first
        while index <= last, major.count < Self.maximumMarks {
            let value = index * step
            let position = origin + value * scale
            if position >= 0, position <= length { major.append(Mark(position: position, label: Self.label(value))) }
            for division in 1..<max(divisions, 1) {
                let tick = position + step * scale * Double(division) / Double(divisions)
                if tick >= 0, tick <= length { minor.append(tick) }
            }
            index += 1
        }
        self.init(step: step, major: major, minor: minor)
    }

    private init(step: Double, major: [Mark], minor: [Double]) {
        self.step = step
        self.major = major
        self.minor = minor
    }

    /// The smallest 1, 2 or 5 times a power of ten that is at least `units`,
    /// and never under one pixel.
    static func niceStep(atLeast units: Double) -> Double {
        guard units.isFinite, units > 1 else { return 1 }
        let power = pow(10, log10(units).rounded(.down))
        return [1.0, 2, 5, 10].map { $0 * power }.first { $0 >= units - 1e-9 } ?? 10 * power
    }

    /// Whole pixels read as integers ("1200", "-50").
    private static func label(_ value: Double) -> String {
        guard abs(value) < 1e15 else { return String(value) }
        return String(Int64(value.rounded()))
    }
}

/// One ruler: `axis` .horizontal runs along the top, .vertical down the left.
public struct Ruler: View {
    private let axis: Axis
    private let origin: Double
    private let scale: Double

    /// `origin` is where document 0 sits along the ruler, in points; `scale`
    /// is points per document pixel (the canvas zoom).
    public init(axis: Axis, origin: Double, scale: Double) {
        self.axis = axis
        self.origin = origin
        self.scale = scale
    }

    public var body: some View {
        Canvas { context, size in
            let horizontal = axis == .horizontal
            let length = horizontal ? size.width : size.height
            let ticks = RulerTicks(
                length: length, origin: origin, scale: scale, minimumLabelSpacing: SuiteSize.rulerLabelSpacing)
            let thickness = SuiteSize.ruler
            var path = Path()
            func tick(at position: Double, from start: CGFloat) {
                let p = CGFloat(position).rounded() + 0.5
                path.move(to: horizontal ? CGPoint(x: p, y: start) : CGPoint(x: start, y: p))
                path.addLine(to: horizontal ? CGPoint(x: p, y: thickness) : CGPoint(x: thickness, y: p))
            }
            for position in ticks.minor { tick(at: position, from: thickness - SuiteSize.rulerMinorTick) }
            for mark in ticks.major { tick(at: mark.position, from: 0) }
            context.stroke(path, with: .color(SuiteColor.rulerTick), lineWidth: 1)
            for mark in ticks.major {
                let text = context.resolve(
                    Text(mark.label).font(SuiteFont.rulerLabel).foregroundStyle(SuiteColor.secondaryText))
                let at = CGFloat(mark.position) + SuiteSpacing.xxs
                if horizontal {
                    context.draw(text, at: CGPoint(x: at, y: 0), anchor: .topLeading)
                } else {
                    var turned = context
                    turned.translateBy(x: 0, y: at)
                    turned.rotate(by: .degrees(-90))
                    turned.draw(text, at: .zero, anchor: .topTrailing)
                }
            }
        }
        .frame(
            width: axis == .vertical ? SuiteSize.ruler : nil,
            height: axis == .horizontal ? SuiteSize.ruler : nil)
        .background(SuiteColor.panel)
        .overlay {
            // A Divider runs across its stack: the hairline on the inner edge.
            if axis == .horizontal {
                VStack(spacing: 0) { Spacer(minLength: 0); Divider() }
            } else {
                HStack(spacing: 0) { Spacer(minLength: 0); Divider() }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The square where the top and left rulers meet, naming the document's unit.
public struct RulerCorner: View {
    /// The unit the corner names: "px", "pt", ...
    public let unit: String

    public init(unit: String = "px") {
        self.unit = unit
    }

    public var body: some View {
        Text(unit)
            .font(SuiteFont.rulerLabel)
            .foregroundStyle(SuiteColor.secondaryText)
            .frame(width: SuiteSize.ruler, height: SuiteSize.ruler)
            .background(SuiteColor.panel)
            .accessibilityHidden(true)
            .overlay {
                // A plain leaf, not text: a journey reads the unit without a contrast check on it.
                Color.clear
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(unit)
                    .accessibilityIdentifier("suite.canvas.rulerUnit")
                    .allowsHitTesting(false)
            }
    }
}
