// AssistContracts.swift: a prompt becomes registered commands (docs/blueprints/flare.md, 6.2 and 6.3).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

public struct AssistProposal: Equatable, Sendable {
    public var summary: String
    public var envelopes: [Data]                 // CommandRegistry envelopes, in order
    public var titles: [String]                  // one readable line per envelope
    public init(summary: String, envelopes: [Data], titles: [String]) {
        self.summary = summary; self.envelopes = envelopes; self.titles = titles
    }
}

public protocol AnimationAssisting: Sendable {
    /// Why assist can't run (no model provider configured), or nil.
    var unavailableHelp: String? { get }
    /// Throws `AssistError.noSuggestion`, `.timedOut` or `.failed(message)`.
    func propose(_ prompt: String, document: Document, selection: [StageAddress],
                 frame: Int) async throws -> AssistProposal
}

/// Why a proposal could not be made.
public enum AssistError: Error, Equatable, Sendable {
    case noSuggestion, timedOut, failed(String)
}
/// What the assist fake does, from `-FlareAssistMode`. Declared here so
/// FlareServices builds before the fake (LM-0c4) exists.
public enum FakeAssistMode: String, CaseIterable, Hashable, Sendable {
    case ok, fail, timeout, empty, text
}
