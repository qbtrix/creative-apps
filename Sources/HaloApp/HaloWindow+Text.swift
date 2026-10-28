// HaloWindow+Text.swift: the text area's routes and hook (#430, TX-6). Each
// text command calls its HaloModel method: the TEXT field's words
// (`setText`, HaloTextEdits.swift, refused under `halo.inspector.text.string`
// when blank), the size bar's samples (`setFontSize`, coalesced until
// `endTextSizeScrub`), and the layer color (`setLayerColor`,
// HaloTextEdits+Color.swift). `textScene(_:)` hands the window's views the
// `haloText` action (HaloTextInspector.swift, text-style TS-10): a text style
// rows gesture through `HaloProject.runText`; the text area shows no dialog.
import HaloModel
import SuiteKernel
import SwiftUI

extension HaloWindow {
    func textPerform(_ command: HaloCommand) {
        switch command {
        case .setText(let string): model.setText(string)
        case .setFontSize(let size): model.setFontSize(size)
        case .endTextSizeScrub: model.endTextSizeScrub()
        case .setLayerColor(let color): model.setLayerColor(color)
        default: break
        }
    }

    func textScene(_ content: some View) -> some View {
        content.environment(\.haloText, { intent in
            takePlayback()
            model.runText(intent)
        })
    }
}
