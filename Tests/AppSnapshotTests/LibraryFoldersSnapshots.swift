// LibraryFoldersSnapshots.swift: the Library window's sidebar with the FOLDERS section (folders FO-3) under
// Collections, Light and Dark, in library-sidebar-folders-{light,dark}.png, on the `folders` fixture's real tree:
// fixture/Photos with family (every file missing: dimmed, with the missing badge), trip and trips (2025 and 2026
// inside), each with its count. It also checks the section's rows: one per root, `library.folder.<path-hash>`
// ids, the missing badge's text on family alone, and the context menu's Show Folder and Include Subfolders
// disabled with a reason. macOS only.
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
        let photos = try #require(section.items.first)
        #expect(photos.children.map(\.title) == ["family", "trip", "trips"])
        #expect(photos.secondLevelRows.map(\.title) == ["family", "trip", "trips", "2025", "2026"])
        #expect(photos.secondLevelRows.compactMap(\.warning) == ["All 4 photos in this folder are missing from disk."])
        #expect(photos.secondLevelRows.first?.isDimmed == true)
        #expect(LibraryFoldersSection.section([])?.id == nil, "an empty tree drew an empty header")
        let actions = LibraryFoldersSection.actions(help: "Import a folder to see its folders.")
        #expect(actions.map(\.title) == ["Show Folder", "Include Subfolders"])
        #expect(actions.allSatisfy { !$0.isEnabled && $0.help == "Import a folder to see its folders." })

        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryWindow(arguments: ["Library", "-LibraryFixture", "folders"]),
                name: "library-sidebar-folders-\(scheme.name)", scheme: scheme)
        }
    }
}
