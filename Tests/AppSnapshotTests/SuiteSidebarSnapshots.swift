// SuiteSidebarSnapshots.swift: SidebarRows with toggles, a count, one
// nested row and a renamable row with no rename active, Light and Dark. The
// rows sit in a VStack with the child indented the way the list's disclosure
// group nests it, so the shot shows the rows themselves. A hidden layer's
// dimmed row sits beside a normal one (LL-4). `goldens()` checks the dimmed
// pair against Golden/sidebar/suiteui-sidebar-dimmed-<appearance>.png in the
// four appearances; its baselines come from the next CI artifact. A rename
// the app refused (LL-6) keeps its field open with the typed name and the
// message under it in stateError, in Light and Dark. macOS only.
import SwiftUI
import Testing
@testable import SuiteUI

@MainActor
@Suite struct SuiteSidebarSnapshots {
    @Test func sidebar() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(SidebarSample(), name: "suiteui-sidebar-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func refusedRename() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                RefusedSample(), name: "suiteui-sidebar-refused-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func goldens() {
        for appearance in SnapshotAppearance.allCases {
            assertGolden(DimmedSample(), size: CGSize(width: 320, height: 120),
                         name: "suiteui-sidebar-dimmed", area: "sidebar", appearance: appearance)
        }
    }
}

/// A visible layer's row above a hidden one's: the hidden row's title and
/// symbol in textSecondary, its toggles drawn as on the normal row.
private struct DimmedSample: View {
    private static func toggles(visible: Bool) -> [SidebarToggle] {
        [
            SidebarToggle(id: "visible", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: visible),
            SidebarToggle(id: "locked", title: "Locked", onSymbol: "lock", offSymbol: "lock.open", isOn: false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            SidebarRow(
                SidebarItem(id: "shown", title: "Shown Layer", systemImage: "square", toggles: Self.toggles(visible: true)),
                onToggle: { _ in })
            SidebarRow(
                SidebarItem(
                    id: "hidden", title: "Hidden Layer", systemImage: "square", toggles: Self.toggles(visible: false),
                    isDimmed: true),
                onToggle: { _ in })
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A row whose rename to "Sky" the app refused: the field stays open with
/// the typed name and the reason under it, above a row that renamed as usual.
private struct RefusedSample: View {
    private static let refusal = "A layer named “Sky” already exists."

    private var refused: SidebarRenameField {
        var field = SidebarRenameField()
        field.open("Layer 2")
        field.type("Sky")
        field.commit(original: "Layer 2", rename: { _ in Self.refusal })
        return field
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            SidebarRow(SidebarItem(id: "sky", title: "Sky", systemImage: "square"), onRename: { (_: String) in })
            SidebarRow(
                SidebarItem(id: "layer-2", title: "Layer 2", systemImage: "square"), onToggle: nil,
                refusableRename: { _ in Self.refusal }, field: refused)
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SidebarSample: View {
    private static func toggles(visible: Bool, locked: Bool) -> [SidebarToggle] {
        [
            SidebarToggle(id: "visible", title: "Visible", onSymbol: "eye", offSymbol: "eye.slash", isOn: visible),
            SidebarToggle(id: "locked", title: "Locked", onSymbol: "lock", offSymbol: "lock.open", isOn: locked),
        ]
    }

    private let child = SidebarItem(
        id: "title", title: "Title Text", systemImage: "textformat", toggles: SidebarSample.toggles(visible: true, locked: true))

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Layers").font(SuiteFont.headline).foregroundStyle(SuiteColor.secondaryText)
            SidebarRow(
                SidebarItem(
                    id: "group", title: "Header Group", systemImage: "folder", toggles: Self.toggles(visible: true, locked: false),
                    children: [child]),
                onToggle: { _ in })
            SidebarRow(child, onToggle: { _ in })
                .padding(.leading, SuiteSpacing.l)
            SidebarRow(
                SidebarItem(
                    id: "bg", title: "Background", systemImage: "rectangle", toggles: Self.toggles(visible: false, locked: true),
                    isDimmed: true),
                onToggle: { _ in })
            // A renamable row after a double-click on its Visible toggle: two
            // clicks leave it on, and the title is a label, not a rename field.
            SidebarRow(
                SidebarItem(id: "shape", title: "Shape", systemImage: "square.on.circle", toggles: Self.toggles(visible: true, locked: false)),
                onToggle: { _ in }, onRename: { _ in })
            SidebarRow(SidebarItem(id: "all", title: "All Photos", systemImage: "photo.on.rectangle.angled", count: 12))
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
