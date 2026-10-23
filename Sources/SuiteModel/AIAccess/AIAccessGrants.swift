// AIAccessGrants.swift (afterglow-mcp MC-1 contract, MC-9 body): which MCP
// clients may drive a running app's live document. SuiteModel doesn't see
// SuiteKernel, so a command's kind comes in as `CommandKind.rawValue`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The user's answer to an approval request.
public enum AIAccessDecision: String, Codable, Sendable { case allowOnce, alwaysForClient, deny }

/// One client asking to drive one app: what the approval sheet shows.
public struct AIAccessRequest: Codable, Hashable, Sendable {
    /// The client's name as it introduced itself, the app it wants, the command it would run first, if known,
    /// and the document the window has open, nil on a window without one.
    public var client: String; public var app: String; public var command: String?; public var document: String?
    public init(client: String, app: String, command: String? = nil, document: String? = nil) {
        (self.client, self.app, self.command, self.document) = (client, app, command, document)
    }
}

/// One remembered decision: what Window > AI Access… lists.
public struct AIAccessEntry: Codable, Hashable, Sendable {
    public var client: String; public var app: String; public var decision: AIAccessDecision
    public init(client: String, app: String, decision: AIAccessDecision) { (self.client, self.app, self.decision) = (client, app, decision) }
}

/// The remembered grants: an always or a deny per client per app (allow once
/// is never remembered), stored in `preferences.json` under each app's
/// `perApp` keys as `aiAccess.<client>` = the decision's raw value.
public struct AIAccessGrants: Codable, Hashable, Sendable {
    /// The `CommandKind.rawValue` that always asks, whatever the grant: a file command reads or writes the disk.
    public static let fileKind = "file"
    /// The `perApp` key prefix a grant is stored under.
    public static let keyPrefix = "aiAccess."

    /// Every remembered decision, by client then app.
    public private(set) var entries: [AIAccessEntry] = []

    public init() {}

    /// The grants stored in `preferences`' per-app keys; a key with an unknown decision is skipped.
    public init(preferences: SuitePreferences) {
        for (app, keys) in preferences.perApp {
            for (key, value) in keys where key.hasPrefix(Self.keyPrefix) {
                guard let decision = AIAccessDecision(rawValue: value) else { continue }
                record(decision, client: String(key.dropFirst(Self.keyPrefix.count)), app: app)
            }
        }
    }

    /// Whether `client` may run a command of `kind` (`CommandKind.rawValue`) in `app`: true for an
    /// always, false for a deny, nil (ask) for no grant. A "file" command always asks.
    public func allows(client: String, app: String, kind: String) -> Bool? {
        guard kind != Self.fileKind else { return nil }
        switch entries.first(where: { $0.client == client && $0.app == app })?.decision {
        case .alwaysForClient: return true
        case .deny: return false
        case .allowOnce, nil: return nil
        }
    }

    /// Remembers `decision` for `client` in `app`, replacing the one before. Allow once remembers nothing.
    public mutating func record(_ decision: AIAccessDecision, client: String, app: String) {
        guard decision != .allowOnce else { return }
        entries.removeAll { $0.client == client && $0.app == app }
        entries.append(AIAccessEntry(client: client, app: app, decision: decision))
        entries.sort { ($0.client, $0.app) < ($1.client, $1.app) }
    }

    /// Forgets `client`'s grants in `app`, or in every app when `app` is nil.
    public mutating func revoke(client: String, app: String?) {
        entries.removeAll { $0.client == client && (app == nil || $0.app == app) }
    }

    /// `preferences` with its stored grants replaced by these; every other key is kept and an app left with none is dropped.
    public func stored(in preferences: SuitePreferences) -> SuitePreferences {
        var p = preferences
        p.perApp = p.perApp.mapValues { $0.filter { !$0.key.hasPrefix(Self.keyPrefix) } }
        for entry in entries { p.perApp[entry.app, default: [:]][Self.keyPrefix + entry.client] = entry.decision.rawValue }
        p.perApp = p.perApp.filter { !$0.value.isEmpty }
        return p
    }

    /// The grants in the suite preferences store.
    public static func load(from store: any PreferencesStoring) async throws(SuiteError) -> AIAccessGrants {
        AIAccessGrants(preferences: try await store.load())
    }

    /// Writes these grants into the store over its current value; `.staleRevision` when another writer won (reload and retry).
    public func save(to store: any PreferencesStoring) async throws(SuiteError) {
        _ = try await store.save(stored(in: try await store.load()))
    }
}
