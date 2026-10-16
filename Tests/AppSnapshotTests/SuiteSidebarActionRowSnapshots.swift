// SuiteSidebarActionRowSnapshots.swift: SidebarActionRow under two sidebar
// list sections (Pages: Add Page, Delete Page disabled; Layers: New Layer,
// Rename Layer…, Delete Layer), in Light and Dark. Writes
// suiteui-sidebar-action-row-light.png and suiteui-sidebar-action-row-dark.png.
// A disabled command's symbol draws fainter than an enabled one's, measured
// on the rendered pixels with this file's own copy of the ink helper in
// SuiteEditorBarDimmingTests (ER-1 deletes that file). Every button's
// accessibility label and tooltip come from its ToolbarAction, and an
// identified action registers its identifier, enabled state and reason in
// the control inventory (`suite.controls`). SwiftUI builds a hosting view's
// accessibility tree only for an assistive client, so the inventory and the
// row's own command list stand in for it. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteSidebarActionRowSnapshots {
    @Test func sidebarActionRow() throws {
        try snapshot(ActionRowSheet(), name: "suiteui-sidebar-action-row-light", scheme: .light)
        try snapshot(ActionRowSheet(), name: "suiteui-sidebar-action-row-dark", scheme: .dark)
    }

    @Test func aDisabledCommandDrawsFainterThanAnEnabledOne() throws {
        for scheme in [ColorScheme.light, .dark] {
            let enabled = try ink(SidebarActionRow([ActionRowSheet.deletePage(enabled: true)]), scheme)
            let disabled = try ink(SidebarActionRow([ActionRowSheet.deletePage(enabled: false)]), scheme)
            #expect(enabled > 0, "the enabled command drew nothing in \(scheme)")
            #expect(disabled < enabled * 0.8, "disabled \(disabled) vs enabled \(enabled) in \(scheme)")
        }
    }

    @Test func eachButtonIsLabelledByItsTitleAndSaysWhyWhenDisabled() {
        let row = SidebarActionRow(ActionRowSheet.layerActions + [ActionRowSheet.deletePage(enabled: false)])
        #expect(row.commands.map(\.label) == ["New Layer", "Rename Layer…", "Delete Layer", "Delete Page"])
        #expect(row.commands.map(\.identifier) == [
            "suite.gallery.layer.new", "suite.gallery.layer.rename", "suite.gallery.layer.delete",
            "suite.gallery.page.delete",
        ])
        #expect(row.commands.map(\.isEnabled) == [true, true, true, false])
        #expect(row.commands.last?.help == ActionRowSheet.lastPage)
        #expect(row.commands.first?.help == "New Layer")
    }

    @Test func eachIdentifiedButtonRegistersItsIdentifier() throws {
        let store = SuiteControlStore()
        let row = SidebarActionRow(ActionRowSheet.pageActions(canDelete: false))
        _ = try #require(render(row.environment(\.suiteControlStore, store), scheme: .light))
        #expect(store.inventory.document().controls == [
            ControlEntry(id: "suite.gallery.page.add", enabled: true),
            ControlEntry(id: "suite.gallery.page.delete", enabled: false, reason: ActionRowSheet.lastPage),
        ])
        #expect(store.inventory.violations().isEmpty)
    }
}

/// Two sidebar list sections, each with its row of commands under it.
private struct ActionRowSheet: View {
    static let lastPage = "A file keeps at least one page."

    static func deletePage(enabled: Bool) -> ToolbarAction {
        ToolbarAction(
            "Delete Page", systemImage: "trash", unavailableHelp: enabled ? nil : lastPage,
            identifier: "suite.gallery.page.delete")
    }

    static func pageActions(canDelete: Bool) -> [ToolbarAction] {
        [
            ToolbarAction("Add Page", systemImage: "plus", identifier: "suite.gallery.page.add"),
            deletePage(enabled: canDelete),
        ]
    }

    static var layerActions: [ToolbarAction] {
        [
            ToolbarAction("New Layer", systemImage: "plus", identifier: "suite.gallery.layer.new"),
            ToolbarAction("Rename Layer…", systemImage: "pencil", identifier: "suite.gallery.layer.rename"),
            ToolbarAction("Delete Layer", systemImage: "trash", identifier: "suite.gallery.layer.delete"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Pages").font(SuiteFont.headline).foregroundStyle(SuiteColor.secondaryText)
            SidebarRow(SidebarItem(id: "page", title: "Page 1", systemImage: "doc"))
            SidebarActionRow(Self.pageActions(canDelete: false))
            Text("Layers").font(SuiteFont.headline).foregroundStyle(SuiteColor.secondaryText)
            SidebarRow(SidebarItem(id: "title", title: "Title Text", systemImage: "textformat"))
            SidebarRow(SidebarItem(id: "bg", title: "Background", systemImage: "rectangle"))
            SidebarActionRow(Self.layerActions)
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal + SuiteSpacing.xxl)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// How far `view`'s pixels sit from the background, summed over every other pixel.
@MainActor
private func ink(_ view: some View, _ scheme: ColorScheme) throws -> Double {
    let image = try #require(render(view, scheme: scheme))
    let background = try #require(image.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB))
    var total = 0.0
    for y in stride(from: 0, to: image.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: image.pixelsWide, by: 2) {
            guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            total += abs(color.redComponent - background.redComponent)
                + abs(color.greenComponent - background.greenComponent)
                + abs(color.blueComponent - background.blueComponent)
        }
    }
    return total
}
