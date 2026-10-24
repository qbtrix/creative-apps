// LibraryFoldersSnapshots.swift: the Library window's sidebar with the FOLDERS section (folders FO-3) under
// Collections, Light and Dark, in library-sidebar-folders-{light,dark}.png. Until FO-4 builds the tree from
// the photos, the section shows LibraryFoldersSection.sample (`stubTree`): trips (with 2025 and 2026 inside,
// behind its disclosure), trip and family, each with its count. It also checks the section's rows: one per
// root, `library.folder.<path-hash>` ids, and the context menu's Show Folder and Include Subfolders disabled
// with the stub's reason. macOS only.
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryFoldersSnapshots {
    @Test func sidebarWithFolders() throws {
        let section = try #require(LibraryFoldersSection.section(LibraryFoldersSection.sample))
        #expect(section.title == "Folders")
        #expect(section.items.map(\.id) == LibraryFoldersSection.sample.map { LibraryFolders.rowID(for: $0.path) })
        #expect(section.items.first?.children.map(\.title) == ["2025", "2026"])
        #expect(LibraryFoldersSection.section([])?.id == nil, "an empty tree drew an empty header")
        let actions = LibraryFoldersSection.actions(help: "Folders arrive with FO-4.")
        #expect(actions.map(\.title) == ["Show Folder", "Include Subfolders"])
        #expect(actions.allSatisfy { !$0.isEnabled && $0.help == "Folders arrive with FO-4." })

        LibraryFoldersSection.stubTree = LibraryFoldersSection.sample
        defer { LibraryFoldersSection.stubTree = nil }
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"]),
                name: "library-sidebar-folders-\(scheme.name)", scheme: scheme)
        }
    }
}
