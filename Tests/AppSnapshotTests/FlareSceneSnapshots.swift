// FlareSceneSnapshots.swift: the SCENE section (inspector-timeline IT-6) on
// `bounce` with nothing selected: Width 550, Height 400, the background,
// Frame Rate 24 fps, Duration 48 frames and the size presets, none on.
// Writes flare-scene-section.png. macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareSceneSnapshots {
    @Test func section() throws {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        #expect(model.propertyLayerIDs.isEmpty)
        #expect(model.inspectorSummary.showsScene)
        let scene = try #require(model.selectedScene)
        #expect(scene.width == 550 && scene.height == 400)
        #expect(scene.fps == 24 && scene.durationFrames == 48)
        let view = FlareInspectorScene(model: model, perform: { _ in })
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .top)
            .background(SuiteColor.panel)
        try snapshot(view, name: "flare-scene-section", scheme: .light)
    }
}
