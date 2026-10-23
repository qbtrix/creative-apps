// DesignPlace.swift (placed-images PD-u, PD-4): the window's half of placing pictures. `fillKey` is where the
// Picture section's "Place into selected frame" checkbox keeps its choice for every Design window; `designPlaceDrop` takes files dropped
// on the artwork through SuiteUI's placeDropTarget (its accent ring while a drag offers something). The Model
// turns the drop's point into page points and says whether it fills the selected frame under it; each file then
// goes to the window as `.place`: the first into that frame, the rest at the drop point (`placeSteps`).
// A file the drop refuses can't say why until SuiteUI hands the reason back (#4985).
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

enum DesignPlace {
    /// The user default holding whether Place… and a drop fill the selected frame.
    static let fillKey = "design.place.fill"
}

/// A drop of pictures on the artwork at `zoom`.
private struct DesignPlaceDrop: ViewModifier {
    let model: DesignWorkspace
    let zoom: Double
    let perform: DesignPerform
    @AppStorage(DesignPlace.fillKey) private var fill = false

    func body(content: Content) -> some View {
        content.contentShape(.rect).placeDropTarget(formats: model.placeFormats) { files, point in
            guard let at = DesignWorkspace.dropPoint(x: point.x, y: point.y, zoom: zoom) else { return false }
            let steps = DesignWorkspace.placeSteps(files, fills: model.dropFills(at: at, fill: fill), at: Point(x: at.x, y: at.y))
            for step in steps { perform(.place(step.intent, fill: step.fill)) }
            return !files.isEmpty
        }
    }
}

extension View {
    /// Pictures dropped here are placed on `model`'s page, the view drawn at `zoom`.
    func designPlaceDrop(_ model: DesignWorkspace, zoom: Double, perform: @escaping DesignPerform) -> some View {
        modifier(DesignPlaceDrop(model: model, zoom: zoom, perform: perform))
    }
}
