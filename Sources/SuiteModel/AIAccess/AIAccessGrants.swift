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
    /// The client's name as it introduced itself, the app it wants, and the command it would run first, if known.
    public var client: String; public var app: String; public var command: String?
    public init(client: String, app: String, command: String? = nil) { (self.client, self.app, self.command) = (client, app, command) }
}

/// One remembered decision: what Window > AI Access… lists.
public struct AIAccessEntry: Codable, Hashable, Sendable {
    public var client: String; public var app: String; public var decision: AIAccessDecision
    public init(client: String, app: String, decision: AIAccessDecision) { (self.client, self.app, self.decision) = (client, app, decision) }
}

/// The remembered grants, stored through the suite preferences store (MC-9).
public struct AIAccessGrants: Codable, Hashable, Sendable {
    /// Every remembered decision, by client then app.
    public private(set) var entries: [AIAccessEntry] = []

    public init() {}

    /// Whether `client` may run a command of `kind` (`CommandKind.rawValue`) in `app`: nil means ask.
    /// A "file" command always asks. Stub: always nil (ask) until MC-9.
    public func allows(client: String, app: String, kind: String) -> Bool? { nil }

    /// Remembers `decision` for `client` in `app`. Stub: remembers nothing until MC-9.
    public mutating func record(_ decision: AIAccessDecision, client: String, app: String) {}

    /// Forgets `client`'s grants in `app`, or in every app when `app` is nil. Stub: nothing to forget until MC-9.
    public mutating func revoke(client: String, app: String?) {}
}
