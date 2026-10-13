// DesignPanel.swift: the right panel of Design's editor shell: the Properties
// and Layers tabs for the selection. Nothing to show until the inspector slice
// builds it; with nothing selected it says so.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignPanel: View {
    let model: DesignWorkspace
    var tab = DesignPanelTab.properties
    var onTab: @MainActor (DesignPanelTab) -> Void = { _ in }
    var perform: DesignPerform = { _ in }

    var body: some View {
        EmptyStateView("No Selection", systemImage: "square.dashed", message: "Select a layer to edit it.")
    }
}
