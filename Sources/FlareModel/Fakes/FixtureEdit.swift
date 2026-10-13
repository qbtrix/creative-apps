// FixtureEdit.swift: the Command a fake uses where FlareCore has none yet. It
// swaps in an edited copy of the document, so the engine still validates it
// and undo restores the document exactly. Never registered in
// `CommandRegistry`; nothing under `Sources/FlareModel/Live/` may use it.
import FlareCore

public struct FixtureEdit: Command {
    public static let id = "fixture.edit"
    public let label: String
    /// The document `execute` leaves.
    public let edited: Document
    /// The document `execute` replaced, for `undo`; nil until it ran.
    private var original: Document?
    private enum CodingKeys: String, CodingKey { case label, edited }

    public init(_ label: String, edited: Document) {
        self.label = label; self.edited = edited
    }

    /// `document` changed by `edit`. A throwing edit makes no command.
    public init(_ label: String, from document: Document, _ edit: (inout Document) throws -> Void) rethrows {
        var copy = document
        try edit(&copy)
        self.init(label, edited: copy)
    }

    public mutating func execute(_ document: inout Document) throws {
        original = document
        document = edited
    }

    public func undo(_ document: inout Document) throws {
        guard let original else { throw CommandError.notExecuted }
        document = original
    }
}
