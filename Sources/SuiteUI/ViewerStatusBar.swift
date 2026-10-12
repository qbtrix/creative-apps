// ViewerStatusBar.swift: the status line under a canvas or viewer: the zoom
// percent, the document size, then a trailing slot for a View menu, a
// timecode or a selection count. A flat panel band with a hairline on top,
// SuiteSize.inspectorRow tall, 10 pt monospaced digits and small controls.
// Chrome, not content, but flat: glass stays on the window frame and the
// floating palettes (docs/design.md, Pro density). The zoom text comes from
// ViewerZoom, so every app formats it the same way.
import SwiftUI

public struct ViewerStatusBar<Trailing: View>: View {
    private let zoom: Double
    private let size: String
    private let trailing: Trailing

    /// `zoom` is the scale the viewer draws at (1 is 100%; ViewerZoom.fitScale
    /// gives CanvasSurface's), `size` the document size ("1920 × 1080 px").
    public init(zoom: Double, size: String, @ViewBuilder trailing: () -> Trailing) {
        self.zoom = zoom
        self.size = size
        self.trailing = trailing()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: SuiteSpacing.m) {
                Text(ViewerZoom.percentText(zoom))
                    .foregroundStyle(Color.primary)
                    .accessibilityLabel("Zoom \(ViewerZoom.percentText(zoom))")
                Text(size)
                Spacer(minLength: SuiteSpacing.s)
                trailing
            }
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.secondaryText)
            .lineLimit(1)
            .controlSize(SuiteSize.compactControl)
            .padding(.horizontal, SuiteSpacing.s)
            .frame(height: SuiteSize.inspectorRow)
            .background(SuiteColor.panel)
        }
    }
}

extension ViewerStatusBar where Trailing == EmptyView {
    public init(zoom: Double, size: String) {
        self.init(zoom: zoom, size: size) { EmptyView() }
    }
}
