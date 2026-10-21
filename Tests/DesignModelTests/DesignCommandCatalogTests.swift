// DesignCommandCatalogTests.swift (adopt-command-catalog AC-d1): Design's catalog keeps the catalog's laws on
// Design's states, keeps its ledger, and each command's availability is the help the window shows today.
// Fails when a reason changes, an edit records no step, or an id is missing. Linux-safe.
@testable import DesignModel
import SuiteKernel
import Foundation
import Testing

/// The workspace as a headless document, so CatalogConformance can walk Design's catalog on any state:
/// each spec runs through `DesignWorkspace.catalog`, and save() is the file's bytes.
struct DesignCatalogDoc: HeadlessDocument {
    var workspace: DesignWorkspace
    static let app = "design", openExtensions = ["design"], exportFormats: [String] = []
    static let catalog: CommandCatalog<DesignCatalogDoc> =
        (try? CommandCatalog(app: app, DesignWorkspace.commands.map(lift), history: { $0.workspace.history.kernel })) ?? .empty(app: app)
    static func lift(_ spec: CommandSpec<DesignWorkspace>) -> CommandSpec<DesignCatalogDoc> {
        .typed(spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
               result: spec.result, example: spec.example, availability: { spec.availability($0.workspace) }
        ) { doc, params in try DesignWorkspace.catalog.run(spec.id, params: params, on: &doc.workspace).result }
    }
    static func open(_ data: Data, name: String) throws -> Self { var w = DesignWorkspace(); try w.open(data); return Self(workspace: w) }
    static func new(_ options: JSONValue) throws -> Self { Self(workspace: DesignFixtures.empty) }
    func save() throws -> Data { try workspace.fileData() }
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [] }
    func summary() -> JSONValue { .object([:]) }
}

@Suite struct DesignCommandCatalogTests {
    /// Design's states: no file, nothing selected, one layer, a locked and a hidden layer, a group, several layers,
    /// two pages, an edit to undo, an undone edit, mid-drag and mid text edit.
    static var states: [(String, DesignWorkspace)] {
        let cards = DesignFixtures.cards
        func with(_ base: DesignWorkspace = cards, _ change: (inout DesignWorkspace) -> Void) -> DesignWorkspace {
            var w = base; change(&w); return w
        }
        let one = with { $0.selectItem("node-2") }
        let nudged = with(one) { $0.nudge(.right, shift: false) }
        return [
            ("no file", DesignWorkspace()), ("nothing selected", cards), ("one layer", one),
            ("locked layer", with { $0.selectItem("node-9") }), ("hidden layer", with { $0.selectItem("node-10") }),
            ("group", with { $0.selectItem("node-6") }),
            ("several", with(one) { $0.toggleSelection("node-3"); $0.toggleSelection("node-4") }),
            ("two pages", DesignFixtures.twoPages), ("edited", nudged), ("undone", with(nudged) { $0.undo() }),
            ("mid-drag", with(one) { $0.drag(from: pt(150, 140), to: pt(170, 150)) }),
            ("editing text", with { try? $0.beginTextEdit("node-5") }),
        ]
    }

