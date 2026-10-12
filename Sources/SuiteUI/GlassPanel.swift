// GlassPanel.swift: a floating Liquid Glass panel for controls that sit over
// content (transport bars, HUD readouts). Glass is for the control layer only:
// never put a GlassPanel around document content or inside another glass view.
import SwiftUI

public struct GlassPanel<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(.horizontal, SuiteSpacing.l)
            .padding(.vertical, SuiteSpacing.s)
            .glassEffect(.regular, in: .rect(cornerRadius: SuiteRadius.large))
    }
}
