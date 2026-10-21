// FlareShapeSnapshots.swift: shape-tools FS-4 (docs/blueprints/flare/features/shape-tools.md). The Shape tool's
// options in the Properties inspector (the chips on Star, Points 5) and a five-point star draft on `bounce`'s stage
// during the drag. Writes flare-shape-options-light/-dark and flare-shape-star-draft-light/-dark PNGs.
import FlareCore
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareShapeSnapshots {
    private static let size = CGSize(width: 1440, height: 900)

    @Test func options() throws {
        var model = Self.bounce()
        model.selectTool(.shape)
        #expect(model.shapeTool.kind == .star && model.shapeTool.points == 5)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Self.inspector(model), name: "flare-shape-options-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func starDraft() throws {
        var model = Self.bounce()
        model.selectTool(.shape)
        model.dragChanged(from: Point(x: 300, y: 60), to: Point(x: 460, y: 180), modifiers: .shift)
        #expect(model.draft?.shape.points.count == 10, "a Shift drag drafts a five-point star")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Self.stage(model), name: "flare-shape-star-draft-\(scheme.name)", scheme: scheme)
        }
    }

    private static func bounce() -> FlareWorkspace {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        #expect(model.selectedScene != nil, "bounce opened no scene")
        return model
    }

    private static func inspector(_ model: FlareWorkspace) -> some View {
        let options = FlareShapeOptions(spec: model.shapeTool, help: ShapeRules.help(model.shapeTool)) { _ in }
        return FlareInspector(model: model, tab: .properties, perform: { _ in }, easing: EmptyView(), shape: options)
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, height: SuiteSize.windowLaunch.height, alignment: .top)
            .background(SuiteColor.panel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private static func stage(_ model: FlareWorkspace) -> some View {
        let scene = CGSize(width: model.selectedScene?.width ?? 1, height: model.selectedScene?.height ?? 1)
        let viewport = CGSize(width: size.width - SuiteSize.ruler, height: size.height - SuiteSize.ruler)
        return FlareStage(
            model: model, zoom: ZoomMath.fit(document: scene, in: viewport), showsRulers: true, showsGuides: true,
            perform: { _ in }, help: { _ in nil })
    }
}
