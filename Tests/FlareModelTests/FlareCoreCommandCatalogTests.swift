// FlareCoreCommandCatalogTests.swift (adopt-command-catalog AC-f1): every FlareCore command id is a catalog spec over
// FlareWorkspace whose example validates, decodes through CommandRegistry.builtIn and runs through the engine.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareCoreCommandCatalogTests {
    let catalog: CommandCatalog<FlareWorkspace>

    init() throws { catalog = try CommandCatalog(app: "flare", FlareWorkspace.coreCommands, history: FlareCoreHistory.init) }

    func opened() -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .fake())
        workspace.newDocument()
        return workspace
    }

    @Test func everyRegistryIDHasOneSpec() {
        let expected = CommandRegistry.builtIn.ids.map(FlareWorkspace.catalogID).sorted()
        #expect(catalog.ids == expected)
        #expect(FlareWorkspace.coreCommands.count == CommandRegistry.builtIn.ids.count)
        #expect(FlareWorkspace.catalogID("machine.addTransition") == "machine.add-transition")
    }

    @Test func everyExampleValidatesAndDecodesThroughTheRegistry() throws {
        for coreID in CommandRegistry.builtIn.ids {
            let spec = try #require(catalog.spec(FlareWorkspace.catalogID(coreID)), "\(coreID)")
            #expect(spec.params.validate(spec.example) == [], "\(coreID)")
            let envelope = JSONValue.object(["id": .string(coreID), "params": spec.example])
            let command = try CommandRegistry.builtIn.decode(envelope.json())
            #expect(type(of: command).id == coreID)
        }
    }

    @Test func theProbeReadsTheEnumPayloadsItIsGiven() {
        let easing = SchemaProbe.schema(of: FlareCore.Keyframe.self)
        #expect(easing.validate(.object(["frame": .number(2), "value": .number(1),
                                         "easing": .object(["hold": .object([:])])])) == [])
        #expect(SchemaProbe.schema(of: Guide.Axis.self).validate(.string("diagonal")) != [])
    }

    @Test func everyExampleRunsInOrderAndUndoRestoresTheSavedBytes() throws {
        var workspace = opened()
        let saved = try FlareFormat.encode(try #require(workspace.document))
        // FlareCore has not built shape keyframes yet (TrackCommands.notBuilt), so the dry run says that, not a
        // generic refusal a caller can't tell from a bad param (#5283).
        let notBuilt: Set = ["shape-key.set", "shape-key.remove"]
        for spec in FlareWorkspace.coreCommands {
            guard !notBuilt.contains(spec.id) else {
                #expect(catalog.availability(spec.id, on: workspace) == .unavailable("That isn\u{2019}t built in Flare yet."))
                continue
            }
            #expect(catalog.availability(spec.id, on: workspace) == .available, "\(spec.id)")
            let outcome = try catalog.run(spec.id, params: spec.example, on: &workspace)
            #expect(outcome.undoStep == spec.title, "\(spec.id)")
        }
        #expect(try FlareFormat.encode(try #require(workspace.document)) != saved)
        while workspace.canUndo { workspace.undo() }
        #expect(try FlareFormat.encode(try #require(workspace.document)) == saved)
    }

    /// A locked layer-1 says nothing about another layer the params could name, so the id stays available and the run
    /// refuses with the engine's message (#5841).
    @Test func aLockedLayersCommandIsRefusedWithTheEnginesMessage() throws {
        var workspace = opened()
        let locked = "The layer is locked. Unlock it to change it."
        for id in ["layer.add", "layer.set-flags"] {
            let params: JSONValue = id == "layer.add" ? try #require(catalog.spec(id)).example
                : .object(["sceneID": .string("scene-1"), "layerID": .string("layer-1"), "isLocked": .bool(true)])
            _ = try catalog.run(id, params: params, on: &workspace)
        }
        // A locked layer refuses content edits (a rename or flag change still goes through).
        let addShape = try #require(catalog.spec("shape.add"))
        #expect(catalog.availability("shape.add", on: workspace) == .available)
        let before = workspace.document
        #expect(throws: CatalogError.failed(id: "shape.add", message: locked)) {
            try catalog.run("shape.add", params: addShape.example, on: &workspace)
        }
        #expect(workspace.document == before)
    }

    /// PNG frames, SVG and Lottie all draw masks and mattes now (the stage says "Masks not shown"), so the catalog
    /// makes and changes them headless, each as one undo step (#6200).
    @Test func maskAndMatteCommandsRunHeadlessAsOneUndoStepEach() throws {
        var workspace = opened()
        _ = try catalog.run("layer.duplicate", params: try #require(catalog.spec("layer.duplicate")).example, on: &workspace)
        for id in ["mask.add", "mask.set", "mask.set-matte"] {
            let spec = try #require(catalog.spec(id))
            #expect(catalog.availability(id, on: workspace) == .available, "\(id)")
            let outcome = try catalog.run(id, params: spec.example, on: &workspace)
            #expect(outcome.undoStep == spec.title, "\(id)")
        }
        let layer = try #require(workspace.document?.scenes.first?.layers.first { $0.id == "layer-1" })
        #expect(layer.masks.map(\.mode) == [.subtract] && layer.matte?.sourceLayerID == "layer-1-copy")
        workspace.undo()
        #expect(workspace.document?.scenes.first?.layers.first { $0.id == "layer-1" }?.matte == nil)
    }

    @Test func withNoDocumentEveryCommandSaysWhy() {
        let empty = FlareWorkspace(services: .fake())
        let why = FlareLayerError.noDocument.message
        #expect(FlareWorkspace.coreCommands.allSatisfy { $0.availability(empty) == .unavailable(why) })
    }
}
