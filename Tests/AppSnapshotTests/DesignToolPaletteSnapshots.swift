// DesignToolPaletteSnapshots.swift (eyedropper DY-2): Design's window on the `cards` fixture with the floating
// tool palette showing every tool, the Eyedropper (I) last, enabled since DY-5 made its click
// pick. Writes design-tool-palette-light.png and design-tool-palette-dark.png. The Shape and Eyedropper option
// shots render the inspector panel alone: the window snapshot leaves its inspector column blank. macOS only.
#if canImport(AppKit)
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignToolPaletteSnapshots {
    @Test func paletteShowsTheEyedropper() throws {
        #expect(DesignTool.allCases.last == .eyedropper)
        #expect(DesignTool.eyedropper.title == "Eyedropper")
        #expect(DesignTool.eyedropper.shortcut == "i")
        #expect(DesignTool.eyedropper.unavailableHelp == nil, "DY-5: a click picks")
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignEditor(model: model, zoom: 0.5),
                name: "design-tool-palette-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// shape-tools DS-2: with the Shape tool (U) picked, the inspector leads with its Shape options.
    /// Writes design-shape-options-light.png and design-shape-options-dark.png.
    @Test func theShapeToolShowsItsOptions() throws {
        #expect(DesignTool.shape.title == "Shape" && DesignTool.shape.shortcut == "u")
        #expect(DesignTool.shape.unavailableHelp?.isEmpty == false, "a disabled tool says why")
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectTool(.shape)
        #expect(model.tool == .shape)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                OptionsPanel(model: model),
                name: "design-shape-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// eyedropper #3985, #3993: with the Eyedropper picked, the inspector leads with its options, the 5 × 5 size
    /// and Stroke chosen; the artboard carries no chips. Writes design-eyedropper-options-light.png and -dark.png.
    @Test func theEyedropperShowsItsOptions() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectTool(.eyedropper)
        model.setSampleSize(.fiveByFive)
        model.setSampleTarget(toStroke: true)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                OptionsPanel(model: model),
                name: "design-eyedropper-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// eyedropper #4061: in the inspector the chips share its width, so the selected Point chip reads "Point" in full,
    /// not "Poi…" as it did when the chips sat sized to fit on the artboard. Writes design-eyedropper-point-light.png
    /// and -dark.png.
    @Test func theEyedropperShowsPointInFull() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectTool(.eyedropper)
        model.setSampleSize(.point)
        #expect(model.sampleSize == .point)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                OptionsPanel(model: model),
                name: "design-eyedropper-point-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

/// The inspector at the editor's panel width. The window snapshot leaves the split view's inspector column
/// blank, so a tool's options are shot here, where they draw.
private struct OptionsPanel: View {
    let model: DesignWorkspace
    var body: some View {
        DesignInspector(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
#endif
