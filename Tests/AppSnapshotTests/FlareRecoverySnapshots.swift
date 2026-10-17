// FlareRecoverySnapshots.swift: Flare's window after a failed save
// (docs/blueprints/flare/features/layers-files.md, LF-5): `bounce` with an
// edit (New Layer) and a save that failed, so "Not saved" shows in the error
// color with its triangle at the window's bottom trailing corner
// (`flare.saveStatus`). The alert and the recovery offer are system alerts,
// shot by J28 instead. Writes flare-save-failed.png. macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareRecoverySnapshots {
    @Test func saveFailed() throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.addLayer()
        model.saveFailed("You don't have permission to save the file in the folder.")
        #expect(model.saveStatus == "Not saved")
        #expect(model.isDirty)
        try snapshot(
            FlareWindow(model: model)
                .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            name: "flare-save-failed", scheme: .light)
    }
}
