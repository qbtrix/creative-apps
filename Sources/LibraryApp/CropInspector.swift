// CropInspector.swift: the CROP section the Develop tab shows while a crop
// draft is open (crop CR-6). SuiteUI's CropAspectPicker (orientation-crop
// OC-9): the aspect chips (`suite.crop.aspect-<title>`, "suite.crop.aspect-1-1"),
// Custom W:H, and the landscape/portrait toggle (`suite.crop.orientation`, X),
// standing as the draft's frame stands; each pick goes to `crop.pick`;
// Straighten, a scrub row from -45° to 45° with one decimal that takes a
// typed angle (`library.crop.straighten`); Auto (`library.crop.auto`), off
// with `levelHelp` until a leveler is connected; Apply, the primary action
// (`library.crop.apply`, also Return), and Cancel (`library.crop.cancel`,
// also Escape on the canvas); and Reset Crop (`library.crop.reset`), back to
// the whole photo at 0°. Values in, closures out: every change goes through
// `LibraryMenu.Crop`'s closures; it never writes LibraryCatalog.
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct CropInspector: View {
    let crop: LibraryMenu.Crop

    var body: some View {
        let auto = action("Auto", "auto", systemImage: "level", crop.level, help: crop.levelHelp)
        let cancel = action("Cancel", "cancel", systemImage: "xmark", crop.cancel)
        let reset = action("Reset Crop", "reset", systemImage: "arrow.counterclockwise", crop.reset, help: crop.resetHelp)
        InspectorSection("Crop") {
            CropAspectPicker(
                aspect: crop.draft?.aspect ?? .original, orientation: Self.orientation(of: crop.frame),
                onPick: { crop.pick?($0) })
                .disabled(crop.pick == nil)
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

    /// The way the draft's frame stands: taller than wide is portrait.
    nonisolated static func orientation(of frame: PixelRect?) -> CropOrientation {
        guard let frame, frame.height > frame.width else { return .landscape }
        return .portrait
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
