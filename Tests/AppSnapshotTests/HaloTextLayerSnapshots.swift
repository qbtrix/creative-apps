// HaloTextLayerSnapshots.swift: Halo's TEXT section (#430, TX-6) on `empty`
// with the fake services and a new text layer, "Hello" at 96. The viewer
// drawing it beside the TEXT section (the field, the "96 px" size bar, the
// color row) at the inspector's ideal width (halo-text-layer-*), and the
// same after a blank commit, with "Enter some text." under the field that
// still holds "Hello" (halo-text-refused-*). Light and Dark. Also: the
// section draws nothing for a solid layer. macOS only.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloTextLayerSnapshots {
    @Test func textLayer() throws {
        let project = try hello()
        #expect(project.selectedText?.string == "Hello")
        #expect(project.selectedText?.sizeText == "96 px")
        #expect(project.refusal == nil)
        #expect(project.unavailableHelp(for: .setText("Hello")) == nil)
        try snapshots(project, name: "halo-text-layer")
    }

    @Test func refusedBlankText() throws {
        var project = try hello()
        project.setText("   ")
        #expect(project.refusal == HaloRefusal(control: HaloTextInspector.stringID, message: "Enter some text."))
        #expect(project.selectedText?.string == "Hello")
        try snapshots(project, name: "halo-text-refused")
    }

    @Test func noSectionForASolid() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.solid)
        #expect(project.selectedText == nil)
        let solid = NSHostingView(rootView: HaloTextInspector(model: project).frame(width: SuiteSize.inspectorWidth.ideal))
        let text = NSHostingView(rootView: HaloTextInspector(model: try hello()).frame(width: SuiteSize.inspectorWidth.ideal))
        #expect(solid.fittingSize.height < 1)
        #expect(text.fittingSize.height > 0)
    }

    /// `empty` on `.fake` with a new text layer reading "Hello" at 96.
    private func hello() throws -> HaloProject {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.text)
        project.setText("Hello")
        project.setFontSize(96)
        project.endTextSizeScrub()
        return project
    }

    /// The viewer beside the TEXT section on the panel, as `<name>-light.png` and `<name>-dark.png`.
    private func snapshots(_ model: HaloProject, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HStack(spacing: 0) {
                    HaloViewer(model: model)
                    HaloTextInspector(model: model)
                        .padding(.vertical, SuiteSpacing.m)
                        .frame(width: SuiteSize.inspectorWidth.ideal)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(SuiteColor.panel)
                },
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
