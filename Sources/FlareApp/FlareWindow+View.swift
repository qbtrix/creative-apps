// FlareWindow+View.swift: the router's view area (stage-edit SE-2). Zoom steps from the zoom, or from the fit
// (`fitted`) while the stage fits. Guide edits go to the Model; onion skin and the motion path stay off until drawn.
import FlareModel

extension FlareWindow {
    func performView(_ intent: FlareIntent.View) {
        guard viewHelp(intent) == nil else { return }
        switch intent {
        case .zoomIn: zoom = FlareZoom.zoomIn(zoom ?? fitted)
        case .zoomOut: zoom = FlareZoom.zoomOut(zoom ?? fitted)
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
        case .zoomIn where (zoom ?? fitted) >= FlareZoom.range.upperBound: return "Already at the largest zoom."
        case .zoomOut where (zoom ?? fitted) <= FlareZoom.range.lowerBound: return "Already at the smallest zoom."
        case .clearGuides: return model.clearGuidesHelp
        case .toggleOnion: return "The stage doesn't draw onion skins yet."
        case .toggleMotionPath: return "The stage doesn't draw the motion path yet."
        default: return nil
        }
    }
}
