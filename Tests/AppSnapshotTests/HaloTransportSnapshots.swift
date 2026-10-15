// HaloTransportSnapshots.swift: HaloViewer on the three-layers fixture (fake
// services) at frame 12, so all six transport buttons in the status bar are
// enabled: paused (play.fill, Play reads "Paused") and playing (pause.fill,
// Play reads "Playing", Loop "On"). Light and Dark. Writes
// halo-transport-paused-*.png and halo-transport-playing-*.png (VP-10).
// macOS only.
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloTransportSnapshots {
    private func project() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
        project.scrub(to: 12)
        return project
    }

    @Test func paused() throws {
        let project = try project()
        #expect(project.playLabel == "Paused")
        #expect(HaloCommand.allCases.filter { $0.area == .playback && project.unavailableHelp(for: $0) != nil }
            .allSatisfy { $0 == .setInPoint || $0 == .setOutPoint })
        try snapshot(HaloViewer(model: project), name: "halo-transport-paused-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-transport-paused-dark", scheme: .dark)
    }

    @Test func playing() throws {
        var project = try project()
        project.play(at: 0)
        #expect(project.playLabel == "Playing")
        #expect(project.loopLabel == "On")
        #expect(project.unavailableHelp(for: .playPause) == nil)
        try snapshot(HaloViewer(model: project), name: "halo-transport-playing-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-transport-playing-dark", scheme: .dark)
    }
}
