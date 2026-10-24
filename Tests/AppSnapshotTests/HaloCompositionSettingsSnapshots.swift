// HaloCompositionSettingsSnapshots.swift (document-setup DS-12): Composition Settings… on a 1920 x 1080, 30 fps,
// 15 s navy composition, the shared sheet on Halo's limits. Writes `halo-composition-settings-{light,dark}.png`.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloCompositionSettingsSnapshots {
    private let settings = CompositionSettings(name: "Comp 1", setup: DocumentSetup(
        width: 1920, height: 1080, background: .color(hex: "#1B2A4A"), frameRate: FrameRate(whole: 30), durationSeconds: 15))
    @Test func compositionSettingsNavy() throws {
        #expect(settings.isValid && settings.durationFrames == 450)
        for scheme in [ColorScheme.light, .dark] {
            let sheet = NewDocumentSheet(.settings, setup: settings.setup, limits: CompositionSettings.limits,
                                         onDone: { _, _ in }, onCancel: {})
            try snapshot(sheet, name: "halo-composition-settings-\(scheme == .light ? "light" : "dark")", scheme: scheme)
        }
    }
}
