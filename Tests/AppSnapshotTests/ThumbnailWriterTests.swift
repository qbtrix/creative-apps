// ThumbnailWriterTests.swift: shared-thumbnails ST-1 writes it, ST-5 turns it on
// (packet suiteui/features/shared-thumbnails.md). SuiteShell's ThumbnailWriter,
// the live ThumbnailPublishing over CoreAsset's ThumbnailStore: a published
// preview reads back, a second publish replaces the first, past the byte budget
// the oldest preview goes, and `-SuiteSupportDir` puts the store under that
// folder (`ThumbnailWriter.folder`), never under the real support root. Each test runs in its own temp
// folder. Here rather than in SuiteUITests because only this target links
// SuiteShell. macOS only.
#if os(macOS)
import Foundation
import SuiteModel
import Testing

@testable import SuiteShell

/// A fresh temp folder for one test.
private func scratch() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent("ThumbnailWriterTests-" + UUID().uuidString).path
}

/// A document ref for `name` under a fixed documents folder.
private func ref(_ name: String) -> SuiteDocumentRef {
    let path = "/tmp/Documents/" + name
    return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .photo, type: .photoOpenRaster,
                            displayName: name)
}

/// `count` bytes of `fill`, standing in for a preview PNG (the store keeps opaque bytes).
private func png(_ fill: UInt8, count: Int = 1_000) -> Data { Data(repeating: fill, count: count) }

@Suite struct ThumbnailWriterTests {
    @Test
    func publishThenPreviewReturnsTheBytes() async throws {
        let writer = try ThumbnailWriter(folder: scratch() + "/Thumbnails", budgetBytes: 256 * 1024 * 1024)
        let beach = ref("Beach.ora")
        let path = try await writer.publish(png: png(1), for: beach)
        #expect(path == "thumbnails/\(SuiteDocumentRef.fileKey(beach.fileID)).png")
        #expect(await writer.preview(for: beach) == png(1))
        #expect(await writer.preview(for: ref("Other.ora")) == nil)
    }

    @Test
    func perDocument() async throws {
        let writer = try ThumbnailWriter(folder: scratch() + "/Thumbnails", budgetBytes: 256 * 1024 * 1024)
        _ = try await writer.publish(png: png(1), for: ref("Beach.ora"))
        _ = try await writer.publish(png: png(2), for: ref("Forest.ora"))
        #expect(await writer.preview(for: ref("Beach.ora")) == png(1))
        #expect(await writer.preview(for: ref("Forest.ora")) == png(2))
    }

    @Test
    func aSecondPublishReplaces() async throws {
        let writer = try ThumbnailWriter(folder: scratch() + "/Thumbnails", budgetBytes: 256 * 1024 * 1024)
        let beach = ref("Beach.ora")
        _ = try await writer.publish(png: png(1), for: beach)
        _ = try await writer.publish(png: png(2), for: beach)
        #expect(await writer.preview(for: beach) == png(2))
    }

    @Test
    func budget() async throws {
        let writer = try ThumbnailWriter(folder: scratch() + "/Thumbnails", budgetBytes: 3_000)
        let refs = ["A.ora", "B.ora", "C.ora", "D.ora"].map(ref)
        for (index, document) in refs.enumerated() {
            _ = try await writer.publish(png: png(UInt8(index + 1)), for: document)
        }
        #expect(await writer.preview(for: refs[0]) == nil)
        for (index, document) in refs.enumerated().dropFirst() {
            #expect(await writer.preview(for: document) == png(UInt8(index + 1)))
        }
    }

    @Test
    func flagReachesStore() async throws {
        let support = scratch(), home = scratch()
        let folder = ThumbnailWriter.folder(arguments: [SuiteLocations.supportDirFlag, support], home: home)
        #expect(folder == support + "/Thumbnails")
        let writer = try ThumbnailWriter(folder: folder, budgetBytes: 256 * 1024 * 1024)
        _ = try await writer.publish(png: png(7), for: ref("Beach.ora"))
        let written = try FileManager.default.subpathsOfDirectory(atPath: folder)
        #expect(!written.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: home + "/Library/Application Support/AfterGlow"))
        // A writer reopened on the same folder reads what the first one wrote (the relaunch).
        let reopened = try ThumbnailWriter(folder: folder, budgetBytes: 256 * 1024 * 1024)
        #expect(await reopened.preview(for: ref("Beach.ora")) == png(7))
    }
}
#endif
