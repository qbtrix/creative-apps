// PhotoAdjustmentsSnapshots.swift: Photo's adjustments inspector with
// Exposure at +1, Levels Black 0.998 and White 0.999 (one step apart, read
// apart), and the other sections at their defaults, at the inspector's
// ideal width, in Light and Dark. Writes photo-adjustments-light.png and
// photo-adjustments-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoAdjustmentsSnapshots {
    @Test func adjustments() throws {
        var settings = AdjustmentSettings()
        settings.apply(.exposure(1))
        settings.apply(.whitePoint(0.999))
        settings.apply(.blackPoint(0.998))
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                AdjustmentsSample(settings: settings), name: "photo-adjustments-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }
}

private struct AdjustmentsSample: View {
    let settings: AdjustmentSettings
    var body: some View {
        AdjustmentsInspector(settings: settings)
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
