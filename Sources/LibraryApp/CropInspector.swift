// CropInspector.swift: the CROP section the Develop tab shows while a crop
// draft is open (crop CR-6). The aspect chips (`library.crop.aspect.<title>`,
// "library.crop.aspect.1:1"), three to a row so all six share one width;
// Straighten, a scrub row from -45° to 45° with one decimal that takes a
// typed angle (`library.crop.straighten`); Auto (`library.crop.auto`), off
// with `levelHelp` until a leveler is connected; Apply, the primary action
// (`library.crop.apply`, also Return), and Cancel (`library.crop.cancel`,
// also Escape on the canvas); and Reset Crop (`library.crop.reset`), back to
// the whole photo at 0°. Values in, closures out: every change goes through
// `LibraryMenu.Crop`'s closures; it never writes LibraryCatalog.
import LibraryModel
import SuiteUI
import SwiftUI

struct CropInspector: View {
    let crop: LibraryMenu.Crop

    var body: some View {
        let auto = action("Auto", "auto", systemImage: "level", crop.level, help: crop.levelHelp)
        let cancel = action("Cancel", "cancel", systemImage: "xmark", crop.cancel)
        let reset = action("Reset Crop", "reset", systemImage: "arrow.counterclockwise", crop.reset, help: crop.resetHelp)
        InspectorSection("Crop") {
            ChoiceChips(options: Self.aspects, selected: crop.draft?.aspect, onSelect: { crop.setAspect?($0) })
            InspectorSliderRow(
                "Straighten", value: crop.draft?.angle ?? 0, in: CropSettings.angleRange, unit: "°", decimals: 1,
                onChange: { crop.setAngle?($0) })
                .libraryControl(id: "library.crop.straighten", enabled: crop.setAngle != nil, help: Self.noDraft)
            InspectorAction(auto).libraryControl(auto)
            HStack(spacing: SuiteSpacing.xs) {
                InspectorAction(cancel).libraryControl(cancel)
                Button { crop.apply?() } label: { Text("Apply").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .tint(SuiteColor.accentFill)
                    .disabled(crop.apply == nil)
                    .help(crop.apply == nil ? Self.noDraft : "Apply the crop (Return)")
                    .libraryControl(id: "library.crop.apply", enabled: crop.apply != nil, help: Self.noDraft)
            }
            InspectorAction(reset).libraryControl(reset)
        }
    }

    /// The six aspects, each chip identified by its title.
    nonisolated static let aspects = CropAspect.allCases.map {
        InspectorOption(id: $0, title: $0.rawValue, identifier: "library.crop.aspect.\($0.rawValue)")
    }

    nonisolated static let noDraft = "Press R in the loupe to crop."

    /// A crop action as a ToolbarAction (`library.crop.<name>`): off, saying why, while `perform` is nil.
    private func action(
        _ title: String, _ name: String, systemImage: String, _ perform: LibraryMenu.Action?, help: String? = nil
    ) -> ToolbarAction {
        ToolbarAction(
            title, systemImage: systemImage, unavailableHelp: perform == nil ? help ?? Self.noDraft : nil,
            identifier: "library.crop.\(name)", perform: perform ?? {})
    }
}
