// FlareWindow+Router.swift: the one door every Flare control goes through.
// A toolbar action, sidebar row, menu item or stage gesture sends a
// FlareIntent to `perform`, and shows `help(for:)` as its reason while that
// is non-nil. Each switches on the intent's area and hands it to that area's
// file (FlareWindow+File.swift … FlareWindow+Assist.swift), so a later task
// fills its own area without touching this file or another area's.
import FlareModel

extension FlareWindow {
    /// Acts on `intent` through its area's `perform<Area>`.
    func perform(_ intent: FlareIntent) {
        switch intent {
        case .file(let intent): performFile(intent)
        case .edit(let intent): performEdit(intent)
        case .stage(let intent): performStage(intent)
        case .tools(let intent): performTools(intent)
        case .view(let intent): performView(intent)
        case .inspector(let intent): performInspector(intent)
        case .timeline(let intent): performTimeline(intent)
        case .layers(let intent): performLayers(intent)
        case .library(let intent): performLibrary(intent)
        case .interactions(let intent): performInteractions(intent)
        case .export(let intent): performExport(intent)
        case .assist(let intent): performAssist(intent)
        }
    }

    /// Why `intent` can't act now, from its area's `<area>Help`; nil when it can.
    func help(for intent: FlareIntent) -> String? {
        switch intent {
        case .file(let intent): fileHelp(intent)
        case .edit(let intent): editHelp(intent)
        case .stage(let intent): stageHelp(intent)
        case .tools(let intent): toolsHelp(intent)
        case .view(let intent): viewHelp(intent)
        case .inspector(let intent): inspectorHelp(intent)
        case .timeline(let intent): timelineHelp(intent)
        case .layers(let intent): layersHelp(intent)
        case .library(let intent): libraryHelp(intent)
        case .interactions(let intent): interactionsHelp(intent)
        case .export(let intent): exportHelp(intent)
        case .assist(let intent): assistHelp(intent)
        }
    }
}
