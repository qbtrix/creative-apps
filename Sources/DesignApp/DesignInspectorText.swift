// DesignInspectorText.swift: the Text section of Design's inspector, shown
// after Fill when a text layer is selected. It draws nothing for now, so a
// text layer shows no bare "TEXT" header: style-rows (SR-t) fills it with an
// InspectorSection holding the font, size, weight and alignment rows, so that
// work touches only this file. Values in, intents out.
import SwiftUI

/// A text layer's Text section; empty until style-rows gives it rows.
struct DesignInspectorText: View {
    var body: some View {
        EmptyView()
    }
}
