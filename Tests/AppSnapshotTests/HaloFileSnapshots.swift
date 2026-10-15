// HaloFileSnapshots.swift: opening a project (#209, HF-10). HaloViewer after
// `finishOpen` of the two-comps fixture as Spot.halo (Intro selected, its
// three layers), and the same viewer with `halo.file.progress` ("Opening
// Spot…") over it after `beginOpen`. Light and Dark. Writes
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
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloViewer(model: project).overlay { HaloOpenProgress(model: project) },
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
                HaloViewer(model: project).overlay { HaloOpenProgress(model: project) },
                name: "halo-file-opening-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
