// DesignInspectorText.swift: the Text section of Design's inspector, shown
// after Fill when a text layer is selected. An empty slot for now: style-rows
// (SR-t) fills it with the font, size, weight and alignment rows, so that work
// touches only this file. Values in, intents out.
import SuiteUI
import SwiftUI

/// A text layer's Text section; its rows come with style-rows.
struct DesignInspectorText: View {
    var body: some View {
        InspectorSection("Text") { EmptyView() }
    }
}
