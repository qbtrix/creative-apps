// DesignWorkspace.swift: the state behind Design's window (vector and UI
// design). Holds the open file's pages, the selected page and the active tool.
// Linux-safe: no UI imports. DesignApp changes it only through the mutating
// methods here. The node tree (D1) replaces `pages` with a real document model.

/// A page of a design file: one canvas of frames.
public struct DesignPage: Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String
    /// The page's default frame size in points.
    public var frameWidth: Double
    public var frameHeight: Double
}

/// The tools on Design's tool palette.
public enum DesignTool: String, CaseIterable, Sendable {
    case move, frame, rectangle, text, pen
}

public struct DesignWorkspace: Sendable, Equatable {
    /// Pages of the open file; empty when no file is open.
    public private(set) var pages: [DesignPage] = []
    public private(set) var selectedPageID: String?
    public private(set) var tool: DesignTool = .move

    public init() {}

    public var isOpen: Bool { !pages.isEmpty }

    public var selectedPage: DesignPage? {
        pages.first { $0.id == selectedPageID }
    }

    /// Opens a new file with one desktop-sized page and selects it.
    public mutating func newFile() {
        pages = [DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024)]
        selectedPageID = "page-1"
    }

    /// Appends a page named after its position and selects it. No-op with no file open.
    public mutating func addPage() {
        guard isOpen else { return }
        let n = pages.count + 1
        pages.append(DesignPage(id: "page-\(n)", name: "Page \(n)", frameWidth: 1440, frameHeight: 1024))
        selectedPageID = "page-\(n)"
    }

    /// Selects a page by id. An unknown id is ignored.
    public mutating func selectPage(_ id: String) {
        if pages.contains(where: { $0.id == id }) { selectedPageID = id }
    }

    public mutating func selectTool(_ tool: DesignTool) {
        self.tool = tool
    }
}
