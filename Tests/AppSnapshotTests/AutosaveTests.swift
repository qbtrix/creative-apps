// AutosaveTests.swift: MP-5's autosave writer and recovery file (docs/blueprints/flare/features/mac-platform.md).
// Each test gets its own temp folder. A due, dirty model writes the recovery file once per edit; a clean model
// writes nothing; the write is atomic, so a failed write leaves no file at the url; a clean save removes the file;
// quitting while dirty writes it once more. macOS only.
#if os(macOS)
import FlareCore
import FlareModel
import Foundation
import Testing

@testable import FlareApp

/// A fresh temp folder and the recovery file inside it.
private func recoveryFile() -> RecoveryFile {
    let folder = FileManager.default.temporaryDirectory.appending(path: "AutosaveTests-\(UUID().uuidString)")
    return RecoveryFile(url: folder.appending(path: "Recovery").appending(path: "Untitled.flare"))
}

private func exists(_ file: RecoveryFile) -> Bool {
    FileManager.default.fileExists(atPath: file.url.path(percentEncoded: false))
}

/// Bounce, opened clean.
private func opened() throws -> FlareWorkspace {
    var model = FlareWorkspace(services: .fake())
    try model.open(FlareFormat.encode(FlareFixtures.bounce), named: "Bounce.flare")
    return model
}

/// Bounce with one unsaved edit.
private func edited() throws -> FlareWorkspace {
    var model = try opened()
    model.addLayer()
    return model
}

@MainActor
@Suite struct AutosaveTests {
    @Test func dueModelWritesRecovery() async throws {
        let model = try edited()
        let file = recoveryFile()
        let autosave = FlareAutosave(recovery: file)
        autosave.noteEdit(at: 0)

        await autosave.tick(model: model, now: 29)
        #expect(exists(file) == false)

        await autosave.tick(model: model, now: 30)
        let written = await file.read()
        let (data, _) = try #require(written)
        #expect(data == model.recoveryData())

        // Once per edit: a later tick doesn't write the same edit again.
        file.remove()
        await autosave.tick(model: model, now: 31)
        await autosave.tick(model: model, now: 90)
        #expect(exists(file) == false)

        // A new edit is written once it is due.
        autosave.noteEdit(at: 100)
        await autosave.tick(model: model, now: 130)
        #expect(exists(file))
    }

    @Test func cleanModelWritesNothing() async throws {
        let file = recoveryFile()
        let autosave = FlareAutosave(recovery: file)
        autosave.noteEdit(at: 0)
        let clean = try opened()
        await autosave.tick(model: clean, now: 1_000)
        await autosave.tick(model: FlareWorkspace(services: .fake()), now: 2_000)
        await autosave.willQuit(model: clean)
        #expect(exists(file) == false)
    }

    @Test func noEditWritesNothing() async throws {
        let file = recoveryFile()
        let model = try edited()
        await FlareAutosave(recovery: file).tick(model: model, now: 1_000)
        #expect(exists(file) == false)
    }

    @Test func writeIsAtomic() async throws {
        let file = recoveryFile()
        try await file.write(Data("old".utf8))
        try await file.write(Data("new".utf8))
        let read = await file.read()
        #expect(read?.0 == Data("new".utf8))
        let folder = file.url.deletingLastPathComponent()
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
        #expect(names == [file.url.lastPathComponent])

        // A folder that can't be made (a plain file sits where it should be): the write throws, no file appears.
        let root = FileManager.default.temporaryDirectory.appending(path: "AutosaveTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appending(path: "blocker")
        try Data("x".utf8).write(to: blocker)
        let blocked = RecoveryFile(url: blocker.appending(path: "Untitled.flare"))
        await #expect(throws: (any Error).self) { try await blocked.write(Data("new".utf8)) }
        #expect(exists(blocked) == false)
        #expect(await blocked.read() == nil)
    }

    @Test func cleanSaveRemovesFile() async throws {
        var model = try edited()
        let file = recoveryFile()
        let autosave = FlareAutosave(recovery: file)
        autosave.noteEdit(at: 0)
        await autosave.tick(model: model, now: 30)
        #expect(exists(file))

        let saved = model.saveData()
        let save = try #require(saved)
        model.didSave(save, named: "Bounce.flare")
        autosave.didSave()
        #expect(exists(file) == false)
        #expect(autosave.lastEdit == nil)

        await autosave.tick(model: model, now: 1_000)
        #expect(exists(file) == false)
        file.remove()
        #expect(exists(file) == false)
    }

    @Test func quitWritesWhenDirty() async throws {
        let model = try edited()
        let file = recoveryFile()
        await FlareAutosave(recovery: file).willQuit(model: model)
        let written = await file.read()
        let (data, date) = try #require(written)
        #expect(data == model.recoveryData())
        #expect(abs(date.timeIntervalSinceNow) < 60)
    }

    @Test func missingFileReadsNil() async {
        let file = recoveryFile()
        #expect(await file.read() == nil)
        file.remove()
    }
}
#endif
