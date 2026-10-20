// HaloWindow+Viewer.swift: the composition area's routes and the viewer's
// hook. The composition commands are shipped: New Composition… opens the
// sheet; Duplicate, Delete, select and rename call the Model, which refuses
// what it can't do. Composition > Delete while a text field has focus (renaming in
// the sidebar) edits the text instead (HaloProject.compositionDeleteCommand).
// HaloViewerCanvas reads the draw list and the selection from the Model itself
// (#37). `viewerScene(_:)` hands the viewer the window's shape tool and points
// its draw at the Model's `drawShape` (shape-tools HS-3): one call per release.
import HaloModel
import SwiftUI

extension HaloWindow {
    func viewerPerform(_ command: HaloCommand) {
        switch command {
        case .newComposition: showsNewComposition = true
        case .duplicateComposition:
            if let id = model.selectedCompositionID { _ = model.duplicateComposition(id) }
        case .deleteComposition:
            switch model.compositionDeleteCommand(editingText: HaloTextFocus.isEditing) {
            case .editText: HaloTextFocus.deleteToStartOfLine()
            case .delete(let id): _ = model.deleteComposition(id)
            case .unavailable: break
            }
        case .selectComposition(let id): model.selectComposition(id)
        case .renameComposition(let id, let name): _ = model.renameComposition(id, to: name)
        default: break
        }
    }

    func viewerScene(_ content: some View) -> some View {
        content
            .environment(\.haloShapeDrawing, shapes)
            .onAppear { shapes.draw = { _ = model.drawShape($0) } }
    }
}
