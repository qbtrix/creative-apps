// DesignTestSupport.swift: small builders the Design model tests share, so each
// test file reads as the scenario and not the setup. Runs on Linux and macOS.
import DesignModel

func pt(_ x: Double, _ y: Double) -> DesignPoint { DesignPoint(x: x, y: y) }

func rc(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> DesignRect {
    DesignRect(x: x, y: y, width: width, height: height)
}

/// A new file: page-1 holding its Desktop frame (node-1, 0 0 1440 1024).
func openDesign() -> DesignWorkspace {
    var workspace = DesignWorkspace()
    workspace.newFile()
    return workspace
}

extension DesignWorkspace {
    /// Picks `tool` and plays one whole gesture from `start` to `end`.
    mutating func gesture(
        _ tool: DesignTool, _ start: DesignPoint, _ end: DesignPoint, _ modifiers: DesignModifiers = []
    ) {
        selectTool(tool)
        drag(from: start, to: end, modifiers: modifiers)
        endDrag()
    }

    /// The node `id` anywhere on any page, or nil.
    func treeNode(_ id: String) -> DesignNode? {
        func find(_ nodes: [DesignNode]) -> DesignNode? {
            for node in nodes {
                if node.id == id { return node }
                if let inner = find(node.children) { return inner }
            }
            return nil
        }
        return pages.lazy.compactMap { find($0.nodes) }.first
    }

    func frame(_ id: String) -> DesignRect? { treeNode(id)?.frame }
}
