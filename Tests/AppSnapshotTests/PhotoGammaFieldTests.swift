// PhotoGammaFieldTests.swift: the Levels Gamma field's text rules. It formats
// and parses through NumericInput (locale-free), clamps to gammaRange, and an
// edit that clamps to the stored gamma commits nothing, so the field shows the
// stored value again. Also renders the inspector with gamma clamped to 10 to
// photo-adjustments-gamma-light.png and photo-adjustments-gamma-dark.png.
// macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoGammaFieldTests {
    @Test func formatsLocaleFreeAndRoundTrips() {
        for gamma: Float in [0.1, 0.25, 0.5, 1, 2.2, 10] {
            let text = GammaField.text(for: gamma)
            #expect(!text.contains(","))
            let committed = GammaField.committed(text, from: 1) ?? 1
            #expect(GammaField.text(for: committed) == text)
        }
        #expect(GammaField.text(for: 0.5) == "0.5")
        #expect(GammaField.text(for: 1) == "1")
    }

    @Test func clampsTypedValuesToGammaRange() {
        #expect(GammaField.committed("50", from: 1) == 10)
        #expect(GammaField.committed("0", from: 1) == 0.1)
        #expect(GammaField.committed("-3", from: 2) == 0.1)
        #expect(GammaField.committed(" 2.5 ", from: 1) == 2.5)
    }

    @Test func editThatClampsToTheStoredValueCommitsNothing() {
        #expect(GammaField.committed("50", from: 10) == nil)
        #expect(GammaField.committed("0", from: 0.1) == nil)
        #expect(GammaField.committed("abc", from: 2) == nil)
        #expect(GammaField.committed("0,5", from: 2) == nil)
    }

    @Test func committedValuesStayClampedInTheModel() {
        var settings = AdjustmentSettings()
        if let value = GammaField.committed("50", from: settings.gamma) { settings.apply(.gamma(value)) }
        #expect(settings.gamma == 10)
        #expect(GammaField.text(for: settings.gamma) == "10")
    }

    @Test func gammaAtTheTopOfItsRange() throws {
        var settings = AdjustmentSettings()
        settings.apply(.gamma(10))
        for scheme in [ColorScheme.light, .dark] {
            let view = AdjustmentsInspector(settings: settings)
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(
                view, name: "photo-adjustments-gamma-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
