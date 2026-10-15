// HaloLayerInspector.swift: the selected layer in Halo's inspector: its
// header (`selectedLayerHeader`), a placeholder for TRANSFORM, a refusal's
// caption, then the EASING and TEXT slots. layer-keys (#38) replaces it.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloLayerInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        if let header = model.selectedLayerHeader {
            VStack(alignment: .leading, spacing: 0) {
                InspectorHeader(header.name, details: [header.kind, header.frames, header.parent.map { "Parent: \($0)" } ?? ""])
                Text("Properties arrive with the layer inspector (#38).")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.textSecondary)
                    .padding(.horizontal, SuiteSpacing.m)
                    .padding(.vertical, SuiteSpacing.s)
                if let refusal = model.refusal, refusal.control.hasPrefix("halo.inspector") {
                    HaloRefusalCaption(refusal: refusal)
                }
                HaloEasingInspector(model: model, perform: perform)
                HaloTextInspector(model: model, perform: perform)
            }
        }
    }
}
