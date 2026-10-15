// HaloWindow+Keys.swift: the keys area's routes and hook. Every keys command
// calls its HaloModel method (HaloKeying.swift, HaloViewerDrag.swift and
// HaloProject's blend mutator), which refuses what it can't do and names the
// refusal's control: a TRANSFORM row's value (scrubbed, or typed), the end
// of its scrub, the stopwatch and key diamond, Parent, Blend, and the
// viewer drag (in composition pixels). `keysScene(_:)` is a pass-through:
// the keys area shows no dialog.
import HaloModel
import SwiftUI

extension HaloWindow {
    func keysPerform(_ command: HaloCommand) {
        switch command {
        case .setProperty(let p, let value): model.setProperty(p, to: value)
        case .setPropertyText(let p, let text): model.setProperty(p, text: text)
        case .endPropertyScrub: model.endPropertyScrub()
        case .toggleAnimation(let p): model.toggleAnimation(p)
        case .toggleKey(let p): model.toggleKey(p)
        case .setParent(let id): model.setParent(id)
        case .setBlendMode(let mode): model.setSelectedLayerBlendMode(mode)
        case .beginViewerDrag(let x, let y): model.beginViewerDrag(at: HaloPoint(x: x, y: y))
        case .moveViewerDrag(let x, let y): model.moveViewerDrag(to: HaloPoint(x: x, y: y))
        case .endViewerDrag: model.endViewerDrag()
        case .cancelViewerDrag: model.cancelViewerDrag()
        default: break
        }
    }

    func keysScene(_ content: some View) -> some View { content }
}
