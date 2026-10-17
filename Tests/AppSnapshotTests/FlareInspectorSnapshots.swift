// FlareInspectorSnapshots.swift: the Properties tab (IT-4) on `bounce` at
// frame 12: Ball (Light, Dark), Ball and Shadow (X reads Mixed), and a refused
// X edit. Writes flare-inspector-ball-light/-dark, -mixed and -refused PNGs.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareInspectorSnapshots {
    @Test func ball() throws {
        var model = Self.bounce()
        model.selectLayer("ball")
        #expect(model.propertyLayerIDs == ["ball"])
        #expect(model.animatedProperties.contains { $0.name == "x" && $0.value != nil })
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Self.inspector(model), name: "flare-inspector-ball-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func mixed() throws {
        var model = Self.bounce()
        model.selectAll()
        #expect(model.propertyLayerIDs.count == 2, "Select All picked \(model.propertyLayerIDs)")
        #expect(model.animatedProperties.first { $0.name == "x" }?.value == nil, "X should read Mixed")
        try snapshot(Self.inspector(model), name: "flare-inspector-mixed", scheme: .light)
    }

    @Test func refused() throws {
        var model = Self.bounce()
        model.selectLayer("ball")
        model.setProperty("x", to: .nan, dragStart: 0)
        #expect(model.layerError != nil, "X set to no number should be refused")
        try snapshot(Self.inspector(model), name: "flare-inspector-refused", scheme: .light)
    }

    private static func bounce() -> FlareWorkspace {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.stepFrame(by: 12)
        return model
    }

    private static func inspector(_ model: FlareWorkspace) -> some View {
        FlareInspector(model: model, tab: .properties, perform: { _ in }, easing: EmptyView())
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, height: SuiteSize.windowLaunch.height, alignment: .top)
            .background(SuiteColor.panel)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
