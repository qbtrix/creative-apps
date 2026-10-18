// HaloFileSnapshots.swift: opening a project (#209, HF-10). The whole
// HaloWindow, at its launch size as HaloWindowSnapshots draws it, after
// `finishOpen` of the two-comps fixture as Spot.halo: titled Spot, Intro and
// Outro in the sidebar, Intro selected with its four layers (Title, Badge,
// Background, Rig; the test checks the count). Then HaloViewer with
// `halo.file.progress` ("Opening Spot…") over it after `beginOpen`. Light
// and Dark. Writes
// halo-opened-project-light.png, halo-opened-project-dark.png,
// halo-file-opening-light.png and halo-file-opening-dark.png. macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloFileSnapshots {
    @Test func openedProject() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.beginOpen(name: "Spot", path: "/t/Spot.halo")
        project.finishOpen(.success(try #require(HaloFixtures.project("two-comps"))))
        #expect(project.windowTitle == "Spot")
        #expect(project.compositions.map(\.name) == ["Intro", "Outro"])
        #expect(!project.file.opening)
        #expect(project.selectedComposition?.name == "Intro")
        #expect(project.selectedComposition?.layers.map(\.name) == ["Title", "Badge", "Background", "Rig"])
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloWindow(model: project)
                    .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "halo-opened-project-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func opening() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("two-comps")))
        project.beginOpen(name: "Spot", path: "/t/Spot.halo")
        #expect(project.file.opening)
        #expect(project.file.recent.first?.name == "Spot")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloViewer(model: project).overlay {
                    if let note = project.openingNote { BusyNote(note, identifier: "halo.file.progress") }
                },
                name: "halo-file-opening-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
