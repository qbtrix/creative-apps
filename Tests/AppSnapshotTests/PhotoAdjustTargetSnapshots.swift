// PhotoAdjustTargetSnapshots.swift: Photo's Adjust tab editing its target
// (AL-7 of photo-adjustment-layers, PV-6): on the `layered` fixture with
// "Curves 1" selected, the header reads "Curves 1" over "Adjusts the layers
// below" and the tab shows only that layer's Curves section, with no enable
// switch (the row's eye turns the layer off), under the Layer section with
// its Blend Mode and Opacity, as the inspector shows it (#1713). With Background selected the
// target is the whole image, under "Image", with all five sections. Writes
// photo-adjust-target-light.png and photo-adjust-target-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoAdjustTargetSnapshots {
    /// The `layered` fixture with the layer named `name` selected.
    private func layered(selecting name: String) throws -> PhotoWorkspace {
        var model = try PhotoWorkspace.fixture(.layered)
        let layer = try #require(model.layers.first { $0.name == name })
        model.selectLayer(layer.id)
        return model
    }

    @Test func curvesLayerTarget() throws {
        let model = try layered(selecting: "Curves 1")
        guard case .layer(let id, let settings) = model.adjustTarget else {
            Issue.record("Curves 1 is not the Adjust tab's target")
            return
        }
        #expect(id == model.selectedLayerID)
        #expect(settings.curvePoints.count == 4)
        #expect(model.adjustHeader.title == "Curves 1")
        #expect(model.adjustHeader.info == "Adjusts the layers below")
        #expect(model.adjustSections == [.curves])
        #expect(AdjustmentsPanel.showsEnable(for: model.adjustTarget) == false)
        #expect(model.selectedLayer?.name == "Curves 1", "the Layer section shows Curves 1's blend and opacity")
        #expect(AdjustTabSample(model: model).showsLayerSettings, "the sample draws the Layer section, as PhotoPanel does")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                AdjustTabSample(model: model), name: "photo-adjust-target-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }

    /// Background selected: the whole image, under "Image", every section
    /// with its enable switch, as the v1 inspector draws it.
    @Test func backgroundTargetsTheImage() throws {
        let model = try layered(selecting: "Background")
        #expect(model.adjustTarget == .image)
        #expect(model.adjustHeader.title == "Image")
        #expect(model.adjustHeader.info == "Adjusts the whole image")
        #expect(model.adjustSections == AdjustmentKind.allCases)
        #expect(AdjustmentsPanel.showsEnable(for: model.adjustTarget))
    }
}

/// The Adjust tab at the inspector's ideal width, in a panel, with the
/// Layer section above the target's header, as PhotoPanel draws it.
private struct AdjustTabSample: View {
    let model: PhotoWorkspace
    let showsLayerSettings = true
    var body: some View {
        PhotoAdjustTab(model: model, perform: { _ in }, showsLayerSettings: showsLayerSettings)
            .frame(width: SuiteSize.inspectorWidth.ideal, height: 720, alignment: .topLeading)
            .background(SuiteColor.panel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
