// DesignFileMenuSnapshots.swift: Design's File > New File item in a VStack,
// since the menu bar does not render here: enabled with a window focused,
// disabled without one. Writes design-file-menu-light.png and
// design-file-menu-dark.png. macOS only.
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignFileMenuSnapshots {
    @Test func fileMenu() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(FileMenuStates(), name: "design-file-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct FileMenuStates: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Window focused").font(SuiteFont.headline)
            DesignFileMenu(newFile: {})
            Text("No window").font(SuiteFont.headline)
            DesignFileMenu(newFile: nil)
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
    }
}
