// FlareFilesTests.swift: Flare's file state (FlareFiles.swift, blueprint LM-1).
// Open through `load`, save data, the file name, the dirty flag, Open Recent,
// the autosave due time and the message for each FormatError (section 3.3),
// plus the main-thread budgets for open and save (QB-L9, QB-L12). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import Testing

struct FlareFilesTests {
    private func opened(_ document: Document = FlareFixtures.bounce, path: String = "/tmp/Bounce.flare") throws
        -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .fake())
        try workspace.open(FlareFormat.encode(document), path: path)
        return workspace
    }

    @Test func openLoadsTheDocumentNamesItAndListsItFirst() throws {
        let workspace = try opened()
        #expect(workspace.document == FlareFixtures.bounce)
        #expect(workspace.fileName == "Bounce.flare")
        #expect(workspace.isDirty == false)
        #expect(workspace.loadState == .idle)
        #expect(workspace.recent == ["/tmp/Bounce.flare"])
        #expect(workspace.canUndo == false)
    }

    @Test func saveThenOpenIsByteIdentical() throws {
        var workspace = try opened()
        let encoded = workspace.saveData()
        let saved = try #require(encoded)
        var reopened = FlareWorkspace(services: .fake())
        try reopened.open(saved, path: "/tmp/Copy.flare")
        #expect(reopened.document == workspace.document)
        #expect(reopened.saveData() == saved)
    }

    @Test func badDataThrowsAndKeepsTheDocument() throws {
        var workspace = try opened()
        workspace.addLayer()
        let before = workspace.document
        #expect(throws: FormatError.notAFlareFile) {
            try workspace.open(Data(#"{"format":"other","version":1}"#.utf8), path: "/tmp/Other.json")
        }
        #expect(workspace.document == before)
        #expect(workspace.fileName == "Bounce.flare")
        #expect(workspace.isDirty)
        #expect(workspace.canUndo)
        #expect(workspace.recent == ["/tmp/Bounce.flare"])
        #expect(workspace.loadState == .failed("This file isn't a Flare animation."))
        workspace.dismissOpenError()
        #expect(workspace.loadState == .idle)
    }

    @Test func eachFormatErrorHasSectionThreeThreesText() {
        let damaged = "layer layer-1: track x not sorted or has duplicates"
        let cases: [(FormatError, String)] = [
            (.notAFlareFile, "This file isn't a Flare animation."),
            (.malformed("not a JSON object"), "This file isn't a Flare animation."),
            (.unsupportedVersion(2), "This file was made by a newer Flare (format 2). Update Flare to open it."),
            (.unsupportedVersion(0), "This file isn't a Flare animation."),
            (.tooLarge("file is 70000000 bytes, limit 67108864"), "This file is larger than Flare can open (64 MB)."),
            (.invalid(damaged), "This file is damaged: \(damaged)."),
            (.invalid("scene s: fps must be > 0."), "This file is damaged: scene s: fps must be > 0."),
            // Engine enum dumps never reach the alert.
            (.invalid(#"layerNotFound("a")"#), "This file is damaged."),
            (.invalid("  "), "This file is damaged."),
        ]
        for (error, text) in cases {
            #expect(FlareWorkspace.message(for: error) == text)
        }
    }

    @Test func realBadFilesGiveTheirMessages() throws {
        let newer = Data(#"{"document":{},"format":"flare","version":2}"#.utf8)
        let notJSON = Data("hello".utf8)
        let huge = Data(count: FlareFormat.maxFileBytes + 1)
        var duplicate = FlareFixtures.empty
        duplicate.scenes.append(duplicate.scenes[0])
        let damaged = Data(#"{"format":"flare","version":1,"document":"#.utf8)
            + (try JSONEncoder().encode(duplicate)) + Data("}".utf8)
        let expected = [
            (newer, "This file was made by a newer Flare (format 2). Update Flare to open it."),
            (notJSON, "This file isn't a Flare animation."),
            (huge, "This file is larger than Flare can open (64 MB)."),
            (damaged, "This file is damaged: duplicate scene id scene-1."),
        ]
        for (data, text) in expected {
            var workspace = try opened()
            #expect(throws: FormatError.self) { try workspace.open(data, path: "/tmp/Bad.flare") }
            #expect(workspace.loadState == .failed(text))
            #expect(workspace.document == FlareFixtures.bounce)
        }
    }

    @Test func dirtyIsSetByAnEditAndClearedBySave() throws {
        var workspace = try opened(path: "Bounce.flare")
        workspace.renameLayer("no-such-layer", to: "X")
        #expect(workspace.isDirty == false, "a refused edit changes nothing")
        workspace.addLayer()
        #expect(workspace.isDirty)
        let encoded = workspace.saveData()
        let data = try #require(encoded)
        #expect(workspace.isDirty, "encoding alone is not a save; the write may still fail")
        workspace.didSave(to: "/work/Renamed.flare")
        #expect(workspace.isDirty == false)
        #expect(workspace.fileName == "Renamed.flare")
        #expect(workspace.recent == ["/work/Renamed.flare", "Bounce.flare"])
        #expect(try FlareFormat.decode(data) == workspace.document)
        workspace.undo()
        #expect(workspace.isDirty)
    }

    @Test func aSaveFailureIsReportedAndKeepsTheChanges() throws {
        var workspace = try opened()
        workspace.addLayer()
        workspace.saveFailed("The disk is full.")
        #expect(workspace.saveError == "Flare couldn't save Bounce.flare. The disk is full.")
        #expect(workspace.isDirty)
        workspace.didSave(to: "/tmp/Bounce.flare")
        #expect(workspace.saveError == nil)
        workspace.saveFailed("")
        #expect(workspace.saveError == "Flare couldn't save Bounce.flare.")
        workspace.dismissSaveError()
        #expect(workspace.saveError == nil)
        var untitled = FlareWorkspace(services: .fake())
        #expect(untitled.saveData() == nil)
        untitled.newDocument()
        untitled.saveFailed("Permission denied.")
        #expect(untitled.saveError == "Flare couldn't save the animation. Permission denied.")
    }

    @Test func newDocumentIsUntitledAndClean() throws {
        var workspace = try opened()
        workspace.addLayer()
        workspace.newDocument()
        #expect(workspace.fileName == nil)
        #expect(workspace.isDirty == false)
        #expect(workspace.recent == ["/tmp/Bounce.flare"], "the recent list is a preference and stays")
    }

    @Test func recentIsNewestFirstWithoutDuplicatesAndCapped() throws {
        var workspace = FlareWorkspace(services: .fake())
        let data = try FlareFormat.encode(FlareFixtures.empty)
        for i in 0..<12 { try workspace.open(data, path: "/f/\(i).flare") }
        #expect(workspace.recent.count == FlareWorkspace.recentLimit)
        #expect(workspace.recent.first == "/f/11.flare")
        #expect(workspace.recent.last == "/f/2.flare")
        try workspace.open(data, path: "/f/5.flare")
        #expect(workspace.recent.prefix(2) == ["/f/5.flare", "/f/11.flare"])
        #expect(workspace.recent.count == FlareWorkspace.recentLimit)
        #expect(workspace.recent.filter { $0 == "/f/5.flare" }.count == 1)
        workspace.forgetRecent("/f/11.flare")
        #expect(workspace.recent.prefix(2) == ["/f/5.flare", "/f/10.flare"])
        workspace.clearRecent()
        #expect(workspace.recent.isEmpty)
    }

    @Test func autosaveIsDueThirtySecondsAfterTheLastEditOnlyWhenDirty() throws {
        var workspace = try opened()
        #expect(workspace.autosaveDue(lastEdit: 100) == nil)
        workspace.addLayer()
        #expect(FlareWorkspace.autosaveDelay == 30)
        #expect(workspace.autosaveDue(lastEdit: 100) == 130)
        #expect(workspace.autosaveDue(lastEdit: 145.5) == 175.5)
        workspace.didSave(to: "/tmp/Bounce.flare")
        #expect(workspace.autosaveDue(lastEdit: 145.5) == nil)
    }

    @Test func aDetachedOpenShowsLoadingThenFinishes() throws {
        var workspace = try opened()
        workspace.beginOpen()
        #expect(workspace.loadState == .loading)
        let result = FlareWorkspace.decodeFile(try FlareFormat.encode(FlareFixtures.empty))
        workspace.finishOpen(result, path: "/tmp/Empty.flare")
        #expect(workspace.loadState == .idle)
        #expect(workspace.document == FlareFixtures.empty)
        #expect(workspace.fileName == "Empty.flare")
    }
}

/// The blueprint's file budgets on the main thread: an open shows its
/// progress state within QB-L9 (100 ms), and neither installing a decoded
/// `crowd`-sized document nor taking a save snapshot stalls for more than
/// QB-L12's two refreshes. Decode and encode run off the main thread
/// (section 2), so their time is only reported. The quietest of three runs counts.
struct FlareFilesBudgetTests {
    private static let progressBudget = Duration.milliseconds(100)
    private static let stallBudget = Duration.microseconds(33_333)

    /// 300 layers x 6 tracks x 25 keys: 45,000 keys, past `crowd`'s 5,000.
    private static let crowd: Document = {
        let tracks = ["x", "y", "scaleX", "scaleY", "rotation", "opacity"]
        let layers = (0..<300).map { i in
            Layer(id: "layer-\(i)", name: "Layer \(i)", tracks: Dictionary(uniqueKeysWithValues: tracks.map { p in
                (p, (0..<25).map { Keyframe(frame: $0 * 12, value: Double($0 + i)) })
            }))
        }
        return Document(scenes: [Scene(id: "s", name: "S", durationFrames: 300, layers: layers)])
    }()

    private func quietest(_ body: () -> Void) -> Duration {
        let clock = ContinuousClock()
        return (0..<3).map { _ in clock.measure(body) }.min() ?? .zero
    }

    @Test func openShowsProgressWithinBudget() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.newDocument()
        let cost = quietest { workspace.beginOpen() }
        print("FlareFiles beginOpen \(cost) budget \(Self.progressBudget)")
        #expect(workspace.loadState == .loading)
        #expect(cost <= Self.progressBudget)
    }

    @Test func installingADecodedLargeFileStaysUnderTwoRefreshes() throws {
        let clock = ContinuousClock()
        let data = try FlareFormat.encode(Self.crowd)
        var result = FlareWorkspace.decodeFile(data)
        let decode = clock.measure { result = FlareWorkspace.decodeFile(data) }
        var workspace = FlareWorkspace(services: .fake())
        let cost = quietest { workspace.finishOpen(result, path: "/tmp/Crowd.flare") }
        print("FlareFiles finishOpen \(cost) budget \(Self.stallBudget); decode \(data.count) bytes off-main \(decode)")
        #expect(workspace.document == Self.crowd)
        #expect(cost <= Self.stallBudget)
    }

    @Test func takingASaveSnapshotStaysUnderTwoRefreshes() throws {
        var workspace = FlareWorkspace(services: .fake())
        try workspace.open(FlareFormat.encode(Self.crowd), path: "/tmp/Crowd.flare")
        var snapshot: Document?
        let cost = quietest { snapshot = workspace.document }
        let clock = ContinuousClock()
        var data: Data?
        let encode = clock.measure { data = try? FlareWorkspace.fileData(for: Self.crowd).get() }
        print("FlareFiles save snapshot \(cost) budget \(Self.stallBudget); encode off-main \(encode)")
        #expect(snapshot == Self.crowd)
        #expect(data == workspace.saveData())
        #expect(cost <= Self.stallBudget)
    }
}
