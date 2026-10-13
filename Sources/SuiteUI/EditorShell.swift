// EditorShell.swift: the window layout of a canvas editor, after the Ripple
// editor shell (docs/design.md, Editor shell). From the top: an EditorTopBar,
// then the docked tool rail, the canvas (a CanvasViewport) and the right panel
// side by side, then the status line (a ViewerStatusBar). Flat graphite
// panels with hairlines between regions, no glass: the shell is dark in both
// appearances, on purpose, like the Studio editor it follows, so the image is
// the brightest thing on screen. It fills the whole window, title bar
// included: the scene uses `.windowStyle(.hiddenTitleBar)` and the top bar
// leaves room for the window's buttons and drags the window. The right panel
// carries the accessibility identifier `suite.inspector`, the rail
// `suite.tools` (ToolbarGroup) and the canvas `suite.canvas` (CanvasViewport),
// which the UI journeys find. Owns no state.
import SwiftUI

public struct EditorShell<TopBar: View, Rail: View, Canvas: View, Panel: View, Status: View>: View {
    private let topBar: TopBar
    private let rail: Rail
    private let canvas: Canvas
    private let panel: Panel
    private let status: Status

    public init(
        @ViewBuilder topBar: () -> TopBar, @ViewBuilder rail: () -> Rail, @ViewBuilder canvas: () -> Canvas,
        @ViewBuilder panel: () -> Panel, @ViewBuilder status: () -> Status
    ) {
        self.topBar = topBar()
        self.rail = rail()
        self.canvas = canvas()
        self.panel = panel()
        self.status = status()
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            HStack(spacing: 0) {
                rail
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(SuiteColor.panel)
                Divider()
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minWidth: SuiteSize.contentMinimum.width, minHeight: SuiteSize.contentMinimum.height)
                    .background(SuiteColor.canvasSurround)
                Divider()
                panel
                    .frame(width: SuiteSize.editorPanelWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(SuiteColor.panel)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("suite.inspector")
            }
            status
        }
        .background(SuiteColor.panel)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: SuiteSize.windowMinimum.width, minHeight: SuiteSize.windowMinimum.height)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .tint(SuiteColor.accent)
    }
}
