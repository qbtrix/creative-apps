// DesignMenuStateTests.swift (AC-d3): the menu items built from catalog specs are on exactly when today's menus are,
// in every workspace state and every menu context (no window, a window, a focused field's own undo). Linux-safe.
@testable import DesignModel
import SuiteKernel
import Testing

struct DesignMenuStateTests {
    /// The ids Design's File, Edit, Page and Object menus show, in menu order.
    static let menuIDs = ["file.new", "file.open", "file.save", "file.save-as", "edit.undo", "edit.redo", "edit.duplicate",
                          "edit.delete", "object.group", "object.ungroup", "page.add", "page.rename", "page.delete"]
        + (DesignArrangeStep.allCases.map(\.title) + DesignAlignEdge.allCases.map(\.title)
            + DesignDistributeAxis.allCases.map(\.title)).map { "object." + DesignWorkspace.slug($0) }

    /// The field contexts: Undo and Redo go to the file, or to a field that can undo, redo, or neither.
    static let fields: [DesignMenuState.FieldUndo?] = [
        nil, .init(canUndo: true, canRedo: false), .init(canUndo: false, canRedo: true), .init(canUndo: false, canRedo: false),
    ]

    /// Today's rule for each menu id (DesignCommands.swift, DesignEditMenu.swift, DesignObjectMenu.swift before AC-d3).
    static func oldEnabled(_ id: String, _ w: DesignWorkspace, window: Bool, field: DesignMenuState.FieldUndo?) -> Bool {
        let editing = w.editingTextID != nil
        if let edge = DesignAlignEdge.allCases.first(where: { id == "object." + DesignWorkspace.slug($0.title) }) {
            return w.alignHelps[edge] == nil
        }
        switch id {
        case "file.new": return true
        case "file.open": return window
        case "file.save", "file.save-as", "page.add": return w.isOpen
        case "edit.undo": return field.map(\.canUndo) ?? (!editing && w.canUndo)
        case "edit.redo": return field.map(\.canRedo) ?? (!editing && w.canRedo)
        case "page.rename": return false
        case "page.delete": return w.canDeletePage
        default: return DesignWorkspace.catalog.availability(id, on: w).why == nil
        }
    }

    @Test func enabledMatchesTodaysMenus() {
        let cases = DesignCommandCatalogTests.states.map { ($0.0, $0.1, true) } + [("no window", DesignWorkspace(), false)]
        for (name, w, window) in cases {
            for field in Self.fields {
                let state = DesignMenuState(workspace: w, hasWindow: window, field: field)
                for id in Self.menuIDs {
                    let spec = DesignMenuState.spec(id)
                    #expect(spec.id == id && spec.title == DesignWorkspace.catalog.spec(id)?.title)
                    #expect(spec.summary == DesignWorkspace.catalog.spec(id)?.summary)
                    #expect((spec.availability(state).why == nil) == Self.oldEnabled(id, w, window: window, field: field),
                            "\(id) in \(name) \(String(describing: field))")
                }
            }
        }
    }

    @Test func offItemsSayWhy() {
        let blank = DesignMenuState(), open = DesignMenuState(workspace: DesignFixtures.cards, hasWindow: true)
        #expect(DesignMenuState.spec("file.open").availability(blank).why == "Open a Design window first.")
        #expect(DesignMenuState.spec("page.rename").availability(blank).why == "Create or open a file first.")
        #expect(DesignMenuState.spec("page.rename").availability(open).why == "Renaming a page from the menu isn't built yet.")
        let typing = DesignMenuState(workspace: DesignFixtures.cards, hasWindow: true, field: .init(canUndo: false, canRedo: false))
        #expect(DesignMenuState.spec("edit.undo").availability(typing).why == "Nothing to undo.")
        #expect(DesignMenuState.spec("edit.redo").availability(typing).why == "Nothing to redo.")
    }

    /// View > Show History drives the window, not the file: on with a window, off with none and saying why.
    @Test func historyNeedsAWindow() {
        let spec = DesignMenuState.spec("view.history")
        #expect(spec.title == "Show History" && DesignWorkspace.catalog.spec("view.history") == nil)
        #expect(spec.availability(DesignMenuState(hasWindow: true)).why == nil)
        #expect(spec.availability(DesignMenuState()).why == "Open a Design window to see its history.")
    }

    @Test func runGoesThroughTheCatalog() throws {
        var state = DesignMenuState(workspace: DesignFixtures.cards, hasWindow: true)
        let pages = state.workspace.pages.count
        let catalog = try CommandCatalog<DesignMenuState>(app: "design", [DesignMenuState.spec("page.add")],
                                                          history: { $0.workspace.history.kernel })
        _ = try catalog.run("page.add", params: .object([:]), on: &state)
        #expect(state.workspace.pages.count == pages + 1)
    }

    @Test func unknownIDIsNeverAvailable() {
        #expect(DesignMenuState.spec("object.teleport").availability(DesignMenuState(hasWindow: true)).why != nil)
    }
}
