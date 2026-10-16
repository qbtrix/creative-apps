// FlareRecordingSnapshots.swift: Flare's window on `bounce` with auto-key on
// (draw-key-save DK-14): the 2 pt recording ring round the stage and timeline
// and the recording dot in its top trailing corner, at frame 30 with Select
// chosen, as the J6 journey starts its drag. Writes flare-recording-on.png.
// macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareRecordingSnapshots {
    @Test func on() throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.toggleAutoKey()
        model.setCurrentFrame(30)
        model.selectTool(.select)
        #expect(model.autoKey)
        #expect(model.currentFrame == 30)
        try snapshot(
            FlareWindow(model: model)
                .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
            name: "flare-recording-on", scheme: .light)
    }
}
