// PhotoEditMenuTests.swift: Photo's Edit > Cut, Copy and Paste (photo-edit
// E-7). With no image Copy is disabled with "Open an image first."; an empty
// pasteboard disables Paste with "Nothing to paste."; Command-C in the Image
// Size sheet's field and in a focused panel text field copies the text, never
// the image; with no text focused Copy acts on the image. Every Edit item has
// the system's symbol, Select All follows Paste, Merge Down's symbol is not a
// save glyph, and with no window or no image on the pasteboard the items are
// off with a reason unless text has focus. A spy text view
// stands in for the field editor, so the general pasteboard is never touched.
// macOS only.
import AppKit
import PhotoModel
import Testing

@testable import PhotoApp

/// A field editor that records the text commands it receives.
private final class TextSpy: NSTextView {
    var received: [String] = []
    override func copy(_ sender: Any?) { received.append("copy") }
    override func cut(_ sender: Any?) { received.append("cut") }
    override func paste(_ sender: Any?) { received.append("paste") }
}

@MainActor
@Suite struct PhotoEditMenuTests {
    private let empty = PhotoPasteboardState()

    /// Whether `intents` asked the window for an image edit.
    private func editsImage(_ intents: [PhotoIntent]) -> Bool {
        intents.contains { if case .edit = $0 { true } else { false } }
    }

    @Test func copyIsDisabledWithItsReasonWithNoImage() {
        let menu = PhotoMenu(model: PhotoWorkspace(), perform: { _ in })
        #expect(menu.isEditDisabled(.copy, pasteboard: empty) && menu.isEditDisabled(.cut, pasteboard: empty))
        #expect(menu.editHelp(.copy, pasteboard: empty) == "Open an image first.")
        #expect(menu.editHelp(.cut, pasteboard: empty) == "Open an image first.")
    }

    @Test func pasteIsDisabledWithItsReasonWithAnEmptyPasteboard() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        let menu = PhotoMenu(model: model, perform: { _ in })
        #expect(menu.isEditDisabled(.paste, pasteboard: empty))
        #expect(menu.editHelp(.paste, pasteboard: empty) == "Nothing to paste.")
        let image = PhotoPasteboardState(hasImage: true, isEmpty: false)
        #expect(!menu.isEditDisabled(.paste, pasteboard: image))
        #expect(!menu.isEditDisabled(.copy, pasteboard: image))
    }

    @Test func commandCInTheImageSizeSheetsFieldCopiesText() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        var sent: [PhotoIntent] = []
        let resizing = PhotoMenu(model: model, isPresenting: true, perform: { sent.append($0) })
        let field = TextSpy()
        resizing.edit(.copy, focusedText: field)
        #expect(field.received == ["copy"] && !editsImage(sent))
        #expect(!resizing.isEditDisabled(.copy, pasteboard: empty) && !resizing.isEditDisabled(.paste, pasteboard: empty))
    }

    @Test func commandCInAFocusedPanelFieldCopiesText() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        var sent: [PhotoIntent] = []
        let menu = PhotoMenu(model: model, perform: { sent.append($0) })
        let field = TextSpy()
        menu.edit(.copy, focusedText: field)
        menu.edit(.paste, focusedText: field)
        #expect(field.received == ["copy", "paste"] && !editsImage(sent))
    }

    @Test func everyEditItemHasTheSystemsSymbol() {
        #expect(PhotoEditItem.allCases.allSatisfy { !$0.systemImage.isEmpty })
        #expect(PhotoEditItem.cut.systemImage == "scissors")
        #expect(PhotoEditItem.copy.systemImage == "document.on.document")
        #expect(PhotoEditItem.paste.systemImage == "document.on.clipboard")
        #expect(PhotoEditItem.undo.systemImage == "arrow.uturn.backward")
        #expect(PhotoEditItem.redo.systemImage == "arrow.uturn.forward")
    }

    @Test func selectAllFollowsPasteInThePasteboardGroup() {
        #expect(PhotoEditItem.pasteboardGroup == [.cut, .copy, .paste, .selectAll])
    }

    @Test func mergeDownIsNotASaveSymbol() {
        for intent in [EditIntent.duplicateLayer, .mergeDown, .flattenImage] {
            #expect(!PhotoLayerMenu.systemImage(intent).hasPrefix("square.and.arrow"))
        }
        #expect(PhotoLayerMenu.systemImage(.mergeDown) != "square.2.layers.3d.bottom.filled")
    }

    @Test func cutCopyPasteAreDisabledWithTheirReasonsWithNoWindow() {
        let menu = PhotoMenu()
        for intent in [EditIntent.cut, .copy, .paste] {
            #expect(menu.isEditDisabled(intent, pasteboard: empty))
            #expect(menu.editHelp(intent, pasteboard: empty) != nil)
            #expect(!menu.isEditDisabled(intent, pasteboard: empty, textHasFocus: true))
        }
    }

    @Test func pasteIsDisabledWhenThePasteboardHoldsNoImage() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        let menu = PhotoMenu(model: model, perform: { _ in })
        let text = PhotoPasteboardState(hasImage: false, isEmpty: false)
        #expect(menu.isEditDisabled(.paste, pasteboard: text))
        #expect(menu.editHelp(.paste, pasteboard: text) == "The pasteboard has no image.")
        // A focused text field still gets Command-V.
        #expect(!menu.isEditDisabled(.paste, pasteboard: text, textHasFocus: true))
    }

    @Test func copyActsOnTheImageWithNoTextFocused() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        var sent: [PhotoIntent] = []
        let menu = PhotoMenu(model: model, perform: { sent.append($0) })
        menu.edit(.copy, focusedText: nil)
        #expect(sent.count == 1 && editsImage(sent))
    }
}
