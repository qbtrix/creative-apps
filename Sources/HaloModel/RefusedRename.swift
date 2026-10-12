// RefusedRename.swift: a composition rename HaloProject refused, kept so the
// window can say why and offer the user's own name back to fix. Holds the
// name exactly as the user typed it.

/// A refused composition rename: which composition, the name the user typed
/// and the reason, ready to show.
public struct RefusedRename: Sendable, Hashable {
    public let id: String
    public let name: String
    public let problem: String

    public init(id: String, name: String, problem: String) {
        self.id = id
        self.name = name
        self.problem = problem
    }
}
