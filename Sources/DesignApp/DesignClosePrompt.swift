// DesignClosePrompt.swift: the close prompt's place on a Design window's root,
// a view modifier that lets every close through until files-history fills it
// with the unsaved-changes question. The slot exists so the feature that fills
// it edits only this file.
import DesignModel
import SwiftUI

struct DesignClosePrompt: ViewModifier {
    let model: DesignWorkspace

    func body(content: Content) -> some View {
        content
    }
}
