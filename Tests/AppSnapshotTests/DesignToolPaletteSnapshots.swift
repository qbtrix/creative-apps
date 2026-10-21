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
}
#endif
