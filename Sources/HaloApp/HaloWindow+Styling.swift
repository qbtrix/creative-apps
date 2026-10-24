// HaloWindow+Styling.swift (layer-styles HY-2): the styling area's hook. The window publishes `runStyleMenu` as
// the `haloRunStyleMenu` focused value, which the Layer menu's HaloStyleMenuItems call: it runs the id on the
// project and puts what Copy returns on LayerStylePasteboard, which Paste reads. `stylingScene(_:)` presents
// HaloStyleSheet (HaloStyleAdapter.swift) while `stylePanel` is set, each gesture sent to `runStyle`.
import HaloModel
import SuiteImaging
import SuiteUI
import SwiftUI

extension FocusedValues {
    /// Runs one Layer menu style id on the focused Halo window; nil with no Halo window.
    @Entry var haloRunStyleMenu: (@MainActor (String) -> Void)?
}

extension HaloWindow {
    func stylingScene(_ content: some View) -> some View {
        content
            .modifier(HaloStyleSheetHost(model: model, onIntent: { intent in
                takePlayback()
                model.runStyle(intent)
            }))
            .focusedSceneValue(\.haloRunStyleMenu, runStyleMenu)
    }

    /// Runs `id`'s Layer menu item; Copy's style goes on the pasteboard.
    func runStyleMenu(_ id: String) {
        takePlayback()
        let copied = model.runStyleMenu(id, pasted: LayerStylePasteboard.read())
        if id == "style.copy", let copied { LayerStylePasteboard.write(copied) }
    }
}
