// FlareOpenStatusSnapshots.swift: Flare's window on `bounce` while another
// file opens (layers-files LF-4): the open progress row "Opening…" over the
// stage area, its start pinned a second back so the 100 ms delay has passed.
// Writes flare-open-progress.png. macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareOpenStatusSnapshots {
    @Test func progress() throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.beginOpen()
        let started = Date.now.timeIntervalSinceReferenceDate - 1
        #expect(model.loadState == .loading)
        #expect(model.showsLoadProgress(startedAt: started, now: Date.now.timeIntervalSinceReferenceDate))
        try snapshot(
            FlareWindow(model: model)
                .environment(\.flareOpenStartedAt, started)
                .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            name: "flare-open-progress", scheme: .light)
    }
}
