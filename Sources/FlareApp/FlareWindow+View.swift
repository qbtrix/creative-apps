// FlareWindow+View.swift: the router's view area (stage-edit SE-2). Zoom steps Flare's table on the suite's zoom
// model (FlareWorkspace.zoomSteps) from the zoom, or from the fit (`fitted`) while the stage fits. Guide edits go to the Model; onion skin and the motion path stay off until drawn.
import FlareModel

extension FlareWindow {
    func performView(_ intent: FlareIntent.View) {
        guard viewHelp(intent) == nil else { return }
        switch intent {
        case .zoomIn: zoom = FlareWorkspace.zoomSteps.zoomedIn(from: zoom ?? fitted)
        case .zoomOut: zoom = FlareWorkspace.zoomSteps.zoomedOut(from: zoom ?? fitted)
        case .fit: zoom = nil
        case .actualSize: zoom = 1
        case .toggleRulers: showsRulers.toggle()
        case .toggleGuides: showsGuides.toggle()
        case .clearGuides: model.clearGuides()
        case .addGuide(let horizontal, let at): model.addGuide(horizontal ? .horizontal : .vertical, at: at)
        case .moveGuide(let index, let to, let start): model.moveGuide(at: index, to: to, dragStart: start)
        case .endGuideDrag: model.endGuideDrag()
        case .removeGuide(let index): model.removeGuide(at: index)
        case .toggleOnion, .toggleMotionPath: break
        }
    }

    /// Why a view intent can't act now; nil when it can.
    func viewHelp(_ intent: FlareIntent.View) -> String? {
        guard model.selectedScene != nil else { return FlareLayerError.noDocument.message }
        switch intent {
        case .zoomIn where (zoom ?? fitted) >= FlareWorkspace.zoomSteps.range.upperBound: return "Already at the largest zoom."
        case .zoomOut where (zoom ?? fitted) <= FlareWorkspace.zoomSteps.range.lowerBound: return "Already at the smallest zoom."
        case .clearGuides: return model.clearGuidesHelp
        // Hidden from the View menu (FlareWorkspace.menuHidden); any other caller reads the same reason.
        case .toggleOnion, .toggleMotionPath: return FlareIntent.view(intent).commandID.map(FlareWorkspace.laterReason)
        default: return nil
        }
    }
}
