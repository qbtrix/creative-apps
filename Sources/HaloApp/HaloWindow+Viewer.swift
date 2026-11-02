// HaloWindow+Viewer.swift: the composition area's routes and the viewer's
// hook. The composition commands are shipped: New Composition… opens the
// sheet; Duplicate, Delete, select and rename call the Model, which refuses
// what it can't do. Composition > Delete while a text field has focus (renaming in
// the sidebar) edits the text instead (HaloProject.compositionDeleteCommand).
// HaloViewerCanvas reads the draw list and the selection from the Model itself
// (#37). `viewerScene(_:)` hands the viewer the window's shape tool and points
// its draw at the Model's `drawShape` (shape-tools HS-3): one call per release.
// It also hands the handles `haloCommitTransform`: a handle drag's release
// reaches `setTransform` as one step (transform HT-3). It supplies
// `haloPlace` (placed-images PH-3) as `runPlace`, to the window's views and as
// the focused value File > Place… reads, and `haloFilter` (adjust-everywhere AJ-13) as `runFilter`, the same way
// for FILTERS and Layer > Add Filter.
import HaloModel
import SuiteKernel
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
            .environment(\.haloCommitTransform, commitTransform)
            // The viewer's drops and the inspector read it; File > Place… reads the focused value.
            .environment(\.haloPlace, { runPlace($0, fill: $1) })
            .focusedSceneValue(\.haloPlace, { runPlace($0, fill: $1) })
            // FILTERS reads it; Layer > Add Filter reads the focused value.
            .environment(\.haloFilter, { runFilter($0) })
            .focusedSceneValue(\.haloFilter, { runFilter($0) })
            .onAppear {
                shapes.draw = {
                    takePlayback()
                    _ = model.drawShape($0)
                }
            }
    }

    /// The window's `haloPlace` (HaloPlace.swift): a place intent through the Model's catalog, Fill riding on a
    /// `.place`; the Model refuses what it can't do.
    func runPlace(_ intent: PlaceIntent, fill: Bool) {
        takePlayback()
        model.runPlace(intent, fill: fill)
    }

    /// The window's `haloFilter` (HaloFilterSection.swift): one FILTERS gesture on the selected layer.
    func runFilter(_ intent: HaloFilterIntent) {
        takePlayback()
        model.runFilter(intent)
    }

    /// A handle drag's release, as one step; the Model refuses what it can't do.
    func commitTransform(_ t: TransformBox, name: String) {
        takePlayback()
        try? model.setTransform(t, name: name, drag: nil)
    }
}
