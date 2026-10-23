// DesignInspectorImage.swift (placed-images PD-u, PD-4): the inspector's Image section on a frame or rectangle.
// A layer showing a picture gets SuiteUI's PlacedImageRows (the file, Replace…, Reset Size), each sent as `.place`;
// then Place… (`.placeFile`, the File menu's command) and Fill, a checkbox kept in user defaults
// (DesignPlace.fillKey) that makes Place… and a drop fill the selected frame. Each control is disabled with the
// Model's reason while its command can't run (`placeActionHelp`), and that reason shows below them.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignInspectorImage: View {
    let model: DesignWorkspace
    let node: DesignNode
    let perform: DesignPerform
    @AppStorage(DesignPlace.fillKey) private var fill = false

    var body: some View {
        let help = model.placeActionHelp()
        InspectorSection("Image") {
            if let asset = node.placedAsset {
                let rowsHelp = model.placeActionHelp("place.replace")
                PlacedImageRows(asset: asset, formats: model.placeFormats) { perform(.place($0, fill: false)) }
                    .disabled(rowsHelp != nil)
            }
            InspectorRow("") {
                Button("Place…") { perform(.placeFile) }
                    .disabled(help != nil)
                    .help(help ?? "Choose a picture to place on the page.")
                    .suiteControl(id: "design.inspector.place", enabled: help == nil, reason: help)
            }
            InspectorRow("") {
                Toggle("Fill", isOn: $fill)
                    .toggleStyle(.checkbox)
                    .help("Place a picture into the selected frame instead of beside it.")
                    .suiteControl(id: "design.inspector.place-fill", enabled: true, reason: nil)
            }
            if let help { InspectorNote(help, identifier: "design.inspector.place-help") }
        }
    }
}
