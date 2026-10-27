// PathLiveDrag.swift (#5145): one point editor press kept off the document until release. It holds a copy of the
// draft, the path in edit and the picked anchors, runs each intent of the press on that copy through the same
// `PathCommands` specs the app's catalog runs (so what it shows is what the commit makes, mapping included), and
// keeps every intent in order. At release the app runs `held` through its catalog in one go: the drag's edits share
// a token, so they are one undo step, and the window updates once instead of once per sample. A refused intent leaves
// the copy as it was and is still held, so the app's own run says why. Linux-safe.

/// A press's copy of the path the overlay draws, and the intents the app runs at release.
public struct PathLiveDrag: PathEditTarget, Equatable {
    public var penDraft: PenDraft?
    public private(set) var pathInEdit: PathInEdit?
    public var anchorSelection: Selection<AnchorRef>
    public var pathHelp: String? { nil }
    /// Every intent of the press so far, in the order it came.
    public private(set) var held: [PathIntent] = []

    public init(draft: PenDraft?, path: PathInEdit?, selection: Selection<AnchorRef>) {
        (penDraft, pathInEdit, anchorSelection) = (draft, path, selection)
    }

    /// Holds `intent` and runs it on the copy as its path command; a refusal leaves the copy unchanged.
    public mutating func run(_ intent: PathIntent) {
        held.append(intent)
        let command = intent.command
        guard let spec = Self.specs.first(where: { $0.id == command.id }) else { return }
        var copy = self
        if (try? spec.run(&copy, command.params)) != nil { self = copy }
    }

    /// A new path belongs to the app; the copy only shows edits to the path in edit.
    public mutating func addPath(_ path: VectorPath, name: String) throws -> String {
        throw CatalogError.unavailable(id: "path", why: "A press adds paths only at release.")
    }

    public mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws {
        pathInEdit?.path = path
    }

    static let specs = PathCommands.specs(PathLiveDrag.self)
}
