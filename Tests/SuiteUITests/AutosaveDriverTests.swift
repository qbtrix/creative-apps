// AutosaveDriverTests.swift (autosave-history AH-8): the `.autosaveRecovery` driver on a fake clock and a temporary
// recovery folder, and the gallery history page's live document (a jump, then Undo from the jumped state).
import Foundation
import SuiteKernel
import SuiteModel
@testable import SuiteUI
import Testing

/// The fake document: the clock, the dirty flag, the bytes, what was restored and where each encode ran.
@MainActor
private final class FakeDocument {
    var time = 0.0
    var dirty = false
    var bytes = Data("poster".utf8)
    var restored: [Data] = []
    let encodes = EncodeLog()

    var hooks: AutosaveHooks {
        AutosaveHooks(
            window: "w1", documentName: { "Poster" }, isDirty: { self.dirty },
            encoder: { [bytes, encodes] in { encodes.note(onMain: Thread.isMainThread); return bytes } },
            restore: { self.restored.append($0) })
    }

    func driver(_ folder: RecoveryFolder?, delay: Double = 2) -> AutosaveDriver {
        AutosaveDriver(folder: folder, delay: delay, now: { self.time })
    }
}

/// Counts encodes and whether each ran on main, from whatever thread runs it.
private final class EncodeLog: @unchecked Sendable {
    private let lock = NSLock()
    private var threads: [Bool] = []

    func note(onMain: Bool) { lock.withLock { threads.append(onMain) } }
    var count: Int { lock.withLock { threads.count } }
    var anyOnMain: Bool { lock.withLock { threads.contains(true) } }
}

@MainActor
@Suite struct AutosaveDriverTests {
    /// A recovery folder in a fresh temporary directory.
    private func folder() -> RecoveryFolder {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("AutosaveDriverTests-\(UUID().uuidString)").path
        return RecoveryFolder(store: FileStore(folder: path), ext: "fake")
    }

    @Test func anEditWritesOnceAfterTheDelay() async throws {
        let (doc, recovery) = (FakeDocument(), folder())
        let driver = doc.driver(recovery)
        doc.dirty = true
        driver.noteEdit()
        doc.time = 1
        await driver.tick(doc.hooks)
        #expect(doc.encodes.count == 0)
        #expect(try recovery.leftBehind().isEmpty)
        doc.time = 2
        await driver.tick(doc.hooks)
        doc.time = 5
        await driver.tick(doc.hooks)
        #expect(doc.encodes.count == 1)
        let items = try recovery.leftBehind()
        #expect(items == [RecoveryItem(window: "w1", name: "Poster", savedAt: 2, data: Data("poster".utf8))])
    }

    @Test func aSaveRemovesTheFile() async throws {
        let (doc, recovery) = (FakeDocument(), folder())
        let driver = doc.driver(recovery)
        doc.dirty = true
        driver.noteEdit()
        doc.time = 2
        await driver.tick(doc.hooks)
        #expect(try recovery.leftBehind().count == 1)
        doc.dirty = false
        await driver.didTurnClean(doc.hooks)
        #expect(try recovery.leftBehind().isEmpty)
        doc.time = 10
        await driver.tick(doc.hooks)
        #expect(doc.encodes.count == 1)
    }

    @Test func aLaunchOffersTheFileLeftBehindAndRestoreHandsItsBytesBack() async throws {
        let (doc, recovery) = (FakeDocument(), folder())
        try recovery.write(Data("left".utf8), window: "old", name: "Poster", at: 100)
        let driver = doc.driver(recovery)
        await driver.launch()
        let item = try #require(driver.offer)
        #expect(item.window == "old")
        #expect(AutosaveDriver.recoveryOffer(item).prompt == "Restore the autosaved changes to \u{201C}Poster\u{201D}?")
        #expect(AutosaveDriver.recoveryOffer(item).savedAt == Date(timeIntervalSinceReferenceDate: 100))
        #expect(AutosaveDriver.message(item).hasPrefix("Autosaved "))
        await driver.restore(item, doc.hooks)
        #expect(doc.restored == [Data("left".utf8)])
        #expect(driver.offer == nil)
        #expect(try recovery.leftBehind().count == 1)
        await driver.didTurnClean(doc.hooks)
        #expect(try recovery.leftBehind().isEmpty)
    }

    @Test func discardDeletesTheOfferedFile() async throws {
        let (doc, recovery) = (FakeDocument(), folder())
        try recovery.write(Data("left".utf8), window: "old", name: nil, at: 5)
        let driver = doc.driver(recovery)
        await driver.launch()
        let item = try #require(driver.offer)
        #expect(AutosaveDriver.recoveryOffer(item).name == "Untitled")
        await driver.discard(item)
        #expect(driver.offer == nil)
        #expect(doc.restored.isEmpty)
        #expect(try recovery.leftBehind().isEmpty)
    }

    @Test func encodesOffMain() async {
        let (doc, recovery) = (FakeDocument(), folder())
        let driver = doc.driver(recovery)
        doc.dirty = true
        driver.noteEdit()
        doc.time = 2
        await driver.tick(doc.hooks)
        #expect(doc.encodes.count == 1)
        #expect(!doc.encodes.anyOnMain)
    }

    // MARK: The gallery's live history page

    @Test func aJumpRunsHistoryCommandsAndUndoUndoesFromTheJumpedState() {
        var doc = GalleryHistoryPanel.document
        #expect(doc.historyListing == HistoryListing(base: "Open", steps: GalleryHistoryPanel.names, index: 8))
        #expect(GalleryHistoryPanel.jump(3, on: &doc) == GalleryHistoryPanel.line(3))
        #expect(doc.history.index == 3)
        #expect(doc.value == 3)
        #expect(GalleryHistoryPanel.undo(on: &doc) == "edit.undo {\"index\": 2}")
        #expect(doc.history.index == 2)
        #expect(doc.value == 2)
    }
}
