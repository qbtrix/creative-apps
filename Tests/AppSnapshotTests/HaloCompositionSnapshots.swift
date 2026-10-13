// HaloCompositionSnapshots.swift: the New Composition sheet with an invalid
// width, so its problem line shows and Create is disabled, in Light and Dark.
// Writes halo-new-comp-sheet-light.png and halo-new-comp-sheet-dark.png, and
// checks that its text fields and Frame Rate picker draw for real, not as the
// yellow "prohibited" placeholder of an offscreen renderer (#152).
// macOS only.
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloCompositionSnapshots {
    private var invalidWidth: CompositionSettings {
        var settings = HaloProject().suggestedSettings
        settings.width = 0
        return settings
    }

    @Test func newCompositionSheet() throws {
        try snapshot(NewCompositionSheet(settings: invalidWidth), name: "halo-new-comp-sheet-light", scheme: .light)
        try snapshot(NewCompositionSheet(settings: invalidWidth), name: "halo-new-comp-sheet-dark", scheme: .dark)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func newCompositionSheetFieldsAreNotPlaceholders(scheme: ColorScheme) throws {
        let image = try #require(render(NewCompositionSheet(settings: invalidWidth), scheme: scheme))
        let samples = placeholderYellowSamples(in: image)
        #expect(samples < 50, "the sheet's fields rendered as placeholders (\(samples) yellow samples, \(scheme))")
    }
}

/// How many pixels, sampled every 4 points, are the placeholder's yellow.
@MainActor
private func placeholderYellowSamples(in image: NSBitmapImageRep) -> Int {
    let points = stride(from: 0, to: image.pixelsHigh, by: 4).flatMap { y in
        stride(from: 0, to: image.pixelsWide, by: 4).map { x in (x, y) }
    }
    return points.filter { x, y in
        guard let rgb = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
        return rgb.redComponent > 0.9 && (0.7..<0.9).contains(rgb.greenComponent) && rgb.blueComponent < 0.2
    }.count
}
