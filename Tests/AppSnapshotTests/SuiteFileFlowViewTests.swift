// SuiteFileFlowViewTests.swift: file-flow SF-3 (packet suite/features/file-flow.md). What the File menu's
// Open Recent ▸ and Open In ▸ show and what the drop mark says: an empty list shows "No Recent Files"
// disabled; Open In with no readers is off with its sentence; the mark shows the first action's sentence.
// macOS only.
#if os(macOS)
import Foundation
import SuiteKernel
import SuiteModel
import Testing

@testable import SuiteShell

private func ref(_ name: String, _ app: SuiteApp, _ type: SuiteTypeID) -> SuiteDocumentRef {
    let path = "/tmp/FileFlowViewTests/\(name)"
    return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app, type: type,
                            displayName: name)
}

@MainActor struct SuiteFileFlowViewTests {
    @Test func anEmptyListShowsNoRecentFilesDisabled() {
        let menu = SuiteFileMenu(app: .design, bridge: SuiteDocumentsBridge(app: .design, services: .fake()))
        #expect(menu.recents.isEmpty)
        #expect(menu.recentsEmpty)
        #expect(SuiteFileMenu.noRecentFiles == "No Recent Files")
    }

    @Test func openInWithNoDocumentIsOffWithItsSentence() {
        let menu = SuiteFileMenu(app: .design, bridge: SuiteDocumentsBridge(app: .design, services: .fake()))
        #expect(menu.openInTargets.isEmpty)
        #expect(menu.openInHelp == "Open a document first.")
    }

    @Test func openInWithNoOtherReaderIsOffWithItsSentence() {
        let bridge = SuiteDocumentsBridge(app: .design, services: .fake())
        let menu = SuiteFileMenu(app: .design, bridge: bridge, document: ref("Poster.design", .design, .designDocument))
        #expect(menu.openInTargets.isEmpty)
        #expect(menu.openInHelp == "No other app opens Design Document files.")
    }

    @Test func openInWithReadersListsThemAndIsOn() {
        let bridge = SuiteDocumentsBridge(app: .photo, services: .fake())
        let menu = SuiteFileMenu(app: .photo, bridge: bridge, document: ref("Sunset.png", .photo, .png))
        #expect(menu.openInTargets == [.library])
        #expect(menu.openInHelp == nil)
    }

    @Test func theMarkShowsTheFirstActionsSentence() {
        let halo: [DropAction] = [.handOff(path: "/x/Intro.halo", app: "halo"), .refuse(path: "/x/a.xyz", reason: "no")]
        #expect(SuiteDropMark.sentence(for: halo, app: .launcher) == "Open in Halo")
        #expect(SuiteDropMark.sentence(for: [.open(path: "/x/Poster.design")], app: .design) == "Open in Design")
        #expect(SuiteDropMark.sentence(for: [.place(path: "/x/Sunset.png")], app: .photo, documentName: "Sunset")
                == "Place in Sunset")
        let xyz: [DropAction] = [.refuse(path: "/x/notes.xyz", reason: "AfterGlow can't open .xyz files.")]
        #expect(SuiteDropMark.sentence(for: xyz, app: .launcher) == "AfterGlow can't open .xyz files.")
        #expect(SuiteDropMark.sentence(for: [], app: .launcher) == nil)
    }

    @Test func theMarkSaysWhetherTheDropIsRefused() {
        #expect(SuiteDropMark.refuses([.refuse(path: "/x/notes.xyz", reason: "r")]))
        #expect(!SuiteDropMark.refuses([.handOff(path: "/x/Intro.halo", app: "halo")]))
        #expect(SuiteFileControlID.dropMark == "suite.file.drop-mark")
        #expect(SuiteFileControlID.openRecent.hasPrefix("suite.file."))
        #expect(SuiteFileControlID.openIn.hasPrefix("suite.file."))
    }
}
#endif
