// Fakes/FakeSidecars.swift (metadata-more MD-2): sidecars in memory, keyed by
// path, with the writer's guards: only a `.xmp` path that isn't an image, and
// never over a sidecar another app wrote (`foreign`). `-LibraryFakeMode` acts
// as in every fake (FakeSupport.swift): fail throws "The folder is read-only."
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeSidecars: SidecarWriting {
    let mode: FakeMode
    /// Sidecar bytes by path, for tests.
    public private(set) var files: [String: Data]
    /// Paths a test marks as another app's sidecar; a write there refuses.
    public private(set) var foreign: Set<String>

    public init(mode: FakeMode = .ok, files: [String: Data] = [:], foreign: Set<String> = []) {
        self.mode = mode; self.files = files; self.foreign = foreign
    }

    public func read(sidecar path: String) async throws -> Data? { files[path] }

    public func write(_ data: Data, sidecar path: String) async throws {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        guard name.lowercased().hasSuffix(".xmp"), PhotoFileKind.kind(forFileName: name) == nil else {
            throw LibraryError.writeFailed(path: path, reason: "\(name) isn't a sidecar file.")
        }
        try await FakeBehavior.perform(mode, failing: .writeFailed(path: path, reason: "The folder is read-only."))
        guard !foreign.contains(path) else {
            throw LibraryError.writeFailed(path: path, reason: "\(name) was written by another app; Library left it unchanged.")
        }
        files[path] = data
    }
}
