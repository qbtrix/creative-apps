// FlareNewSheet.swift: the New Animation sheet (presets, size, fps,
// duration). A no-op modifier until layers-files LF-3 fills it.
import FlareModel
import SwiftUI

struct FlareNewSheet: ViewModifier {
    @Binding var presented: FlarePresentation?
    let perform: @MainActor (FlareIntent) -> Void

    func body(content: Content) -> some View {
        content
    }
}
