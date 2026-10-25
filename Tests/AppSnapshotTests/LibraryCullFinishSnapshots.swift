// LibraryCullFinishSnapshots.swift: Delete Rejected Photos… and the named label keys (cull-finish DR-3)
// on the shoot with three rejects, in Light and Dark. Dialogs and menus don't render here, so the confirm
// and items are drawn as columns, help beside each: library-delete-rejects-{confirm,done,none} and
// library-label-keys. "done" keeps 24 photos until DR-6. macOS only.
@testable import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryCullFinishSnapshots {
    /// The shoot under the name sort, with `rejected` (indexes) flagged reject.
    static func shoot(rejected: [Int] = [1, 4, 7]) -> LibraryCatalog {
        var photos = LibraryFixtures.shoot()
        for index in rejected where photos.indices.contains(index) { photos[index].flag = .reject }
        var catalog = LibraryCatalog(services: .fake(photos))
        catalog.load(photos)
        catalog.setSort(.name)
        return catalog
    }

    static func names(_ scheme: ColorScheme) -> String { scheme == .dark ? "dark" : "light" }

    @Test func confirmAsksOnce() throws {
        let catalog = Self.shoot()
        #expect(catalog.deleteRejectsTitle == "Delete 3 Rejected Photos…")
        #expect(catalog.deleteRejectsMessage == "Move 3 rejected photos to the Trash?")
        let item = LibraryCommands.deleteRejectsItem(
            LibraryMenu.Trash(deleteRejects: {}, title: catalog.deleteRejectsTitle, help: nil))
        #expect(item.isEnabled && item.title == "Delete 3 Rejected Photos…")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                ConfirmPage(question: catalog.deleteRejectsMessage, item: item),
                name: "library-delete-rejects-confirm-\(Self.names(scheme))", scheme: scheme)
        }
    }

    @Test func doneShowsTheGrid() throws {
        var catalog = Self.shoot()
        catalog.deleteRejects()
        // DR-6 turns this into 21; on the stubs the photos stay.
        #expect(catalog.items.count >= 21)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                VStack(spacing: 0) {
                    LibraryBrowser(model: catalog).frame(maxWidth: .infinity, maxHeight: .infinity)
                    LibraryStatusBar(model: catalog, fitScale: 1).fixedSize(horizontal: false, vertical: true)
                },
                name: "library-delete-rejects-done-\(Self.names(scheme))", scheme: scheme)
        }
    }

    @Test func noRejectsTurnsTheItemOff() throws {
        let catalog = Self.shoot(rejected: [])
        let help = try #require(catalog.deleteRejectsHelp)
        #expect(help.hasPrefix("No rejected photos in"))
        let item = LibraryCommands.deleteRejectsItem(LibraryMenu.Trash(title: catalog.deleteRejectsTitle, help: help))
        #expect(!item.isEnabled && item.help.hasSuffix(help) && item.title == "Delete Rejected Photos…")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                MenuItemsPage(items: [item]), name: "library-delete-rejects-none-\(Self.names(scheme))", scheme: scheme)
        }
    }

    @Test func labelKeysAreNamed() throws {
        let catalog = Self.shoot()
        let cull = LibraryMenu.Cull(key: { _ in }, setLabel: { _ in })
        let items = LibraryCommands.labelItems(cull, on: catalog, reason: "")
        #expect(items.map(\.title) == ["None"] + PhotoLabel.allCases.map(\.rawValue))
        for (key, label) in LibraryKey.labelKeys {
            let help = items.first { $0.title == label.rawValue }?.help ?? ""
            #expect(help.hasPrefix("\(label.rawValue) (\(key))"), "\(label) reads \(help)")
        }
        #expect(items.last?.help.contains("(") == false, "Purple names a key")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(MenuItemsPage(items: items), name: "library-label-keys-\(Self.names(scheme))", scheme: scheme)
        }
    }
}

/// The confirm as a column (a system dialog doesn't render here), beside the Photo menu item that opens it.
private struct ConfirmPage: View {
    let question: String
    let item: MenuCommand

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            MenuItemsPage.row(item)
            VStack(alignment: .leading, spacing: SuiteSpacing.m) {
                Text(question).font(SuiteFont.headline)
                Text(LibraryTrashArea.detail).font(SuiteFont.body).foregroundStyle(SuiteColor.textSecondary)
                HStack(spacing: SuiteSpacing.m) { LibraryDeleteRejectsButtons(perform: {}) }
            }
            .padding(SuiteSpacing.l)
            .background(SuiteColor.panel)
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Menu items in a column, each with its help (the key it names, or why it is off) beside it.
private struct MenuItemsPage: View {
    let items: [MenuCommand]

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ForEach(Array(items.enumerated()), id: \.offset) { Self.row($0.element) }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    static func row(_ item: MenuCommand) -> some View {
        HStack(spacing: SuiteSpacing.l) {
            item.labelStyle(.titleAndIcon)
            Text(item.help).font(SuiteFont.caption).foregroundStyle(SuiteColor.textSecondary)
        }
    }
}
