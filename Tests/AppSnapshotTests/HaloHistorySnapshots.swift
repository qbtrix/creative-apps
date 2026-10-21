// HaloHistorySnapshots.swift (autosave-history HA-4, packet
// docs/blueprints/halo/features/autosave-history.md, Screens and states):
// Halo's whole window at its launch size with the History panel shown, as
// HaloWindowSnapshots' `historyPanel` shoots it, in Light and Dark.
// `jumped`: four edits taken back to step 2, the state a jump to row 2 lands
// on (reached here by two undos, the Model's own steps, while the jump's body
// is HA-5's), so steps 3 and 4 read secondary and "not applied". `empty`: no
// edits, "New Project" and "No changes yet.". Writes
// halo-history-panel-jumped-light/dark.png and
// halo-history-panel-empty-light/dark.png. The recovery offer is a system
// alert, shot by the journey (HA-7). macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloHistorySnapshots {
    @Test func jumped() throws {
        var project = try BodyCountSuites.HaloHistoryAreaTests.edited(4)
        project.undo()
        project.undo()
        #expect(project.historyListing.index == 2 && project.historyListing.steps.count == 4)
        try snapshots(project, name: "halo-history-panel-jumped")
    }

    @Test func empty() throws {
        let project = try BodyCountSuites.HaloHistoryAreaTests.edited(0)
        #expect(project.historyListing.steps.isEmpty)
        try snapshots(project, name: "halo-history-panel-empty")
    }

    private func snapshots(_ project: HaloProject, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloWindow(model: project)
                    .environment(\.haloHistoryShelf, HaloHistoryShelf(shown: true))
                    .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
