// ClipCommandsTests.swift (layer-styles LS-11, slice LS-clip, KJ-clip): `layer.clip` and
// `layer.unclip` on a test document. Clip needs a base below (ClipRules), unclip needs a clipped
// selection, and each records exactly one undo step for the whole selection.
import Testing
import SuiteKernel

/// A payload that says whether its layer is clipped to the layer below.
private struct Clip: LayerPayload {
    var holdsChildren = false
    var isClipped = false
}

/// A document with a layer tree, a selection (the last id is the primary) and a history.
private struct ClipDoc: ClipTarget {
    var tree: LayerTree<Clip>
    var selected: [String]
    var history = History<LayerTree<Clip>>()
    var clipSelection: ClipSelection? {
        selected.last.flatMap { ClipCommands.selection(of: $0, in: tree) { $0.isClipped } }
    }
    mutating func setClipped(_ clipped: Bool, name: String) throws {
        history.record(name, tree)
        for id in selected { _ = tree.update(id) { $0.payload.isClipped = clipped } }
    }
    mutating func undo() {
        let now = tree
        var restored = tree
        _ = history.undo { before in restored = before; return now }
        tree = restored
    }
    func clipped(_ id: String) -> Bool { tree.node(id)?.payload.isClipped ?? false }
    static func catalog() throws -> CommandCatalog<ClipDoc> {
        try CommandCatalog(app: "test", ClipCommands.specs(ClipDoc.self)) { $0.history }
    }
}

private func layer(_ id: String, clipped: Bool = false, children: [LayerNode<Clip>] = []) -> LayerNode<Clip> {
    LayerNode(id: id, name: id, children: children, payload: Clip(holdsChildren: !children.isEmpty, isClipped: clipped))
}

@Suite struct ClipCommandsTests {
    /// [A, B, C], back to front.
    private static let stack = LayerTree([layer("A"), layer("B"), layer("C")])

    @Test func clipOnTheBottomLayerIsUnavailableWithNoBaseHelp() throws {
        let catalog = try ClipDoc.catalog()
        var doc = ClipDoc(tree: Self.stack, selected: ["A"])
        #expect(catalog.availability("layer.clip", on: doc).why == ClipRules.noBaseHelp)
        #expect(throws: CatalogError.unavailable(id: "layer.clip", why: ClipRules.noBaseHelp)) {
            try catalog.run("layer.clip", params: .object([:]), on: &doc)
        }
        #expect(doc.history.steps.isEmpty && !doc.clipped("A"))
        let none = ClipDoc(tree: Self.stack, selected: [])
        #expect(catalog.availability("layer.clip", on: none).why == ClipCommands.nothingSelectedHelp)
        #expect(catalog.availability("layer.unclip", on: none).why == ClipCommands.nothingSelectedHelp)
    }

    @Test func clipThenUnclipAreOneStepEach() throws {
        let catalog = try ClipDoc.catalog()
        var doc = ClipDoc(tree: Self.stack, selected: ["B", "C"])
        let clip = try catalog.run("layer.clip", params: .object([:]), on: &doc)
        #expect(clip.undoStep == "Create Clipping Mask")
        #expect(doc.clipped("B") && doc.clipped("C") && !doc.clipped("A"))
        #expect(doc.history.steps == ["Create Clipping Mask"])
        let unclip = try catalog.run("layer.unclip", params: .object([:]), on: &doc)
        #expect(unclip.undoStep == "Release Clipping Mask")
        #expect(!doc.clipped("B") && !doc.clipped("C"))
        #expect(doc.history.steps == ["Create Clipping Mask", "Release Clipping Mask"])
        doc.undo()
        #expect(doc.clipped("B") && doc.clipped("C"))
    }

    @Test func unclipOnAnUnclippedLayerIsUnavailable() throws {
        let catalog = try ClipDoc.catalog()
        var doc = ClipDoc(tree: Self.stack, selected: ["B"])
        #expect(catalog.availability("layer.unclip", on: doc).why == ClipRules.notClippedHelp)
        #expect(throws: CatalogError.self) { try catalog.run("layer.unclip", params: .object([:]), on: &doc) }
        #expect(doc.history.steps.isEmpty)
    }

    @Test func theSelectionUsesClipRulesInsideItsGroup() {
        let tree = LayerTree([layer("A"), layer("G", children: [layer("X"), layer("Y", clipped: true)])])
        let x = ClipCommands.selection(of: "X", in: tree) { $0.isClipped }
        let y = ClipCommands.selection(of: "Y", in: tree) { $0.isClipped }
        let g = ClipCommands.selection(of: "G", in: tree) { $0.isClipped }
        #expect(x?.hasBase == false && x?.isClipped == false)
        #expect(y?.hasBase == true && y?.isClipped == true && y?.id == "Y")
        #expect(g?.hasBase == true)
        #expect(ClipCommands.selection(of: "Z", in: tree) { $0.isClipped } == nil)
    }

    @Test func bothSpecsAreUndoableEditsWithValidExamples() throws {
        let catalog = try ClipDoc.catalog()
        #expect(catalog.ids == ["layer.clip", "layer.unclip"])
        for id in catalog.ids {
            let spec = try #require(catalog.spec(id))
            #expect(spec.undoable && spec.params.validate(spec.example).isEmpty, "\(id)")
        }
    }
}
