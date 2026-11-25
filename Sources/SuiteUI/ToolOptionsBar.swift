// ToolOptionsBar.swift: the contextual tool options bar an editor puts under
// its window toolbar, above the canvas: the active tool's options only, in one
// horizontal row of cells. `leading` (an app's paint color) stays put at the
// leading edge; the tool's controls sit after a hairline and scroll sideways
// when the column is too narrow, with no scroller (its parts are unnamed
// buttons to the app audit). The bar is always SuiteSize.toolOptionsBar high,
// whatever the tool, so the canvas under it never moves as tools change, and a
// hairline closes its bottom edge. It carries `suite.toolOptions`.
// ToolOptionsStack is how option views lay themselves out: a leading VStack in
// an inspector (the default), one row inside the bar, where each control gets
// at least SuiteSize.toolOptionsCell (its ideal width when wider) and is
// centred vertically. The bar tells it through the environment's
// `toolOptionsAxis`, so one option view serves both places. Owns no state.
import SwiftUI

public struct ToolOptionsBar<Leading: View, Content: View>: View {
    private let leading: Leading
    private let content: Content

    public init(@ViewBuilder leading: () -> Leading, @ViewBuilder content: () -> Content) {
        self.leading = leading()
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: SuiteSpacing.s) {
                ToolOptionsStack { leading }
                Divider().frame(height: SuiteSize.studioRow)
                ScrollView(.horizontal) {
                    ToolOptionsStack { content }
                        .frame(maxHeight: .infinity)
                }
                .scrollIndicators(.never)
            }
            .padding(.horizontal, SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            Divider()
        }
        .frame(height: SuiteSize.toolOptionsBar)
        .background(SuiteColor.panel)
        .environment(\.toolOptionsAxis, .horizontal)
        .controlSize(SuiteSize.compactControl)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.toolOptions")
    }
}

/// Option rows laid out for where they are: a leading VStack `spacing` apart in an inspector, one row of cells
/// at least SuiteSize.toolOptionsCell wide inside a ToolOptionsBar.
public struct ToolOptionsStack<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    @Environment(\.toolOptionsAxis) private var axis

    public init(spacing: CGFloat = SuiteSpacing.xs, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(ToolOptionsRowLayout(spacing: SuiteSpacing.s, minCell: SuiteSize.toolOptionsCell))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
        layout { content }
    }
}

/// One row: each subview `max(ideal, minCell)` wide, `spacing` apart, centred vertically.
struct ToolOptionsRowLayout: Layout {
    let spacing: CGFloat
    let minCell: CGFloat

    func widths(_ subviews: Subviews) -> [CGFloat] {
        subviews.map { max($0.sizeThatFits(.unspecified).width, minCell) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = widths(subviews)
        let height = zip(subviews, widths).map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
            .max() ?? 0
        let width = widths.reduce(0, +) + spacing * CGFloat(max(widths.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(subviews)) {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: nil))
            x += width + spacing
        }
    }
}

extension EnvironmentValues {
    /// `.horizontal` inside a ToolOptionsBar, where ToolOptionsStack lays out one row; `.vertical` elsewhere.
    @Entry public var toolOptionsAxis: Axis = .vertical
}
