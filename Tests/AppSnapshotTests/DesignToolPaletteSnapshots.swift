// DesignToolPaletteSnapshots.swift (eyedropper DY-2): Design's window on the `cards` fixture with the floating
// tool palette showing every tool, the Eyedropper (I) last, disabled with its reason until DY-5 makes its click
// pick. Writes design-tool-palette-light.png and design-tool-palette-dark.png. macOS only.
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
        #expect(DesignTool.eyedropper.unavailableHelp?.isEmpty == false, "a disabled tool says why")
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
                DesignEditor(model: model, zoom: 0.5),
                name: "design-shape-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// eyedropper #3985, #3993: with the Eyedropper picked, the inspector leads with its options, the 5 × 5 size
    /// and Stroke chosen; the artboard carries no chips. Writes design-eyedropper-options-light.png and -dark.png.
    @Test func theEyedropperShowsItsOptions() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        #expect(model.openFixture("cards"))
        model.selectTool(.eyedropper)
        model.setSampleSize(.fiveByFive)
        model.setSampleTarget(toStroke: true)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignEditor(model: model, zoom: 0.5),
                name: "design-eyedropper-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
#endif
