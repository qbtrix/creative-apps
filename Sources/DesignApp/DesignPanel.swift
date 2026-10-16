// DesignPanel.swift: DesignPanelHint, the one-line secondary help text under
// the rows of Design's sidebar (DesignLayersPanel) and inspector
// (DesignInspector).
import SuiteUI
import SwiftUI

/// A short line of secondary help text under a panel's rows.
struct DesignPanelHint: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SuiteSpacing.s)
            .padding(.vertical, SuiteSpacing.xs)
    }
}
