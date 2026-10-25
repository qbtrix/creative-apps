// HaloCompositionSnapshots.swift: New Composition, SuiteUI's New Document sheet over Halo's suggested
// settings (document-setup DS-15), with an invalid width, so its problem line shows (in stateError with the
// error circle) and Create is disabled, in Light and Dark.
// Writes halo-new-comp-sheet-light.png and halo-new-comp-sheet-dark.png, and
// checks that its text fields and Frame Rate menu draw for real, not as the
// yellow "prohibited" placeholder of an offscreen renderer (#152).
// macOS only.
import AppKit
import HaloModel
import SuiteUI
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

    /// The sheet as HaloWindow presents it for New Composition.
    static func newSheet(_ settings: CompositionSettings) -> NewDocumentSheet {
        NewDocumentSheet(.new(presets: [], clipboard: nil), setup: settings.setup, limits: CompositionSettings.limits,
                         onDone: { _, _ in }, onCancel: {})
    }

    @Test func newCompositionSheet() throws {
        try snapshot(Self.newSheet(invalidWidth), name: "halo-new-comp-sheet-light", scheme: .light)
        try snapshot(Self.newSheet(invalidWidth), name: "halo-new-comp-sheet-dark", scheme: .dark)
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func newCompositionSheetFieldsAreNotPlaceholders(scheme: ColorScheme) throws {
        let image = try #require(render(Self.newSheet(invalidWidth), scheme: scheme))
        let samples = placeholderYellowSamples(in: image)
        #expect(samples < 50, "the sheet's fields rendered as placeholders (\(samples) yellow samples, \(scheme))")
    }

    /// The problem line is an error: drawn in stateError (a red), not grey.
    @Test(arguments: [ColorScheme.light, .dark])
    func newCompositionSheetProblemUsesErrorInk(scheme: ColorScheme) throws {
        #expect(!invalidWidth.setup.problems(CompositionSettings.limits).isEmpty)
        let image = try #require(render(Self.newSheet(invalidWidth), scheme: scheme))
        let samples = errorRedSamples(in: image).count
        #expect(samples > 10, "the sheet's problem line isn't in the error color (\(samples) red samples, \(scheme))")
    }
}

/// The pixels, sampled every 2 points, that are clearly red: stateError's ink
/// (light 9E1F1F, dark FF8F8F) and its anti-aliased edges. y counts down from the top.
@MainActor
private func errorRedSamples(in image: NSBitmapImageRep) -> [(x: Int, y: Int)] {
    let points = stride(from: 0, to: image.pixelsHigh, by: 2).flatMap { y in
        stride(from: 0, to: image.pixelsWide, by: 2).map { x in (x: x, y: y) }
    }
    return points.filter { x, y in
        guard let rgb = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
        return rgb.redComponent - max(rgb.greenComponent, rgb.blueComponent) > 0.25
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
