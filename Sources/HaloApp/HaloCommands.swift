// HaloCommands.swift: Halo's Layer menu in the menu bar. Layer > New adds a
// Solid, Shape, Text or Null layer to the focused window's selected
// composition. The window publishes the action as a focused scene value, nil
// when no composition is selected, so the items disable rather than hide.
import HaloModel
import SwiftUI

extension FocusedValues {
    /// Adds a layer of a kind to the focused window's project; nil when it
    /// has no composition selected.
    @Entry var haloNewLayer: (@MainActor (HaloLayerKind) -> Void)?
}

struct HaloCommands: Commands {
    @FocusedValue(\.haloNewLayer) private var newLayer

    var body: some Commands {
        CommandMenu("Layer") {
            Menu("New") {
                ForEach(HaloLayerKind.allCases, id: \.self) { kind in
                    Button(kind.title, systemImage: kind.systemImage) { newLayer?(kind) }
                        .disabled(newLayer == nil)
                }
            }
        }
    }
}

extension HaloLayerKind {
    /// The SF Symbol for the kind in lists and menus.
    var systemImage: String {
        switch self {
        case .solid: "square.fill"
        case .shape: "star"
        case .text: "textformat"
        case .null: "square.dashed"
        }
    }
}
