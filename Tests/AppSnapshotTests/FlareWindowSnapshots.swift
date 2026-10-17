// FlareWindowSnapshots.swift: Flare's whole window on SuiteWindow at its
// launch size, in Light and Dark: with no document (the empty state with New
// Animation, the toolbar's Undo, Redo, Save, Auto-key, Animate… and Export…
// disabled) and with the `bounce` fixture open (SCENES and LAYERS, the stage
// over the timeline, the inspector on Properties). Then the inspector alone on
// its Library tab ("Not built yet"). Writes flare-window-empty-light.png,
// flare-window-empty-dark.png, flare-window-bounce-light.png,
// flare-window-bounce-dark.png and flare-inspector-library.png. macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareWindowSnapshots {
    @Test func empty() throws {
        try window(FlareWorkspace(launch: FlareLaunch(arguments: [])), name: "flare-window-empty")
    }

    @Test func bounce() throws {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        #expect(model.document != nil, "the bounce fixture opened no document")
        try window(model, name: "flare-window-bounce")
    }

    @Test func library() throws {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        try snapshot(
            FlareInspector(model: model, tab: .library, perform: { _ in }, easing: EmptyView())
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, height: SuiteSize.windowLaunch.height, alignment: .top),
            name: "flare-inspector-library", scheme: .light)
    }

    private func window(_ model: FlareWorkspace, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                FlareWindow(model: model)
                    .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
