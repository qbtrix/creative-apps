// StoreRoundTripTests.swift: QB-SV8 (blueprint 7.4). Each store file
// (recents, assets, preferences) and a hand-off file encodes, decodes and
// encodes again to the same bytes, so a process that reads and rewrites a
// file it doesn't change never churns it.
import Foundation
import SuiteModel
import Testing

@Suite struct StoreRoundTripTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() -> FileStore {
        FileStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("StoreRoundTrip-\(UUID().uuidString)").path)
    }

    /// Writes `value` as `name`, reads it back, writes what it read to a second store: both files byte-equal.
    private func roundTrips<T: Codable & Equatable & Sendable>(_ name: String, _ value: T) throws {
        let first = makeStore(), second = makeStore()
        defer { try? FileManager.default.removeItem(atPath: first.folder); try? FileManager.default.removeItem(atPath: second.folder) }
        try first.write(name, value, expecting: 0)
        let decoded = try #require(try first.read(name, as: T.self).value)
        #expect(decoded == value)
        try second.write(name, decoded, expecting: 0)
        let a = try #require(try first.readData(name)), b = try #require(try second.readData(name))
        #expect(a == b, "\(name) re-encoded differently")
    }

    @Test func recentsRoundTrip() throws {
        let store = try #require(SuiteFixtures.store("weekOfWork", documents: "/tmp/Documents", now: now))
        try roundTrips("recents.json", store.recents)
    }

    @Test func assetsRoundTrip() throws {
        let store = try #require(SuiteFixtures.store("assets", documents: "/tmp/Documents", now: now))
        #expect(!store.assets.assets.isEmpty)
        try roundTrips("assets/index.json", store.assets)
    }

    @Test func preferencesRoundTrip() throws {
        let prefs = SuitePreferences(revision: 3, units: .millimeters, autosaveSeconds: 45, checkForUpdates: false,
                                     onboardingDoneVersion: 1, homeOrder: [.photo, .design],
                                     perApp: ["design": ["grid": "8", "snap": "on"], "flare": ["fps": "24"]])
        try roundTrips("preferences.json", prefs)
    }

    @Test func handOffRoundTrip() throws {
        let path = "/tmp/Documents/Logo.design"
        let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                                   type: .designDocument, displayName: "Logo.design")
        let handOff = HandOff(id: HandOff.newID(), from: .launcher, to: .design, verb: .open, documents: [ref],
                              settingsPane: .general, returnTo: .launcher, createdAt: now)
        let bytes = try HandOffCodec.encode(handOff)
        let decoded = try HandOffCodec.decode(bytes)
        #expect(decoded == handOff)
        #expect(try HandOffCodec.encode(decoded) == bytes)
    }
}
