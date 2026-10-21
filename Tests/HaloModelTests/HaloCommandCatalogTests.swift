// HaloCommandCatalogTests.swift (adopt-command-catalog AC-h1): one spec per `HaloCommand` case, availability is `unavailableHelp(for:)`
// on the `keyed` states, runs do what the routes do, ids keep the ledger, conformance holds but for the gaps in `exempt`.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

/// The conformance suite runs over `HaloProject`; files stay with `HaloHeadless` (AC-h2).
extension HaloProject: HeadlessDocument {
    public static var app: String { "halo" }; public static var openExtensions: [String] { [] }; public static var exportFormats: [String] { [] }
    public static func open(_ data: Data, name: String) throws -> HaloProject { throw CatalogError.notBuilt(id: "open", feature: "AC-h2") }
    public static func new(_ options: JSONValue) throws -> HaloProject { HaloProject(services: .fake) }
    public func save() throws -> Data { try fileData() }
    public func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [] }; public func summary() -> JSONValue { .object([:]) }
}

@Suite struct HaloCommandCatalogTests {
    let catalog = HaloProject.catalog

    /// `keyed` with Ball, the top layer, selected.
    static func ballSelected() -> HaloProject { var project = commandProject("keyed", .fake); project.selectLayer("comp-1-layer-2"); return project }

    /// No project, no layer, the top layer, the bottom one, after an edit, and with a picked key.
    static func keyedStates() -> [HaloProject] {
        var floor = ballSelected(), edited = ballSelected(), picked = ballSelected()
        floor.selectLayer("comp-1-layer-1")
        edited.newLayer(.text)
        picked.selectKey(HaloKeyRef(layerID: "comp-1-layer-2", property: .x, frame: 0), extending: false)
        return [HaloProject(services: .fake), commandProject("keyed", .fake), ballSelected(), floor, edited, picked]
    }

    @Test func oneSpecPerCase() {
        let ids = HaloCommand.allCases.map(\.commandID)
        #expect(ids.count == 62 && Set(ids).count == ids.count)
        #expect(catalog.ids == ids.sorted() && HaloProject.commandSpecs.map(\.id) == ids)
    }

    @Test func areaHelpMatches() {
        for (n, state) in Self.keyedStates().enumerated() {
            for command in HaloCommand.allCases {
                let why = catalog.availability(command.commandID, on: state).why
                #expect(why == state.unavailableHelp(for: command), "\(command.commandID) on state \(n)")
            }
        }
    }

    @Test func scrubIsView() throws {
        #expect(catalog.spec("timeline.scrub")?.kind == .view)
        var project = Self.ballSelected()
        let outcome = try catalog.run("timeline.scrub", params: .object(["frame": .number(12)]), on: &project)
        #expect(outcome.undoStep == nil && project.history.undo.isEmpty)
        #expect(project.selectedComposition?.playheadFrame == 12)
    }

    @Test func runsWhatTheRouteRuns() throws {
        var project = Self.ballSelected()
        #expect(try catalog.run("layer.delete", params: .object([:]), on: &project).undoStep == "Delete Layer")
        #expect(project.selectedComposition?.layers.map(\.id) == ["comp-1-layer-1"])
        _ = try catalog.run("edit.undo", params: .object([:]), on: &project)
        #expect(project.selectedComposition?.layers.count == 2)
        let rename: JSONValue = .object(["id": .string("comp-1-layer-1"), "name": .string("Ground")])
        #expect(try catalog.run("layer.rename", params: rename, on: &project).undoStep == "Rename Layer")
        let query = try catalog.run("layer.rename-begin", params: .object([:]), on: &project)
        #expect(query.result == .object(["id": .string("comp-1-layer-2"), "name": .string("Ball")]))
    }

