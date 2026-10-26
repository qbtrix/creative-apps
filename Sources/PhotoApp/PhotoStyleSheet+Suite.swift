// PhotoStyleSheet+Suite.swift: the layer style sheet (layer styles PY-2), an
// adapter onto SuiteUI's LayerStylePanel: the panel on the selected layer's
// style at the open kind, its intents sent as `.style(.panel(_))`, and Done
// (Return) or Escape closing it with `.show(nil)`. Done is Layer Style…'s
// spec, which stays on while the panel is open. PhotoStyleArea
// (PhotoWindow+Styling) presents it. Values in, intents out.
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI

struct PhotoStyleSheet: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            Text("Layer Style").font(SuiteFont.headline)
            LayerStylePanel(
                style: model.styleSelection, selected: model.stylePanel ?? .dropShadow, help: model.styleHelp,
                onIntent: { perform(.style(.panel($0))) })
            HStack {
                Spacer()
                MenuCommand(PhotoMenuState.spec("style.panel"), on: PhotoMenuState(workspace: model, hasWindow: true),
                            title: "Done", shortcut: .defaultAction) { close() }
                    .accessibilityIdentifier("photo.style.done")
            }
        }
        .padding(SuiteSpacing.l)
        .onExitCommand { close() }
    }

    private func close() { perform(.style(.panel(.show(nil)))) }
}
