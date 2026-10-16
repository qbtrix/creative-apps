// HaloEasingSnapshots.swift: Halo's EASING group (#428, EZ-6) on the `keyed`
// fixture. With Ball selected and Position X 0 → 24 picked with Ease In and
// Out: the two rows (the picked one selected), the chips with Ease In and
// Out on, the curve and X1 Y1 X2 Y2 (halo-easing-*). Ball with nothing
// picked: the rows and "Pick a key above." (halo-easing-unpicked-*). Floor,
// which has no property of two keys: "Key a property to shape its easing."
// (halo-easing-empty-*). Light and Dark, at the inspector's ideal width.
// macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloEasingSnapshots {
    /// x 0 picked with Ease In and Out: its row reads it, its chip is on.
    @Test func pickedSegment() throws {
        var project = try layer("Ball")
        let x0 = try #require(project.keySegments.first { $0.key.property == .x && $0.key.frame == 0 })
        project.selectKey(x0.key, extending: false)
        project.setEasing(.easeInOut)
        #expect(project.pickedSegment?.key == x0.key)
        #expect(project.pickedSegment?.easingTitle == "Ease In and Out")
        #expect(project.pickedPreset == .easeInOut)
        #expect(project.easingHandles != nil)
        #expect(project.easingCurve(count: 129).count == 129)
        #expect(project.refusal == nil)
        try snapshots(project, name: "halo-easing")
    }

    /// Ball's segments with none picked: the rows and "Pick a key above.".
    @Test func unpicked() throws {
        let project = try layer("Ball")
        #expect(project.keySegments.map(\.title) == ["Position X 0 → 24", "Opacity 0 → 12"])
        #expect(project.keySegments.map(\.easingTitle) == ["Linear", "Linear"])
        #expect(project.pickedSegment == nil)
        #expect(project.easingHandles == nil)
        try snapshots(project, name: "halo-easing-unpicked")
    }

    /// Floor has no property of two keys: "Key a property to shape its easing.".
    @Test func noSegments() throws {
        let project = try layer("Floor")
        #expect(project.keySegments.isEmpty)
        try snapshots(project, name: "halo-easing-empty")
    }

    /// `keyed` on `.fake` with the layer named `name` selected.
    private func layer(_ name: String) throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let layer = try #require(project.selectedComposition?.layers.first { $0.name == name })
        project.selectLayer(layer.id)
        #expect(project.selectedLayer?.id == layer.id)
        return project
    }

    /// The EASING group in its column on the panel, as `<name>-light.png` and `<name>-dark.png`.
    private func snapshots(_ model: HaloProject, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloEasingInspector(model: model)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 520, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme.name)", scheme: scheme)
        }
    }
}