    @Test func refusesWithTheHelpAndChangesNothing() {
        var project = commandProject("keyed", .fake)
        let before = project
        #expect(throws: CatalogError.unavailable(id: "layer.delete", why: HaloEditError.noLayerSelected.message)) {
            try catalog.run("layer.delete", params: .object([:]), on: &project)
        }
        #expect(throws: CatalogError.unavailable(id: "layer.select", why: HaloEditError.unknownLayer("x").message)) {
            try catalog.run("layer.select", params: .object(["id": .string("nope")]), on: &project)
        }
        #expect(project == before)
    }

    @Test func idsKeepTheLedger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let ledger = try String(contentsOf: url.appendingPathComponent("command-ids/halo.txt"), encoding: .utf8)
        #expect(CommandIDLedger.check(catalog.ids, ledger: ledger).isEmpty)
        let listed = Set(ledger.split(whereSeparator: \.isNewline).map(String.init))
        #expect(Set(catalog.ids).subtracting(listed).isEmpty)
    }

    /// Key editing's four ids (KE-1) join the catalog; the lane pick keeps its params.
    @Test func keyEditingIdsJoinAndLanePickKeepsItsParams() throws {
        let ids = ["timeline.pick-keys", "timeline.select-all-keys", "timeline.move-keys", "timeline.end-key-drag"]
        #expect(ids.allSatisfy { catalog.spec($0) != nil })
        #expect(catalog.spec("timeline.move-keys")?.kind == .edit)
        let lane = try #require(catalog.spec("easing.select-lane-keys"))
        #expect(lane.params == .object(["layerID": .string("A composition or layer id.", maxLength: 64),
            "frame": .integer(minimum: 0), "extending": .boolean], required: ["extending", "frame", "layerID"]))
        var project = Self.ballSelected()
        let pick: JSONValue = .object(["layerID": .string("comp-1-layer-2"), "frame": .number(24), "mode": .string("extend")])
        #expect(try catalog.run("timeline.pick-keys", params: pick, on: &project).undoStep == nil)
        #expect(project.pickedFrames(of: "comp-1-layer-2") == [24])
        let clear: JSONValue = .object(["layerID": .string("comp-1-layer-2"), "mode": .string("replace")])
        _ = try catalog.run("timeline.pick-keys", params: clear, on: &project)
        #expect(project.pickedFrames(of: "comp-1-layer-2").isEmpty)
        #expect(try catalog.run("timeline.select-all-keys", params: .object([:]), on: &project).undoStep == nil)
        #expect(project.pickedFrames(of: "comp-1-layer-2") == [0, 12, 24])
    }

    /// Where Halo breaks a kernel law today: "<ids>: <law>", by reason. Each is a gap for a later slice.
    static let exempt: [String: [String]] = [
        "Halo saves the playhead in the file": ["animation.go-to-end animation.next-frame timeline.scrub: queryOrViewChangesNoBytes"],
        "the step names the property or direction": ["inspector.set-property inspector.set-property-text inspector.toggle-animation inspector.toggle-key layer.send-backward: stepNamedTitle"],
        "a no-op edit stays enabled (in point at frame 0, drag end with no drag)": ["animation.set-in-point viewer.drag-end: stepNamedTitle",
            "animation.set-in-point viewer.drag-end: editRecordsOneStep", "animation.set-in-point viewer.drag-end: undoRestoresBytes"],
        "undo of a duplicate keeps the bumped id counter": ["layer.duplicate: undoRestoresBytes"],
        "the example needs a picked key, text layer, render, recent file or room to move": ["animation.easing animation.go-to-start animation.previous-frame composition.delete easing.delete-keys easing.end-drag easing.move-handle easing.set-custom file.open-recent layer.bring-forward render.cancel render.close-sheet text.end-size-scrub text.set text.set-color text.set-size: exampleRuns"],
        "files and rendering run through HaloHeadless in AC-h2": ["file.open file.save file.save-as render.start: exampleRuns"],
        "key editing's move is a stub until KE-4": ["timeline.move-keys: exampleRuns"],
    ]

    @Test func conformance() {
        let problems = CatalogConformance.check(HaloProject.self, fixture: Self.ballSelected())
        let exempted = Set(Self.exempt.values.joined().flatMap { entry -> [String] in
            let parts = entry.split(separator: ":")
            return parts[0].split(separator: " ").map { "\($0):\(parts[1])" }
        })
        let key = { (problem: String) in problem.split(separator: ":").prefix(2).joined(separator: ":") }
        #expect(problems.filter { !exempted.contains(key($0)) } == [])
        #expect(exempted.subtracting(problems.map(key)).sorted() == [], "an exemption no longer applies")
    }
}
