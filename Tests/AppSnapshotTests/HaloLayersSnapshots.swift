// HaloLayersSnapshots.swift: HaloViewer with a composition holding three
// layers, so the status bar shows the layer count, in Light and Dark. Writes
// halo-layers-light.png and halo-layers-dark.png. macOS only.
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloLayersSnapshots {
    @Test func layers() throws {
        var project = HaloProject()
        project.newComposition()
        project.newLayer(.solid)
        project.newLayer(.shape)
        project.newLayer(.text)
        try snapshot(HaloViewer(model: project), name: "halo-layers-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-layers-dark", scheme: .dark)
    }
}
