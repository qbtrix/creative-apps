// DesignPanel.swift: the right panel of Design's editor shell: Properties and
// Layers tabs on SegmentedTabs, then the tab's content (DesignInspector or
// DesignLayersPanel). With no file open it says how to start. Values in,
// intents out; which tab shows is presentation state that DesignWindow keeps.
// Also DesignPanelHint, the one-line secondary help text both tabs use.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignPanel: View {
    let model: DesignWorkspace
    var tab = DesignPanelTab.properties
    var onTab: @MainActor (DesignPanelTab) -> Void = { _ in }
    var perform: DesignPerform = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs(
                "Panel",
                tabs: [InspectorOption(id: .properties, title: "Properties"), InspectorOption(id: .layers, title: "Layers")],
                selection: tab, onChange: onTab)
            if !model.isOpen {
                EmptyStateView("No Selection", systemImage: "square.dashed", message: "Create a file to start designing.")
            } else if tab == .properties {
                DesignInspector(model: model, perform: perform)
            } else {
                DesignLayersPanel(model: model, perform: perform)
            }
        }
    }
}

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
