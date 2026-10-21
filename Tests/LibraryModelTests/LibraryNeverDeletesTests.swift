// LibraryNeverDeletesTests.swift: Library never deletes a file (cull-finish).
// Delete Rejects moves files to the Trash through `services.trash`; nothing
// under Sources/Library* calls a file-deleting API, except the catalog and
// collections stores setting a damaged file aside. Runs on Linux and macOS.
import Foundation
import Testing

/// File-deleting calls; a hit outside `allowed` fails.
private let deleting = ["removeItem(", "unlink(", "rmdir(", "remove(atPath"]
/// The only places a delete is allowed: each store replaces its set-aside copy.
private let allowed = [
    "Sources/LibraryApp/Platform/CatalogStore.swift",
    "Sources/LibraryApp/Platform/CollectionsStore.swift",
]

@Test func librarySourcesNeverDeleteAFile() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    var hits: [String] = []
    for folder in ["Sources/LibraryModel", "Sources/LibraryApp"] {
        let base = root.appendingPathComponent(folder)
        guard let files = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else {
            Issue.record("missing \(folder)"); continue
        }
        for case let file as URL in files where file.pathExtension == "swift" {
            let relative = folder + file.path.dropFirst(base.path.count)
            guard !allowed.contains(relative) else { continue }
            let text = try String(contentsOf: file, encoding: .utf8)
            for call in deleting where text.contains(call) { hits.append("\(relative): \(call)") }
        }
    }
    #expect(hits.isEmpty, "Library moves files to the Trash, never deletes: \(hits)")
}
