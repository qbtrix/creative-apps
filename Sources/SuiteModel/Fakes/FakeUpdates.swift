// FakeUpdates.swift: the in-memory UpdateChecking (UC-14). `check` reads
// its feed with `UpdateFeed`; `download` refuses a signature it doesn't
// trust with `updateNotVerified`; `install` gives `updatePostponed` when an
// app cancels its quit. With `unavailable:` set, every throwing call throws
// `.notAvailable(that sentence)` (packet correction 6).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeUpdates: UpdateChecking {
    public var feed: Data
    public private(set) var installed: [String] = []
    let unavailable: String?
    let validSignatures: Set<String>
    let refusesQuit: SuiteApp?          // an app whose unsaved-changes prompt is cancelled
    public init(feed: Data = Data("[]".utf8), validSignatures: Set<String> = [], refusesQuit: SuiteApp? = nil,
                unavailable: String? = nil) {
        self.feed = feed; self.validSignatures = validSignatures; self.refusesQuit = refusesQuit; self.unavailable = unavailable
    }
    public func check(current: SuiteVersion) throws(SuiteError) -> UpdateOffer? {
        if let unavailable { throw .notAvailable(unavailable) }
        return try UpdateFeed.newest(in: feed, above: current)
    }
    public func download(_ offer: UpdateOffer) throws(SuiteError) -> String {
        if let unavailable { throw .notAvailable(unavailable) }
        guard validSignatures.contains(offer.signature) else { throw .updateNotVerified }
        return "/tmp/AfterGlow-\(offer.version.major).\(offer.version.minor).\(offer.version.patch).zip"
    }
    public func install(zipAt path: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        if let app = refusesQuit { throw .updatePostponed(app) }
        installed.append(path)
    }
}
