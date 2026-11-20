// SidePanel.swift: a panel an app shows beside a SuiteWindow's columns (Design's History),
// `.suiteSidePanel(isShown:inspectorWidth:) { panel }` on the window's root. Where the window is
// wide enough for its columns at their minimums plus the panel, the panel sits beside them in a
// GlassPanel at SuiteSize.editorPanelWidth. Narrower, it takes the inspector column's place: it
// goes down the environment as `suiteInspectorSwap`, which SuiteWindow shows in that column
// (presenting it even when the user hid the inspector), and the inspector comes back when the
// panel closes (captain 2026-10-24, #4291). The width compared is the one the window proposes,
// read by a zero-height probe the root never measures; the row's own width runs past a window
// sized below its minimum (the journeys' 1024 pt runner), so it can't decide.
import SwiftUI

/// The panel SuiteWindow shows in its inspector column instead of the inspector; nil shows the inspector.
public struct InspectorSwap {
    let content: AnyView
}

/// A plain key rather than `@Entry`, as in Glass.swift.
private struct InspectorSwapKey: EnvironmentKey {
    static var defaultValue: InspectorSwap? { nil }
}

extension EnvironmentValues {
    /// The panel that takes the window's inspector column while set (SidePanel.swift).
    public var suiteInspectorSwap: InspectorSwap? {
        get { self[InspectorSwapKey.self] }
        set { self[InspectorSwapKey.self] = newValue }
    }
}

extension SuiteSize {
    /// The narrowest window whose sidebar, content and inspector all fit: the column minimums SuiteWindow
    /// lays out, with `inspectorWidth` (an editor's panel) in the inspector token's place when given.
    public static func windowMinimumWidth(inspectorWidth: CGFloat?) -> CGFloat {
        let inspector = inspectorWidth.flatMap { $0 > 0 ? $0 : nil } ?? self.inspectorWidth.ideal
        return sidebarWidth.ideal + contentMinimum.width + inspector
    }

    /// The width a side panel takes beside the columns: its panel width and its inset on both sides.
    public static let sidePanelWidth: CGFloat = editorPanelWidth + 2 * SuiteSpacing.s

    /// Whether a side panel fits beside the columns of a window `windowWidth` wide.
    public static func sidePanelFits(windowWidth: CGFloat, inspectorWidth: CGFloat?) -> Bool {
        windowWidth >= windowMinimumWidth(inspectorWidth: inspectorWidth) + sidePanelWidth
    }
}

extension View {
    /// Shows `panel` beside the window's columns while `isShown`, or in its inspector column when the
    /// window is too narrow for both. `inspectorWidth` is the one the window's SuiteWindow was given.
    public func suiteSidePanel<Panel: View>(
        isShown: Bool, inspectorWidth: CGFloat?, @ViewBuilder panel: () -> Panel
    ) -> some View {
        modifier(SidePanelArea(isShown: isShown, inspectorWidth: inspectorWidth, panel: panel()))
    }
}

struct SidePanelArea<Panel: View>: ViewModifier {
    let isShown: Bool
    let inspectorWidth: CGFloat?
    let panel: Panel
    /// Whether the panel fits beside the columns at the width the window proposes; false until measured
    /// (the safe side). A Bool, so a window resize changes it only when it crosses that width.
    @State private var fits = false

    func body(content: Content) -> some View {
        let beside = isShown && fits
        let inspectorWidth = self.inspectorWidth
        ProposalProbe {
            HStack(spacing: 0) {
                content.environment(\.suiteInspectorSwap, isShown && !beside ? InspectorSwap(content: AnyView(panel)) : nil)
                if beside {
                    GlassPanel { panel }
                        .frame(width: SuiteSize.editorPanelWidth)
                        .padding(SuiteSpacing.s)
                }
            }
            Color.clear.onGeometryChange(for: Bool.self) {
                SuiteSize.sidePanelFits(windowWidth: $0.size.width, inspectorWidth: inspectorWidth)
            } action: { fits = $0 }
        }
    }
}

/// Sizes and places its first subview as if alone, and gives its second the proposal itself at no size
/// of its own, so the second can read the width the window offers.
private struct ProposalProbe: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(proposal) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let first = subviews.first else { return }
        first.place(at: bounds.origin, proposal: proposal)
        if subviews.count > 1 {
            subviews[1].place(at: bounds.origin, proposal: ProposedViewSize(width: proposal.width ?? bounds.width, height: 0))
        }
    }
}
