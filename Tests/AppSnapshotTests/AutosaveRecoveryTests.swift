// AutosaveRecoveryTests.swift: MP-6's launch recovery (docs/blueprints/flare/features/mac-platform.md). Each test
// gets its own temp folder. A recovery file of bounce gives the offer "Restore the unsaved animation from <time>?"
// with the file's date; Restore lands bounce dirty and untitled and removes the file; Discard removes it; a damaged
// file is removed with no offer; no file gives no offer; the read and decode run off the main thread. macOS only.
#if os(macOS)
import FlareCore
import FlareModel
import Foundation
import Synchronization
import Testing

@testable import FlareApp

/// A fresh temp folder and the recovery file inside it.
private func recoveryFile() -> RecoveryFile {
    let folder = FileManager.default.temporaryDirectory.appending(path: "AutosaveRecoveryTests-\(UUID().uuidString)")
    return RecoveryFile(url: folder.appending(path: "Recovery").appending(path: "Untitled.flare"))
}

private func exists(_ file: RecoveryFile) -> Bool {
    FileManager.default.fileExists(atPath: file.url.path(percentEncoded: false))
}

/// A recovery file holding bounce, and its modification date.
private func bounceRecovery() async throws -> (RecoveryFile, Date) {
    let file = recoveryFile()
    try await file.write(FlareFormat.encode(FlareFixtures.bounce))
    let read = await file.read()
    let (_, date) = try #require(read)
    return (file, date)
}

/// Records, from inside the launch's read and decode, whether each call ran on the main thread.
private final class ThreadProbe: Sendable {
    let onMain = Mutex<[Bool]>([])
    func record() {
        let main = Thread.isMainThread
        onMain.withLock { $0.append(main) }
    }
}

@MainActor
@Suite struct AutosaveRecoveryTests {
    @Test func offerNamesTheFilesTime() async throws {
        let (file, date) = try await bounceRecovery()
        let launched = await FlareAutosave(recovery: file).launch()
        let offer = try #require(launched)
        #expect(offer.document == FlareFixtures.bounce)
        #expect(offer.date == date)
        let time = date.formatted(date: .abbreviated, time: .shortened)
        #expect(offer.message == "Restore the unsaved animation from \(time)?")
        #expect(exists(file), "the file stays until Restore or Discard")

        // The time string comes from the injected formatter.
        let custom = RecoveryOffer(document: FlareFixtures.bounce, date: date) { _ in "9:41 AM" }
        #expect(custom.message == "Restore the unsaved animation from 9:41 AM?")
        file.remove()
    }

    @Test func restoreLandsTheDocument() async throws {
        let (file, _) = try await bounceRecovery()
        let autosave = FlareAutosave(recovery: file)
        let launched = await autosave.launch()
        let offer = try #require(launched)
        var model = FlareWorkspace(services: .fake())
        autosave.restore(offer, into: &model)
        #expect(model.document == FlareFixtures.bounce)
        #expect(model.isDirty)
        #expect(model.title == "Untitled")
        #expect(exists(file) == false)
    }

    @Test func discardDeletesTheFile() async throws {
        let (file, _) = try await bounceRecovery()
        let autosave = FlareAutosave(recovery: file)
        let launched = await autosave.launch()
        #expect(launched != nil)
        autosave.discard()
        #expect(exists(file) == false)
        #expect(await autosave.launch() == nil)
    }

    @Test func damagedFileIsDeletedWithNoOffer() async throws {
        let file = recoveryFile()
        try await file.write(Data("not a flare file".utf8))
        #expect(exists(file))
        #expect(await FlareAutosave(recovery: file).launch() == nil)
        #expect(exists(file) == false)
    }

    @Test func noFileGivesNoOffer() async {
        let file = recoveryFile()
        #expect(await FlareAutosave(recovery: file).launch() == nil)
        #expect(exists(file) == false)
    }

    @Test func readsOffMain() async throws {
        let (file, _) = try await bounceRecovery()
        let probe = ThreadProbe()
        let launched = await FlareAutosave(recovery: file).launch(offMain: { probe.record() })
        #expect(launched != nil)
        #expect(probe.onMain.withLock { $0 } == [false])
        file.remove()
    }
}
#endif
