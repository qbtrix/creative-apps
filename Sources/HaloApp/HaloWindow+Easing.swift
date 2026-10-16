// HaloWindow+Easing.swift: the easing area's routes and hook (#428, EZ-6).
// Every easing command calls its HaloModel method (HaloKeySelection.swift),
// which refuses what it can't do under the control `halo.easing`: picking a
// key from an EASING row or a timeline diamond, clearing the pick, deleting
// the picked keys (⌫ from the viewer or timeline, refused under
// `halo.timeline`), a preset, a custom curve from the X1 Y1 X2 Y2 rows (coalesced per layer, as a handle
// drag is), a curve handle (index 0 the first, 1 the second), and the end of
// a drag, nudge or scrub, which ends the coalesced step. `easingScene(_:)` is
// a pass-through: the easing area shows no dialog.
import HaloModel
import SwiftUI

extension HaloWindow {
    func easingPerform(_ command: HaloCommand) {
        switch command {
        case .selectKey(let key, let extending): model.selectKey(key, extending: extending)
        case .selectLaneKeys(let layerID, let frame, let extending):
            model.selectLaneKeys(layerID: layerID, frame: frame, extending: extending)
        case .clearKeySelection: model.clearKeySelection()
        case .deleteKeys: model.deleteKeys()
        case .setEasing(let preset): model.setEasing(preset)
        case .setCustomEasing(let easing):
            model.setCustomEasing(easing, coalesceKey: model.pickedSegment.map { "\($0.key.layerID).easing" })
        case .moveEasingHandle(let index, let x, let y):
            model.moveEasingHandle(index == 0 ? .first : .second, to: HaloPoint(x: x, y: y))
        case .endEasingDrag: model.endCoalescing()
        default: break
        }
    }

    func easingScene(_ content: some View) -> some View { content }
}
