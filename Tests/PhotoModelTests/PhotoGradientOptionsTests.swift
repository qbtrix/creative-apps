// PhotoGradientOptionsTests.swift (gradient-fill PG-4): the Gradient tool's
// options take each editor gesture through the kernel's `GradientRules`. The
// tool draws only linear and radial gradients, so a switch to solid is
// ignored, and it has no angle (the drag gives the line), so an angle is
// ignored too. Runs on Linux and macOS.
import FlareCore
import PhotoModel
import SuiteKernel
import Testing

struct PhotoGradientOptionsTests {
    /// A workspace with the Gradient tool picked, its options the default.
    static func picked() -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        workspace.selectTool(.gradient)
        return workspace
    }

    @Test func addAtHalfAddsAStopInTheColourShownThere() {
        var workspace = Self.picked()
        workspace.runGradientOption(.add(offset: 0.5))
        let stops = workspace.toolOptions.gradient.stops
        #expect(stops.map(\.offset) == [0, 0.5, 1])
        #expect(stops.count == 3 && stops[1].color == FillColor(r: 0.5, g: 0.5, b: 0.5, a: 1))
    }

    @Test func keepsTwoStops() {
        var workspace = Self.picked()
        workspace.runGradientOption(.remove(index: 0))
        #expect(workspace.toolOptions.gradient == ToolOptions.defaultGradient)
        workspace.runGradientOption(.add(offset: 0.5))
        workspace.runGradientOption(.remove(index: 1))
        #expect(workspace.toolOptions.gradient.stops == ToolOptions.defaultGradient.stops)
    }

    @Test func toolIsNeverSolid() {
        var workspace = Self.picked()
        workspace.runGradientOption(.type(.solid))
        #expect(workspace.toolOptions.gradient == ToolOptions.defaultGradient)
        workspace.runGradientOption(.type(.radial))
        let radial = workspace.toolOptions.gradient
        #expect(GradientRules.type(of: radial) == .radial && radial.stops == ToolOptions.defaultGradient.stops)
        workspace.runGradientOption(.type(.solid))
        #expect(workspace.toolOptions.gradient == radial)
        workspace.runGradientOption(.type(.linear))
        #expect(GradientRules.type(of: workspace.toolOptions.gradient) == .linear)
    }

    @Test func angleIsIgnored() {
        var workspace = Self.picked()
        workspace.runGradientOption(.angle(90, drag: nil))
        #expect(workspace.toolOptions.gradient == ToolOptions.defaultGradient)
    }

    @Test func moveAndColourEditTheStops() {
        var workspace = Self.picked()
        workspace.runGradientOption(.move(index: 0, offset: 0.25, drag: "d"))
        workspace.runGradientOption(.color(index: 1, FillColor(r: 0, g: 0, b: 1, a: 1), drag: nil))
        let stops = workspace.toolOptions.gradient.stops
        #expect(stops.map(\.offset) == [0.25, 1])
        #expect(stops.map(\.color) == [.black, FillColor(r: 0, g: 0, b: 1, a: 1)])
    }

    /// The options are the brush's set, which the panel shows for the tool,
    /// and the brush's settings stay as they were.
    @Test func anEditLeavesTheBrushSettingsAlone() {
        var workspace = Self.picked()
        let settings = workspace.toolOptions.settings
        workspace.runGradientOption(.add(offset: 0.5))
        #expect(workspace.brushOptions.gradient.stops.count == 3)
        #expect(workspace.toolOptions.settings == settings && workspace.eraserOptions.gradient == ToolOptions.defaultGradient)
    }
}
