// FixtureSeeder.swift: writes a journey fixture into the suite store
// (packet correction 5, SC-4c). The three store files come from
// `SuiteFixtures.store`; for the fixtures with documents it copies each
// weekOfWork file from the exported fixtures folder into the support
// folder's Documents, and its thumbnail to `thumbnails/<fileKey>.png`. A
// source its app line hasn't exported yet is skipped, so its card shows
// Missing; `missing` always skips Cards.design.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum FixtureSeeder {
    /// Fixtures whose recents point at real documents.
    static let withDocuments: Set<String> = ["weekOfWork", "missing", "roundTrip"]

    /// Seeds `store` with fixture `name`. `documentsFrom` holds the exported
    /// fixture documents and their `thumbnails/<file name>.png`;
    /// `documentsTo` is where the documents land (the support folder's Documents).
    public static func seed(_ name: String, into store: FileStore, documentsFrom: String, documentsTo: String,
                            now: Date) throws(SuiteError) {
        guard let s = SuiteFixtures.store(name, documents: documentsTo, now: now) else {
            throw .notAvailable("No fixture named \(name).")
        }
        try replace(store, "recents.json", s.recents)
        try replace(store, "assets/index.json", s.assets)
        try replace(store, "preferences.json", s.preferences)
        guard withDocuments.contains(name) else { return }
        for (file, _, _) in SuiteFixtures.weekOfWorkFiles {
            if name == "missing" && file == "Cards.design" { continue }
            guard let data = FileManager.default.contents(atPath: documentsFrom + "/" + file) else { continue }
            try write(data, to: documentsTo + "/" + file)
            let key = SuiteDocumentRef.fileKey(SuiteDocumentRef.fileID(forPath: documentsTo + "/" + file))
            if let thumb = FileManager.default.contents(atPath: documentsFrom + "/thumbnails/" + file + ".png") {
                try store.writeData("thumbnails/\(key).png", thumb)
            }
        }
    }

    /// Overwrites `name` with `value` whatever revision it holds.
    private static func replace<T: Codable & Sendable>(_ store: FileStore, _ name: String, _ value: T) throws(SuiteError) {
        try store.update(name, empty: value) { _ in value }
    }

    private static func write(_ data: Data, to path: String) throws(SuiteError) {
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw .ioFailed(url.lastPathComponent)
        }
    }
}
