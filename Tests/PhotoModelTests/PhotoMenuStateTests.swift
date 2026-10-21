// PhotoMenuStateTests.swift (AC-p3): the menu items built from catalog specs are on exactly when today's menus are,
// in every workspace state and every menu context (no window, a sheet up, text focused, the pasteboard's contents).
import SuiteKernel
import Testing
@testable import PhotoModel

struct PhotoMenuStateTests {
    /// The contexts a menu builds in: hasWindow, isPresenting, textFocused, pasteboard has an image, pasteboard is empty.
    static let contexts: [(Bool, Bool, Bool, Bool, Bool)] = [
        (true, false, false, false, true), (true, false, false, true, false), (true, false, false, false, false),
        (true, true, false, false, true), (true, false, true, false, true), (false, false, false, false, true),
        (false, false, true, true, false), (true, true, true, true, false),
    ]

    /// Today's rule for each menu id (PhotoCommands*.swift before AC-p3): on or off.
    static func oldEnabled(_ id: String, _ ws: PhotoWorkspace, _ c: (Bool, Bool, Bool, Bool, Bool)) -> Bool {
        let (window, presenting, text, pasteImage, _) = c, image = ws.canvas != nil
        switch id {
        case "edit.cut", "edit.copy": return text || presenting || (window && image)
        case "edit.paste": return text || presenting || (window && pasteImage)
        case "edit.select-all": return (image && !presenting) || text
        case "select.all": return window ? image : true
        default: return PhotoWorkspace.catalog.availability(id, on: ws).why == nil
        }
    }

    @Test func enabledMatchesTodaysMenus() throws {
        for (name, ws) in try PhotoCommandCatalogTests.states() {
            for c in Self.contexts {
                let state = PhotoMenuState(workspace: ws, hasWindow: c.0, isPresenting: c.1, textFocused: c.2,
                                           pasteboardHasImage: c.3, pasteboardIsEmpty: c.4)
                for id in PhotoCommandCatalogTests.menuIDs {
                    let spec = PhotoMenuState.spec(id)
                    #expect(spec.id == id && spec.summary == PhotoWorkspace.menuSummary(id))
                    #expect((spec.availability(state).why == nil) == Self.oldEnabled(id, ws, c), "\(id) in \(name) \(c)")
                    #expect(state.title(id) == ws.menuTitle(id))
                }
            }
        }
    }

    @Test func disabledPasteSaysWhy() {
        let empty = PhotoMenuState(hasWindow: true), text = PhotoMenuState(hasWindow: true, pasteboardIsEmpty: false)
        #expect(PhotoMenuState.spec("edit.paste").availability(empty).why == "Nothing to paste.")
        #expect(PhotoMenuState.spec("edit.paste").availability(text).why == "The pasteboard has no image.")
        #expect(PhotoMenuState.spec("edit.copy").availability(PhotoMenuState()).why == "Open an image first.")
    }

    @Test func runGoesThroughTheCatalog() throws {
        var state = PhotoMenuState(workspace: try PhotoCommandCatalogTests.lawsFixture(), hasWindow: true)
        let layers = state.workspace.layers.count
        let catalog = try CommandCatalog<PhotoMenuState>(app: "photo", [PhotoMenuState.spec("layer.new")],
                                                         history: { $0.workspace.history.kernel })
        _ = try catalog.run("layer.new", params: .object([:]), on: &state)
        #expect(state.workspace.layers.count == layers + 1)
    }

    /// An enabled item's tooltip is its menu summary: what clicking does, never the agent call's params
    /// (Open's RGBA bytes, Save's "marks saved", a sheet's "given size").
    @Test func tooltipsSayWhatTheItemDoes() {
        #expect(PhotoMenuState.spec("file.open").summary == "Opens an image file.")
        #expect(PhotoMenuState.spec("file.save").summary == "Saves the image to its file.")
        for id in PhotoCommandCatalogTests.menuIDs {
            let summary = PhotoMenuState.spec(id).summary
            for agentOnly in ["bytes", "given", "Marks", "of a kind", "png or jpeg", "by an angle"] {
                #expect(!summary.contains(agentOnly), "\(id): \(summary)")
            }
        }
    }

    @Test func unknownIDIsNeverAvailable() {
        #expect(PhotoMenuState.spec("layer.teleport").availability(PhotoMenuState(hasWindow: true)).why != nil)
    }
}
