// Update.swift: the suite's version and one update the feed offers. The
// feed parser is `UpdateFeed` (Update/). Foundation free, Linux-safe, Sendable.

/// A `major.minor.patch` version; "1.2" reads as 1.2.0.
public struct SuiteVersion: Comparable, Codable, Hashable, Sendable {
    public var major: Int, minor: Int, patch: Int
    public init(_ major: Int, _ minor: Int, _ patch: Int) { self.major = major; self.minor = minor; self.patch = patch }
    public init?(_ text: String) {
        let parts = text.split(separator: ".").map { Int($0) }
        guard (1...3).contains(parts.count), parts.allSatisfy({ $0 != nil }) else { return nil }
        let n = parts.compactMap { $0 } + [0, 0]
        self.init(n[0], n[1], n[2])
    }
    public static func < (a: SuiteVersion, b: SuiteVersion) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }
}

/// One release the update feed offers.
public struct UpdateOffer: Codable, Equatable, Sendable {
    public var version: SuiteVersion
    public var notes: String
    public var url: String                  // https zip of AfterGlow.app
    public var byteCount: Int
    public var signature: String            // base64 Ed25519 over the zip
    public var minimumSystem: String        // "26.0"
    public init(version: SuiteVersion, notes: String, url: String, byteCount: Int, signature: String, minimumSystem: String) {
        self.version = version; self.notes = notes; self.url = url; self.byteCount = byteCount
        self.signature = signature; self.minimumSystem = minimumSystem
    }
}
