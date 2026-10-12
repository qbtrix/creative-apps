// DesignPageMenuSnapshots.swift: Design's Page menu items in a VStack, since
// the menu bar does not render here: with two pages both are enabled, with
// the last page Delete Page is disabled. Writes design-page-menu-light.png and
// design-page-menu-dark.png. macOS only.
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignPageMenuSnapshots {
    @Test func pageMenu() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(PageMenuStates(), name: "design-page-menu-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct PageMenuStates: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Two pages").font(SuiteFont.headline)
            DesignPageMenu(addPage: {}, deletePage: {})
            Text("Last page").font(SuiteFont.headline)
            DesignPageMenu(addPage: {}, deletePage: nil)
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
    }
}
