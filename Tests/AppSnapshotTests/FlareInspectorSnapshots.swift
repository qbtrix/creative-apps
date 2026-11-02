// FlareInspectorSnapshots.swift: the Properties tab (IT-4) on `bounce` at
// frame 12: Ball (Light, Dark), Ball and Shadow (X reads Mixed), a refused
// X edit, and Ball with a linear gradient fill (gradient-fill FG-a). Writes
// flare-inspector-ball-light/-dark, -mixed, -refused and -gradient PNGs. The
// panel sizes to its content, so STROKE and TIMING draw on the panel, not
// past it (#4045); `panelHoldsContent` checks that geometry in each state.
import AppKit
@testable import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareInspectorSnapshots {
    @Test func ball() throws {
        let model = Self.ballModel()
        #expect(model.propertyLayerIDs == ["ball"])
        #expect(model.animatedProperties.contains { $0.name == "x" && $0.value != nil })
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Self.inspector(model), name: "flare-inspector-ball-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func mixed() throws {
        try snapshot(Self.inspector(Self.mixedModel()), name: "flare-inspector-mixed", scheme: .light)
    }

    @Test func refused() throws {
        try snapshot(Self.inspector(Self.refusedModel()), name: "flare-inspector-refused", scheme: .light)
    }

    @Test func gradient() throws {
        let model = Self.gradientModel()
        #expect(model.paint?.fillIsGradient == true, "Ball's fill reads as a gradient")
        try snapshot(Self.inspector(model), name: "flare-inspector-gradient", scheme: .light)
    }

    /// #4045: in every state the panel background is at least as tall as the
    /// inspector's content, so its last section (TIMING) ends inside it, and
    /// the panel fits the 900 pt snapshot.
    @Test func panelHoldsContent() {
        let states = [("ball", Self.ballModel()), ("mixed", Self.mixedModel()), ("refused", Self.refusedModel()),
                      ("gradient", Self.gradientModel())]
        for (name, model) in states {
            let content = Self.fittingHeight(Self.content(model))
            let panel = Self.fittingHeight(Self.panel(model))
            #expect(content > 0, "\(name): the content measured nothing")
            #expect(content <= panel + 0.5, "\(name): \(content) pt of content against a \(panel) pt panel")
            #expect(panel <= 900, "\(name): the \(panel) pt panel is taller than the snapshot")
        }
    }

    private static func bounce() -> FlareWorkspace {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.stepFrame(by: 12)
        return model
    }

    private static func ballModel() -> FlareWorkspace {
        var model = bounce()
        model.selectLayer("ball")
        return model
    }

    private static func mixedModel() -> FlareWorkspace {
        var model = bounce()
        model.selectAll()
        #expect(model.propertyLayerIDs.count == 2, "Select All picked \(model.propertyLayerIDs)")
        #expect(model.animatedProperties.first { $0.name == "x" }?.value == nil, "X should read Mixed")
        return model
    }

    private static func refusedModel() -> FlareWorkspace {
        var model = ballModel()
        model.setProperty("x", to: .nan, dragStart: 0)
        #expect(model.layerError != nil, "X set to no number should be refused")
        return model
    }

    /// `bounce` with Ball's circle filled by a three-stop left-to-right linear
    /// gradient, loaded directly: the fill commands are not built yet (FG-5).
    private static func gradientModel() -> FlareWorkspace {
        var document = FlareFixtures.bounce
        let stops = [GradientStop(offset: 0, color: FillColor(r: 1, g: 0.23, b: 0.19)),
                     GradientStop(offset: 0.5, color: FillColor(r: 1, g: 0.8, b: 0)),
                     GradientStop(offset: 1, color: FillColor(r: 0, g: 0.48, b: 1))]
        let fill = Fill.linear(stops: stops, start: Point(x: -30, y: 0), end: Point(x: 30, y: 0))
        for s in document.scenes.indices {
            for l in document.scenes[s].layers.indices where document.scenes[s].layers[l].id == "ball" {
                for i in document.scenes[s].layers[l].shapes.indices {
                    document.scenes[s].layers[l].shapes[i].fill = fill
                }
            }
        }
        var model = FlareWorkspace(services: .fake())
        model.load(document)
        model.stepFrame(by: 12)
        model.selectLayer("ball")
        return model
    }

    /// The inspector's content as the snapshot lays it out, without the panel.
    private static func content(_ model: FlareWorkspace) -> some View {
        FlareInspector(model: model, tab: .properties, perform: { _ in }, easing: EmptyView())
            .padding(SuiteSpacing.m)
            .frame(width: FlareWindow.inspectorWidth, alignment: .top)
    }

    /// The panel: the content on the panel background, as tall as the content.
    private static func panel(_ model: FlareWorkspace) -> some View {
        content(model)
            .fixedSize(horizontal: false, vertical: true)
            .background(SuiteColor.panel)
    }

    private static func inspector(_ model: FlareWorkspace) -> some View {
        panel(model)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// `view`'s fitting height in points, with snapshot rendering on.
    private static func fittingHeight(_ view: some View) -> CGFloat {
        _ = TestDefaults.registered
        let host = NSHostingView(rootView: view.environment(\.suiteSnapshotRendering, true))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }
}
