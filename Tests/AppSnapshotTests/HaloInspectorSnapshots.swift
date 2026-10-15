// HaloInspectorSnapshots.swift: Halo's layer inspector on the `keyed`
// fixture with Ball selected at frame 12: the header, TRANSFORM's eight bar
// rows each with its keyframe button (Position X animated with a hollow
// diamond, Opacity keyed here with a filled one and its bar in the keyed
// color, the rest not animated), then the EASING and TEXT slots; and the same
// after typing "abc" into Rotation, with "Rotation needs a number." under the
// Rotation row. Light and Dark, at the inspector's ideal width. Writes
// halo-inspector-{light,dark}.png and halo-inspector-refusal-{light,dark}.png.
// Also LAYER on `parented` at frame 0 with Ball following Rig and blending
// Multiply (halo-inspector-layer-*), and the `keyed` inspector at the minimum
// width, each keyframe button under its bar so TRANSFORM's titles read in
// full, LAYER unclipped (halo-inspector-narrow-*). macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloInspectorSnapshots {
    @Test func transformRows() throws {
        let project = try ballAt12()
        #expect(project.propertyRows.map(\.property) == HaloProperty.allCases)
        #expect(project.propertyRows.first { $0.property == .x }?.keyState == .animated)
        #expect(project.propertyRows.first { $0.property == .opacity }?.keyState == .keyedHere)
        #expect(project.propertyRows.first { $0.property == .rotation }?.keyState == .notAnimated)
        try snapshots(project, name: "halo-inspector")
    }

    /// Typed text that isn't a number: the caption sits under Rotation.
    @Test func refusalUnderItsRow() throws {
        var project = try ballAt12()
        project.setProperty(.rotation, text: "abc")
        #expect(project.refusal == HaloRefusal(control: "halo.inspector.row.rotation", message: "Rotation needs a number."))
        try snapshots(project, name: "halo-inspector-refusal")
    }

    /// LAYER: Parent reads Rig (None, Rig, Floor offered), Blend Multiply.
    /// At frame 0, as the parenting journey does: Ball keeps its place and
    /// Set Parent writes no key, so Position X still reads 160.0 px.
    @Test func layerGroup() throws {
        var project = try ball("parented", at: 0)
        let rig = try #require(project.parentChoices.first { $0.name == "Rig" })
        #expect(project.parentChoices.map(\.name) == ["Rig", "Floor"])
        let before = project.propertyRows.first { $0.property == .x }
        project.setParent(rig.id)
        let after = project.propertyRows.first { $0.property == .x }
        #expect(after?.text == "160.0 px")
        #expect(after?.keyState == before?.keyState)
        project.setSelectedLayerBlendMode(.multiply)
        #expect(project.selectedLayer?.parentID == rig.id)
        #expect(project.selectedLayer?.blendMode == .multiply)
        #expect(project.refusal == nil)
        #expect(project.unavailableHelp(for: .setParent(rig.id)) == nil)
        #expect(project.unavailableHelp(for: .setBlendMode(.multiply)) == nil)
        try snapshots(project, name: "halo-inspector-layer")
    }

    /// The inspector at its minimum width: each keyframe button under its
    /// bar, so every TRANSFORM title reads in full ("Position X" apart from
    /// "Position Y") and no value sits under its bar's marker; LAYER as wide.
    @Test func narrowInspector() throws {
        let project = try ballAt12()
        #expect(SuiteSize.inspectorWidth.min == 200)
        let titles = project.propertyRows.map(\.property.title)
        #expect(Set(titles).count == titles.count)
        try snapshots(project, name: "halo-inspector-narrow", width: SuiteSize.inspectorWidth.min)
    }

    /// `fixture` (`keyed` by default) with Ball selected and the playhead at frame 12.
    private func ballAt12(_ fixture: String = "keyed") throws -> HaloProject {
        try ball(fixture, at: 12)
    }

    /// `fixture` with Ball selected and the playhead at `frame`.
    private func ball(_ fixture: String, at frame: Int) throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project(fixture)))
        let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" })
        project.selectLayer(ball.id)
        project.scrub(to: frame)
        #expect(project.selectedLayerHeader != nil)
        return project
    }

    /// The inspector in its column on the panel, as `<name>-light.png` and `<name>-dark.png`.
    private func snapshots(_ model: HaloProject, name: String, width: CGFloat = SuiteSize.inspectorWidth.ideal) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloLayerInspector(model: model)
                    .frame(width: width, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme.name)", scheme: scheme)
        }
    }
}
