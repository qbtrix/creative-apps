// PhotoGammaSnapshots.swift: Photo's adjustments inspector with Levels Gamma
// at each end of gammaRange, so the Pro density Gamma row (its GammaTrack
// slider and SuiteUI ScrubField in the InspectorRow label column) keeps visual
// coverage at its widest values. Light and Dark. Writes
// photo-adjustments-gamma-light.png and photo-adjustments-gamma-dark.png
// (gamma 10), and photo-adjustments-gamma-min-light.png and
// photo-adjustments-gamma-min-dark.png (gamma 0.1). macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoGammaSnapshots {
    @Test func gammaAtTheTopOfItsRange() throws {
        var settings = AdjustmentSettings()
        settings.apply(.gamma(50))
        #expect(settings.gamma == AdjustmentSettings.gammaRange.upperBound)
        try render(settings, name: "photo-adjustments-gamma")
    }

    @Test func gammaAtTheBottomOfItsRange() throws {
        var settings = AdjustmentSettings()
        settings.apply(.gamma(0))
        #expect(settings.gamma == AdjustmentSettings.gammaRange.lowerBound)
        try render(settings, name: "photo-adjustments-gamma-min")
    }

    private func render(_ settings: AdjustmentSettings, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            let view = AdjustmentsInspector(settings: settings)
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
