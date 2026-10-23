// AIAccessAudit.swift (afterglow-mcp MC-10): the Linux-safe half of SuiteShell's LiveCommandChannel: whether a
// command runs, asks or is refused, whether an answer holds the connection, its line in
// ~/Library/Logs/AfterGlow/ai-access.log (never the params), and LiveFront, the window a channel reaches.
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

    /// How long an answer to the sheet still counts; AIAccessCenter.ask's fallback answers after 111 s.
    public static let answerWindow: Duration = .seconds(110)

    /// Whether the command asked about runs: not on a deny, nor on an answer that came after `answerWindow`.
    public static func answeredInTime(decision: AIAccessDecision, waited: Duration) -> Bool {
        decision != .deny && waited < answerWindow
    }

    /// Whether `decision` lets the connection's later commands of `kind` run unasked: only an allow once given
    /// in time, never for a "file" command. A late allow once (no sheet could show) holds nothing.
    public static func holdsConnection(decision: AIAccessDecision, kind: String, waited: Duration) -> Bool {
        decision == .allowOnce && kind != fileKind && waited < answerWindow
    }
}

/// The window a live command channel reads and writes: the one that registered last, until it releases.
/// Each editor window registers when it becomes active and releases when it closes (SuiteShell's
/// `suiteLiveWindow`); with none, `document()` is nil and `apply` does nothing.
@MainActor public final class LiveFront<Document> {
    /// The window that live commands reach now.
    public private(set) var window: UUID?
    private var read: @MainActor () -> Document? = { nil }
    private var write: @MainActor (Document) -> Void = { _ in }

    public init() {}

    /// Makes the window `id` the one live commands reach.
    public func register(_ id: UUID, read: @escaping @MainActor () -> Document?, write: @escaping @MainActor (Document) -> Void) {
        (window, self.read, self.write) = (id, read, write)
    }

    /// The window `id` closed: if it was the front one, no window is until another registers.
    public func release(_ id: UUID) {
        guard window == id else { return }
        // One assignment each, so every closure takes its property's @MainActor type (a tuple doesn't).
        window = nil
        read = { nil }
        write = { _ in }
    }

    /// The front window's document; nil with none.
    public func document() -> Document? { read() }

    /// Hands `document` to the front window; does nothing with none.
    public func apply(_ document: Document) { write(document) }
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
