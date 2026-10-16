// UpdateFeed.swift: reads the update feed, a JSON array of `UpdateOffer`s,
// and picks the newest offer above the running version. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum UpdateFeed {
    /// The feed is a JSON array of offers; the newest above `current` wins.
    public static func newest(in data: Data, above current: SuiteVersion) throws(SuiteError) -> UpdateOffer? {
        guard let offers = try? JSONDecoder().decode([UpdateOffer].self, from: data) else { throw .damaged("update feed") }
        return offers.filter { $0.version > current }.max { $0.version < $1.version }
    }
}
