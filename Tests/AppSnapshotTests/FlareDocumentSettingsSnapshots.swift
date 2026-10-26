// FlareDocumentSettingsSnapshots.swift (document-setup DS-14): File > Document Settings… on `bounce`, the shared
// NewDocumentSheet in settings mode on the scene's setup (550 × 400 px, 24 fps, 2 s, white) with its anchor grid
// (flare-document-settings-light.png, -dark.png). macOS only.
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareDocumentSettingsSnapshots {
    @Test func settingsOnBounce() throws {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        #expect(model.documentSetup.pixelSize.width == 550)
        let sheet = NewDocumentSheet(.settings, setup: model.documentSetup, limits: model.documentLimits,
                                     onDone: { _, _ in }, onCancel: {})
        try snapshot(sheet, name: "flare-document-settings-light", scheme: .light)
        try snapshot(sheet, name: "flare-document-settings-dark", scheme: .dark)
    }
}
