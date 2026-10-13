// SuiteEditorBarDimmingTests.swift: a disabled top bar command draws dimmer
// than an enabled one, in Light and Dark. EditorBarLabelStyle colors the
// symbol, which overrides the system's disabled dimming unless the style dims
// it too. Measured on the rendered pixels: the summed distance from the
// background, so it holds wherever the button lands in the frame. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Test func aDisabledBarCommandDrawsDimmerThanAnEnabledOne() throws {
    for scheme in [ColorScheme.light, .dark] {
        let enabled = try ink(EditorBarItem(ToolbarAction("Undo", systemImage: "arrow.uturn.backward"), showsTitle: false), scheme)
        let disabled = try ink(
            EditorBarItem(
                ToolbarAction("Undo", systemImage: "arrow.uturn.backward", unavailableHelp: "Nothing to undo."),
                showsTitle: false),
            scheme)
        #expect(enabled > 0, "the enabled command drew nothing in \(scheme)")
        #expect(disabled < enabled * 0.8, "disabled \(disabled) vs enabled \(enabled) in \(scheme)")
    }
}

/// How far `view`'s pixels sit from the background, summed over every other pixel.
@MainActor
private func ink(_ view: some View, _ scheme: ColorScheme) throws -> Double {
    let image = try #require(render(view, scheme: scheme))
    let background = try #require(image.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
    var total = 0.0
    for y in stride(from: 0, to: image.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: image.pixelsWide, by: 2) {
            guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            total += abs(color.redComponent - background.redComponent)
                + abs(color.greenComponent - background.greenComponent)
                + abs(color.blueComponent - background.blueComponent)
        }
    }
    return total
}
