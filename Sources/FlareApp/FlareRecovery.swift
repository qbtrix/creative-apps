// FlareRecovery.swift: the offer to restore unsaved work after a crash;
// `restore` lands the recovered document (FlareWorkspace.restoreRecovery).
// A no-op modifier until layers-files LF-5 fills it.
import FlareCore
import FlareModel
import SwiftUI

struct FlareRecovery: ViewModifier {
    let model: FlareWorkspace
    let restore: @MainActor (FlareCore.Document) -> Void

    func body(content: Content) -> some View {
        content
    }
}
