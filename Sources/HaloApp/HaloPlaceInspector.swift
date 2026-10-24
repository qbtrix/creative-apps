// HaloPlaceInspector.swift (placed-images PH-3): the IMAGE slot of Halo's layer inspector, under FILL, shown only
// while a solid is selected (`shows`). A solid with a picture shows SuiteUI's PlacedImageRows (its file line
// "logo.svg · SVG · 480 × 160", Replace… and Reset Size), each sending one PlaceIntent to the window's `haloPlace`
// action. Under it the Place row's checkbox, "Into the selected solid" (`halo.inspector.place.fill`), keeps the
// preference the next File > Place… and drop read: a placed file fills the selected solid. While `help` says why placing can't run, the rows and the checkbox
// are off with that reason as their tooltip and as a note (`halo.inspector.placeHelp`). Its inputs are values, so
// a snapshot can show any picture; `init(model:)` reads them from the project. Values in, intents out.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct HaloPlaceInspector: View {
    /// The selected solid's picture; nil shows only the checkbox.
    let asset: PlacedAsset?
    let formats: Set<PlacedFormat>
    /// The Model's reason placing can't run (`placeHelp`); nil while it can.
    let modelHelp: String?
    @Environment(\.haloPlace) private var place
    @AppStorage(HaloPlace.fillKey) private var fill = false

    nonisolated static let fillID = "halo.inspector.place.fill"
    nonisolated static let helpID = "halo.inspector.placeHelp"
    /// The Fill checkbox's title, under the row's "Place" label: a preference for the next place, not a command.
    nonisolated static let fillTitle = "Into the selected solid"

    /// Whether IMAGE shows for a layer of `kind`: solids only.
    nonisolated static func shows(_ kind: HaloLayerKind?) -> Bool { kind == .solid }

    /// Why placing can't run here: the Model's reason, or no wired action; nil while it can.
    var help: String? { modelHelp ?? (place == nil ? HaloPlace.notWired : nil) }

    var body: some View {
        InspectorSection("Image") {
            if let asset {
                PlacedImageRows(asset: asset, formats: formats) { place?($0, false) }
                    .disabled(help != nil)
                    .help(help ?? "The placed file")
            }
            InspectorRow("Place") {
                Toggle(Self.fillTitle, isOn: $fill)
                    .toggleStyle(.checkbox)
            }
            .disabled(help != nil)
            .help(help ?? "The next Place… or drop fills the selected solid instead of adding a layer")
            .haloControl(id: Self.fillID, enabled: help == nil, help: help)
            if let help { InspectorNote(help, kind: .secondary, identifier: Self.helpID) }
        }
    }
}

extension HaloPlaceInspector {
    /// IMAGE for the project's selected layer.
    init(model: HaloProject) {
        self.init(asset: model.placedSelection?.asset, formats: model.placeFormats, modelHelp: model.placeHelp)
    }
}
