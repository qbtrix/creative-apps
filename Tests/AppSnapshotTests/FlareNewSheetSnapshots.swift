// FlareNewSheetSnapshots.swift: the New Animation sheet (layers-files LF-3)
// in three states: Vertical 9:16 picked (flare-new-sheet.png), a typed
// 800 × 600 that makes it Custom (flare-new-sheet-custom.png), and width 0,
// whose problem shows under the fields and disables Create
// (flare-new-sheet-invalid.png). Frame-rates FR-10b adds the SCENE section on
// `bounce` set to 23.976 fps, its Frame Rate menu titled "23.976 fps"
// (flare-scene-inspector-2398-light.png, -dark.png). macOS only.
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareNewSheetSnapshots {
    @Test func preset() throws {
        let sheet = FlareNewAnimationSheet(spec: NewDocumentSpec(preset: .vertical))
        try snapshot(sheet, name: "flare-new-sheet", scheme: .light)
    }

    @Test func custom() throws {
        var spec = NewDocumentSpec(preset: .hd1080)
        spec.setSize(width: 800, height: 600)
        #expect(spec.preset == nil && spec.problem == nil)
        try snapshot(FlareNewAnimationSheet(spec: spec), name: "flare-new-sheet-custom", scheme: .light)
    }

    @Test func invalid() throws {
        var spec = NewDocumentSpec(preset: .web)
        spec.setSize(width: 0, height: 400)
        #expect(spec.problem != nil)
        try snapshot(FlareNewAnimationSheet(spec: spec), name: "flare-new-sheet-invalid", scheme: .light)
    }

    @Test func sceneAt2398() throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        let ntsc = try #require(FrameRate.common.first { $0.numerator == 24000 && $0.denominator == 1001 })
        model.setSceneFrameRate(ntsc)
        #expect(model.layerError == nil)
        #expect(model.selectedScene?.frameRate == ntsc)
        let view = FlareInspectorScene(model: model, perform: { _ in })
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .top)
            .background(SuiteColor.panel)
        try snapshot(view, name: "flare-scene-inspector-2398-light", scheme: .light)
        try snapshot(view, name: "flare-scene-inspector-2398-dark", scheme: .dark)
    }
}
