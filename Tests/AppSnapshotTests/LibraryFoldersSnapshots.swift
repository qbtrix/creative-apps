// LibraryFoldersSnapshots.swift: the Library window's sidebar with the FOLDERS section (folders FO-3) under
// Collections, Light and Dark, in library-sidebar-folders-{light,dark}.png. The `folders` fixture's photos build
// the tree: family (every file missing, so dimmed with the missing badge), trip, and trips (2025 and 2026 behind
// its disclosure), each with its count. It also checks the section's rows: one per root,
// `library.folder.<path-hash>` ids, the missing badge only on family, and the context menu's Show Folder and
// Include Subfolders disabled with a reason while they can't run. macOS only.
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryFoldersSnapshots {
    @Test func sidebarWithFolders() throws {
        let tree = LibraryFolders.tree(LibraryFixtures.photos(named: "folders"))
        let section = try #require(LibraryFoldersSection.section(tree))
        #expect(section.title == "Folders")
        #expect(section.items.map(\.id) == tree.map { LibraryFolders.rowID(for: $0.path) })
        #expect(section.items.last?.children.map(\.title) == ["2025", "2026"])
        #expect(section.items.map { $0.notice != nil } == [true, false, false], "only family is all missing")
        #expect(section.items.first?.isDimmed == true)
        #expect(LibraryFoldersSection.section([])?.id == nil, "an empty tree drew an empty header")
        let actions = LibraryFoldersSection.actions(help: LibraryCatalog.noFolders)
        #expect(actions.map(\.title) == ["Show Folder", "Include Subfolders"])
        #expect(actions.allSatisfy { !$0.isEnabled && $0.help == LibraryCatalog.noFolders })

        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryWindow(arguments: ["Library", "-LibraryFixture", "folders"]),
                name: "library-sidebar-folders-\(scheme.name)", scheme: scheme)
        }
    }
}
