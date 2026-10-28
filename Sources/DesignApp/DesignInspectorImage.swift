// DesignInspectorImage.swift (placed-images PD-u, PD-4): the inspector's Picture section on a frame or rectangle.
// A layer showing a picture gets SuiteUI's PlacedImageRows (the file, Replace…, Reset Size), each sent as `.place`;
// then Place in Frame… (`.placeFile(fill: true)`: the picture fills this layer; built from the catalog's place.image
// spec, whose help is `placeActionHelp`) and the "Place into selected frame" checkbox, kept in user defaults
// (DesignPlace.fillKey), which makes File > Place… and a drop fill the selected frame. The rows go grey together on
// Replace…'s reason until SuiteUI takes one reason per row (#4985); the note names every reason (`placeNote`).
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
        InspectorSection("Picture") {
            if let asset = node.placedAsset {
                PlacedImageRows(asset: asset, formats: model.placeFormats) { perform(.place($0, fill: false)) }
                    .disabled(model.placeActionHelp("place.replace") != nil)
            }
            InspectorRow("") {
                MenuCommand(DesignMenuState.spec("place.image"), on: DesignMenuState(workspace: model, hasWindow: true),
                            title: "Place in Frame…", systemImage: "photo.badge.plus") { perform(.placeFile(fill: true)) }
                    .suiteControl(id: "design.inspector.place", enabled: help == nil, reason: help)
            }
            InspectorRow("") {
                Toggle("Place into selected frame", isOn: $fill)
                    .toggleStyle(.checkbox)
                    .help("On: File > Place… and a drop fill the selected frame, cropped to cover it. Off: they add the picture as a new layer on the page.")
                    .suiteControl(id: "design.inspector.place-fill", enabled: true, reason: nil)
            }
            if let note = model.placeNote { InspectorNote(note, identifier: "design.inspector.place-help") }
        }
    }
}
