// FlareNewSheet.swift: the New Animation sheet (presets, size, fps,
// duration). A no-op modifier until layers-files LF-3 fills it. It also
// holds FlarePresentation, what the window presents over itself.
import FlareModel
import SwiftUI

/// What the window presents over itself; filled by the tasks that present it.
enum FlarePresentation: Hashable, Identifiable {
    case newAnimation

    var id: Self { self }
}

struct FlareNewSheet: ViewModifier {
    @Binding var presented: FlarePresentation?
    let perform: @MainActor (FlareIntent) -> Void

    func body(content: Content) -> some View {
        content
    }
}
