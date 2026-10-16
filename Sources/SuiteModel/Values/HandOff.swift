// HandOff.swift: one request from one suite process to another, its verb
// and its state. The file format is `HandOffCodec` (HandOff/). Foundation
// only for `Date` and `UUID`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What a hand-off asks the receiving app to do.
public enum HandOffVerb: String, Codable, Sendable {
    case open, new, edit, place, importAnimation, returnEdit, openSettings
}

/// Where a hand-off stands.
public enum HandOffState: String, Codable, Sendable { case pending, accepted, returned, cancelled, expired }

/// One request from one suite process to another, written as `handoffs/<id>.aghandoff`.
public struct HandOff: Codable, Equatable, Identifiable, Sendable {
    public static let formatVersion = 1
    public var format: Int
    public var id: String                // `HandOff.newID()`: a lowercase UUID, so it can name a file
    public var from: SuiteApp
    public var to: SuiteApp
    public var verb: HandOffVerb
    public var documents: [SuiteDocumentRef]
    public var preset: NewDocumentPreset?
    public var asset: AssetLink?
    public var settingsPane: SettingsPane?
    public var session: String?          // a round-trip session id
    public var returnTo: SuiteApp?
    public var createdAt: Date
    public var state: HandOffState

    public init(id: String, from: SuiteApp, to: SuiteApp, verb: HandOffVerb, documents: [SuiteDocumentRef] = [],
                preset: NewDocumentPreset? = nil, asset: AssetLink? = nil, settingsPane: SettingsPane? = nil,
                session: String? = nil, returnTo: SuiteApp? = nil, createdAt: Date, state: HandOffState = .pending) {
        self.format = Self.formatVersion
        self.id = id; self.from = from; self.to = to; self.verb = verb; self.documents = documents
        self.preset = preset; self.asset = asset; self.settingsPane = settingsPane; self.session = session
        self.returnTo = returnTo; self.createdAt = createdAt; self.state = state
    }

    /// A fresh hand-off id: a lowercase UUID, 36 characters of a-z, 0-9 and -.
    public static func newID() -> String { UUID().uuidString.lowercased() }

    /// Pending hand-offs older than this are expired by the next reader.
    public static let lifetime: Double = 7 * 24 * 3600

    public func isExpired(now: Date) -> Bool {
        state == .pending && now.timeIntervalSince(createdAt) > Self.lifetime
    }
}