    /// The help each id showed before the catalog: the selection commands' `help(_:)`, the toolbar's, the pages'
    /// and the palette's. The three rules the window had no help for are spelled out.
    static func oldHelp(_ id: String, _ w: DesignWorkspace) -> String?? {
        let commands: [DesignCommand] = [.duplicate, .delete, .group, .ungroup, .nudge(.right, large: false)]
            + DesignArrangeStep.allCases.map { .arrange($0) } + DesignAlignEdge.allCases.map { .align($0) }
            + DesignDistributeAxis.allCases.map { .distribute($0) }
        let ids = ["edit.duplicate", "edit.delete", "object.group", "object.ungroup", "object.nudge"]
            + (DesignArrangeStep.allCases.map(\.title) + DesignAlignEdge.allCases.map(\.title)
                + DesignDistributeAxis.allCases.map(\.title)).map { "object." + $0.lowercased().split(separator: " ").joined(separator: "-") }
        if let index = ids.firstIndex(of: id), commands.indices.contains(index) { return .some(w.help(commands[index])) }
        if let tool = DesignTool.allCases.first(where: { "tool.\($0.rawValue)" == id }) { return .some(tool.unavailableHelp) }
        let noPage = w.selectedPage == nil ? "Create or open a file first."
            : w.editingTextID == nil ? nil : "Finish editing the text first."
        return switch id {
        case "edit.undo": .some(DesignToolbarItem.undo.unavailableHelp(in: w))
        case "edit.redo": .some(DesignToolbarItem.redo.unavailableHelp(in: w))
        case "file.new": .some(DesignToolbarItem.newFile.unavailableHelp(in: w))
        case "file.save", "file.save-as": .some(DesignToolbarItem.save.unavailableHelp(in: w))
        case "file.open": .some(w.takesOpenedFile ? nil : "This window holds a file; open it in a new one.")
        case "page.add", "page.select", "edit.select", "edit.select-all": .some(w.addPageHelp)
        case "page.delete": .some(w.deletePageHelp)
        case "page.rename": .some(noPage)
        default: nil
        }
    }

    @Test func availabilityMatchesHelp() {
        for id in DesignWorkspace.catalog.ids {
            #expect(Self.oldHelp(id, DesignWorkspace()) != nil, "\(id) has no old help to match")
            for (state, w) in Self.states {
                let old = Self.oldHelp(id, w) ?? nil
                #expect(DesignWorkspace.catalog.availability(id, on: w).why == old, "\(id) on \(state)")
            }
        }
    }

    /// help(_:) for a one-layer command: a locked layer's delete and nudge and a hidden layer's nudge stay off.
    @Test func oneLayerHelpKept() {
        let states = Dictionary(uniqueKeysWithValues: Self.states)
        let locked = states["locked layer"] ?? DesignWorkspace(), hidden = states["hidden layer"] ?? DesignWorkspace()
        #expect(DesignWorkspace.catalog.availability("edit.delete", on: locked).why == locked.help(.delete))
        #expect(DesignWorkspace.catalog.availability("object.nudge", on: locked).why != nil)
        #expect(DesignWorkspace.catalog.availability("object.nudge", on: hidden).why == hidden.help(.nudge(.up, large: false)))
        #expect(DesignWorkspace.catalog.availability("object.align-left", on: locked).why == locked.help(.align(.left)))
    }

    /// object.nudge moves 1 pt, and 10 pt with `large`, for one layer and for several.
    @Test func nudgeLarge() throws {
        let states = Dictionary(uniqueKeysWithValues: Self.states)
        for (state, x) in [("one layer", 100.0), ("several", 100.0)] {
            for (large, step) in [(false, 1.0), (true, 10.0)] {
                var w = states[state] ?? DesignWorkspace()
                let params = JSONValue.object(["direction": .string("right"), "large": .bool(large)])
                let outcome = try DesignWorkspace.catalog.run("object.nudge", params: params, on: &w)
                #expect(w.frame("node-2")?.x == x + step, "\(state) large \(large)")
                #expect(outcome.undoStep == "Nudge")
            }
        }
    }

    /// Every spec keeps the catalog's laws on each open state where it can run (mid-drag is an availability state
    /// only: today's run refuses there); each id that is built runs on at least one state.
    @Test func conformsOnDesignStates() {
        var ran = Set<String>()
        for (state, w) in Self.states where w.isOpen && state != "mid-drag" {
            let doc = DesignCatalogDoc(workspace: w)
            let problems = CatalogConformance.check(DesignCatalogDoc.self, fixture: doc).filter { problem in
                let id = String(problem.prefix { $0 != ":" })
                let off = DesignCatalogDoc.catalog.availability(id, on: doc).why != nil
                // As today: an edit that would change nothing refuses though its help is clear (layers already spaced).
                let noChange = problem.contains("exampleRuns") && problem.hasSuffix("failed: unchanged")
                // A one-layer delete names its step after the layer's kind ("Delete Rectangle"), as it did before.
                let named = id == "edit.delete" && w.selectedNodeIDs.count == 1 && problem.contains("stepNamedTitle")
                // A nudge right after a nudge joins its step, as the arrow keys do.
                let joined = id == "object.nudge" && state == "edited"
                return !(off && problem.contains("exampleRuns")) && !noChange && !named && !joined
            }
            #expect(problems.isEmpty, "\(state): \(problems.joined(separator: "\n"))")
            ran.formUnion(DesignCatalogDoc.catalog.ids.filter { DesignCatalogDoc.catalog.availability($0, on: doc).why == nil })
        }
        let empty = DesignWorkspace()
        ran.formUnion(DesignWorkspace.catalog.ids.filter {
            let why = DesignWorkspace.catalog.availability($0, on: empty).why
            return why == nil || why?.hasSuffix("isn't built yet.") == true
        })
        #expect(Set(DesignWorkspace.catalog.ids).subtracting(ran).isEmpty, "never available: \(Set(DesignWorkspace.catalog.ids).subtracting(ran))")
    }

