// HaloWindowSnapshots.swift: Halo's whole window as it opens, on a new
// HaloProject with no compositions, at its launch size (SuiteSize.windowLaunch)
// in the top leading corner of the 1440x900 frame, in Light and Dark. Writes
// halo-window-launch-light.png and halo-window-launch-dark.png; and the
// History panel shown over a project with four edits (halo-history-panel-*).
// macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloWindowSnapshots {
    @Test func launch() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloWindow()
                    .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "halo-window-launch-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// `keyed` with Ball's x typed at frames 0...3 and the History panel shown
    /// (autosave-history HA-2): "New Project" and four "Change Position X"
    /// steps, the fourth current. Writes halo-history-panel-light/dark.png.
    @Test func historyPanel() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" })
        project.selectLayer(ball.id)
        for frame in 0..<4 {
            project.scrub(to: frame)
            project.setProperty(.x, text: "\(100 + frame * 10)")
        }
        #expect(project.historyListing.steps.count == 4)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloWindow(model: project)
                    .environment(\.haloHistoryShelf, HaloHistoryShelf(shown: true))
                    .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "halo-history-panel-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
