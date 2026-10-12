// DeleteLayerCommand.swift: Photo's Delete Layer toolbar item. It is always
// shown and disabled while it can't run (one layer left, or no selection),
// so the toolbar doesn't shift and the command stays discoverable.
import SwiftUI

struct DeleteLayerCommand: View {
    let isEnabled: Bool
    var perform: @MainActor () -> Void = {}

    var body: some View {
        Button(action: perform) {
            Label("Delete Layer", systemImage: "trash")
        }
        .help("Delete Layer")
        .disabled(!isEnabled)
    }
}
