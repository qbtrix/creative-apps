// CopyAsMenuTests.swift (clipboard-interop CB-u1): CopyAsMenu builds Edit > Copy As and Paste as Image from
// CopyAsCommands' specs through MenuCommand+Catalog. Copy As has three items, PNG, SVG and the app's own type, in
// that order, each running `edit.copy-as` with its format; with no selection each is off and says why. With text on
// the gallery's fake pasteboard Paste as Image is off and its help is the coder's sentence
// (`SuitePasteboardCoding.pasteRefusal`); once a PNG is copied it is on. Checked over the gallery's fake document,
// whatever the coder's body says, so the test stays honest on the stubs. macOS only.
import Foundation
import SuiteKernel
import SuiteModel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct CopyAsMenuTests {
    private let text = [TypedData(type: .plainText, data: Data("hello".utf8))]

    private func menu(_ doc: GalleryClipDocument, copied: @escaping @MainActor (CopyAsFormat) -> Void = { _ in },
                      pasted: @escaping @MainActor () -> Void = {}) -> CopyAsMenu<GalleryClipDocument> {
        CopyAsMenu(on: doc, ownTitle: "Gallery Layers", copy: copied, pasteAsImage: pasted)
    }

    @Test func threeCopyAsItemsInOrderEachWithItsCommand() {
        var ran: [CopyAsFormat] = []
        let items = menu(GalleryClipDocument(), copied: { ran.append($0) }).copyItems
        #expect(items.map(\.format) == [.png, .svg, .own])
        #expect(items.map(\.command.title) == ["PNG", "SVG", "Gallery Layers"])
        #expect(items.map(\.commandID) == ["edit.copy-as", "edit.copy-as", "edit.copy-as"])
        #expect(items.map(\.id) == ["edit.copy-as.png", "edit.copy-as.svg", "edit.copy-as.own"])
        let allEnabled = items.allSatisfy { $0.command.isEnabled }
        #expect(allEnabled)
        for item in items { item.command.perform() }
        #expect(ran == [.png, .svg, .own])
    }

    @Test func noSelectionTurnsEachCopyOffWithWhy() {
        for item in menu(GalleryClipDocument(selected: false)).copyItems {
            #expect(!item.command.isEnabled, "\(item.id) is on with nothing selected")
            #expect(item.command.help == "\(item.command.title): \(GalleryClipDocument.noSelection)")
        }
    }

    @Test func textOnTheFakePasteboardTurnsPasteAsImageOffWithTheCodersSentence() throws {
        let why = try #require(SuitePasteboardCoding().pasteRefusal(for: text, in: GalleryClipDocument.app))
        let paste = try #require(menu(GalleryClipDocument(offered: text)).pasteItem)
        #expect(paste.commandID == "edit.paste-as-image" && paste.format == nil)
        #expect(paste.command.title == "Paste as Image" && !paste.command.isEnabled)
        #expect(paste.command.help == "Paste as Image: \(why.message)")
    }

    @Test func aCopiedPngTurnsPasteAsImageOn() throws {
        var doc = GalleryClipDocument(offered: text)
        doc.copy(.png)
        #expect(doc.offered.map(\.type) == [.png])
        var pasted = 0
        let paste = try #require(menu(doc, pasted: { pasted += 1 }).pasteItem)
        #expect(paste.command.isEnabled && paste.command.help.hasPrefix("Pastes an image"))
        paste.command.perform()
        #expect(pasted == 1)
    }
}
