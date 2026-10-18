// HaloEditMenuSnapshots.swift: Halo's Edit menu items (SuiteUI's MenuCommand for
// .undo and .redo, as HaloEditMenu builds them) drawn as buttons, since the
// menu bar does not render here, on the empty fixture with live services
// after New Layer: "Undo New Layer" enabled, "Redo" disabled with "Nothing to
// redo." as its reason. Writes halo-edit-menu-light.png and
// halo-edit-menu-dark.png. macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloEditMenuSnapshots {
    @Test func editMenu() throws {
        var project = HaloProject(services: .live, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.solid)
        let target = HaloMenuTarget(model: project, perform: { _ in })
        #expect(target.title(for: .undo) == "Undo New Layer" && target.help(for: .undo) == nil)
        #expect(target.title(for: .redo) == "Redo" && target.help(for: .redo) == "Nothing to redo.")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(EditMenuItems(target: target), name: "halo-edit-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct EditMenuItems: View {
    let target: HaloMenuTarget

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("After New Layer").font(SuiteFont.headline)
            MenuCommand(command: .undo, target: target, shortcut: KeyboardShortcut("z"))
            MenuCommand(command: .redo, target: target, shortcut: KeyboardShortcut("z", modifiers: [.command, .shift]))
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