    /// Opening a saved file's text in an empty window gives back the same file; Save marks it saved.
    @Test func fileRoundTrip() throws {
        var w = DesignFixtures.cards
        w.nudge(.right, shift: false)
        let saved = try DesignWorkspace.catalog.run("file.save", params: .object([:]), on: &w).result
        #expect(!w.isDirty)
        guard case .object(let result) = saved, let text = result["text"] else { Issue.record("no text"); return }
        var opened = DesignWorkspace()
        _ = try DesignWorkspace.catalog.run("file.open", params: .object(["text": text]), on: &opened)
        #expect(try opened.fileData() == w.fileData())
    }

    @Test func idsKeepTheLedger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/design.txt")
        let ledger = try String(contentsOf: url, encoding: .utf8)
        #expect(CommandIDLedger.check(DesignWorkspace.catalog.ids, ledger: ledger) == [])
        let listed = ledger.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty && !$0.hasPrefix("#") }
        #expect(listed.sorted() == DesignWorkspace.catalog.ids, "the ledger lists exactly the catalog's ids")
    }

    /// Today's menu table with one layer selected: each id's title and why it is off ("on" when it can run).
    @Test func menusUnchanged() {
        let one = Dictionary(uniqueKeysWithValues: Self.states)["one layer"] ?? DesignWorkspace()
        let table = DesignWorkspace.commands.map { "\($0.id) | \($0.title) | \($0.availability(one).why ?? "on")" }
        #expect(table == Self.golden, "\(table.joined(separator: "\n"))")
    }

    static let golden = [
        "file.new | New File | on", "file.open | Open… | This window holds a file; open it in a new one.",
        "file.save | Save | on", "file.save-as | Save As… | on",
        "edit.undo | Undo | Nothing to undo.", "edit.redo | Redo | Nothing to redo.",
        "edit.select | Select | on", "edit.select-all | Select All | on",
        "edit.duplicate | Duplicate | on", "edit.delete | Delete | on",
        "object.group | Group | on", "object.ungroup | Ungroup | A isn't a group.",
        "object.bring-to-front | Bring to Front | on", "object.bring-forward | Bring Forward | on",
        "object.send-backward | Send Backward | Nothing would change.", "object.send-to-back | Send to Back | Nothing would change.",
        "object.align-left | Align Left | on", "object.align-center | Align Center | on", "object.align-right | Align Right | on",
        "object.align-top | Align Top | on", "object.align-middle | Align Middle | on", "object.align-bottom | Align Bottom | on",
        "object.distribute-horizontally | Distribute Horizontally | Select three or more layers to distribute.",
        "object.distribute-vertically | Distribute Vertically | Select three or more layers to distribute.",
        "object.nudge | Nudge | on",
        "page.add | Add Page | on", "page.rename | Rename Page | on",
        "page.delete | Delete Page | A file keeps at least one page.", "page.select | Select Page | on",
        "tool.move | Move | on", "tool.frame | Frame | on", "tool.rectangle | Rectangle | on",
        "tool.ellipse | Ellipse | on", "tool.text | Text | on", "tool.pen | Pen | Drawing paths isn't built yet.",
        "tool.eyedropper | Eyedropper | Picking a color from the canvas isn't built yet.",
    ]
}
