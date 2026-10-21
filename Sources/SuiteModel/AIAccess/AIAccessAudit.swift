// AIAccessAudit.swift (afterglow-mcp MC-10): the Linux-safe half of SuiteShell's LiveCommandChannel: whether a
// command runs, asks or is refused, and its line in ~/Library/Logs/AfterGlow/ai-access.log (never the params).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What the channel does with one command from a client.
public enum AIAccessVerdict: String, Codable, Sendable { case run, ask, refuse }

extension AIAccessGrants {
    /// `run` for a remembered always or this connection's allow once, `refuse` for a remembered deny, else `ask`.
    /// Allow once never covers a "file" command: each one asks.
    public func verdict(client: String, app: String, kind: String, allowedOnce: Bool) -> AIAccessVerdict {
        switch allows(client: client, app: app, kind: kind) {
        case true?: .run
        case false?: .refuse
        case nil: allowedOnce && kind != Self.fileKind ? .run : .ask
        }
    }
}

/// One line of the AI access log: a JSON object with sorted keys, so a client name can't break the line.
public struct AIAccessAuditLine: Codable, Hashable, Sendable {
    /// The client as it named itself, the app's name, the command's id, the UTC time and what happened
    /// ("ran", "refused", "failed").
    public var client, app, id, time, outcome: String

    public init(client: String, app: String, id: String, time: Date, outcome: String) {
        (self.client, self.app, self.id, self.outcome) = (client, app, id, outcome)
        self.time = time.ISO8601Format()
    }

    /// The line with its newline; empty if it can't be encoded.
    public var text: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    /// The log's path under the user's home.
    public static func path(home: String) -> String {
        (home.hasSuffix("/") ? String(home.dropLast()) : home) + "/Library/Logs/AfterGlow/ai-access.log"
    }
}
