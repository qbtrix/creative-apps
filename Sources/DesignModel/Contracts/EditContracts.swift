// Contracts/EditContracts.swift: what every Design use case returns and the
// ids it mints. A use case never touches the workspace: it reads one page and
// returns a DesignEdit, which DesignWorkspace.apply records as exactly one named
// undo step (or merges into the run with the same coalescing key). A refused
// call throws DesignRefusal and the workspace records nothing.
//
// The help law, for a write `w` and its help read `wHelp` on the same page and
// ids: when `wHelp` is nil, `w` throws nothing but `.unchanged` (a value equal
// to the current one); when it is not nil, `w` throws, either the refusal whose
// `help` it is, or `.unchanged` when the help says the layer is already there
// (single-layer Align's "already at the left edge"). A help never depends on
// the value being written.
// DesignContractLawTests checks every fake and live conformance on `cards`.
// Coalescing keys are `runKey(base, ids)`, so a run never spans two
// selections. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One edit to the selected page: its whole new node tree and selection, named for Undo.
public struct DesignEdit: Sendable, Equatable {
    /// The undo step's name, without "Undo": "Duplicate", "Group", "Align Left".
    public var name: String
    /// The selected page's top-level nodes after the edit, back to front.
    public var nodes: [DesignNode]
    /// The selected layers after the edit, primary last.
    public var selection: [String]
    /// A run of edits with the same key is one undo step (a scrub, a drag); nil never merges.
    public var coalescingKey: String?

    public init(name: String, nodes: [DesignNode], selection: [String], coalescingKey: String? = nil) {
        (self.name, self.nodes, self.selection, self.coalescingKey) = (name, nodes, selection, coalescingKey)
    }

    /// The coalescing key for a run of `base` edits on exactly these layers: "move-node-3,node-4".
    public static func runKey(_ base: String, _ ids: [String]) -> String {
        "\(base)-\(ids.sorted().joined(separator: ","))"
    }
}

/// Why a use case refused. `help` is the sentence a disabled control shows as its tooltip.
public enum DesignRefusal: Error, Equatable, Sendable {
    case nothingSelected
    case locked(String)
    case hidden(String)
    case notSameParent
    case tooFew(needed: Int)
    case notAGroup(String)
    case notAContainer(String)
    case intoItself(String)
    case notAFrame(String)
    case noCorners(String)
    case notText(String)
    case tooFewToDistribute
    case nothingToExport
    case emptyName
    case nameTaken(String)
    case unknownID(String)
    case unreadable
    case unchanged
    /// The use case has no live conformance yet (DesignServices.live before its feature lands).
    case notBuilt(String)

    public var help: String {
        switch self {
        case .nothingSelected: "Select a layer first."
        case .locked(let name): "Unlock \(name) to change it."
        case .hidden(let name): "Show \(name) to change it."
        case .notSameParent: "Select layers that share a parent."
        case .tooFew(let needed): "Select \(needed == 2 ? "two" : "\(needed)") or more layers."
        case .tooFewToDistribute: "Select three or more layers to distribute."
        case .notAFrame(let name): "\(name) isn't a frame."
        case .noCorners(let name): "\(name) has no corners to round."
        case .notText(let name): "\(name) isn't a text layer."
        case .nothingToExport: "There's nothing on this page to export."
        case .emptyName: "A name can't be empty."
        case .nameTaken(let name): "\(name) is already used."
        case .notAGroup(let name): "\(name) isn't a group."
        case .notAContainer(let name): "\(name) can't hold other layers."
        case .intoItself(let name): "\(name) can't go inside itself."
        case .unknownID(let id): "\(id) isn't on this page."
        case .unreadable: "The pasteboard holds no Design layers."
        case .unchanged: "Nothing would change."
        case .notBuilt(let feature): "\(feature) isn't built yet."
        }
    }
}

/// Mints node ids no page or node of the file holds. The workspace makes one from its held-id
/// index and counter before a use case runs, and takes `counter` back after a successful edit.
public struct DesignIDMint: Sendable, Equatable {
    /// Every id the file held when the mint was made.
    public let taken: Set<String>
    /// The highest "node-N" handed out so far.
    public private(set) var counter: Int
    /// The ids this mint handed out, in order.
    public private(set) var minted: [String] = []

    public init(taken: Set<String>, after counter: Int) {
        (self.taken, self.counter) = (taken, Swift.max(counter, 0))
    }

    /// The next "node-N" that is neither taken nor minted. Never repeats an id.
    public mutating func nextNodeID() -> String {
        repeat { counter += 1 } while taken.contains("node-\(counter)")
        let id = "node-\(counter)"
        minted.append(id)
        return id
    }
}
