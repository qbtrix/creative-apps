// DesignGroupPick+Kernel.swift (area-selection AR-14): Design's click on SuiteKernel's GroupPick. A Move press
// picks the outermost group in the entered one, ⌘ (`.deep`) the layer under the pointer; a double-click
// (`.enter`) or Return enters the picked group, Escape steps out one level. select.pick, select.enter-group
// and select.exit-group run the kernel's rule on the pick tree: the selected page's layers with each frame
// made a leaf and its children lifted beside it (carrying its lock), so a frame is a place, not a group a click
// lifts to. A pick is view state, never an undo step. Linux-safe.
import SuiteKernel

/// One layer of Design's pick tree: whether it is a group a click can enter.
public struct DesignPickLayer: SuiteKernel.LayerPayload {
    public let holdsChildren: Bool
}

extension DesignModifiers {
    /// ⌘ held: the press picks the layer under the pointer, not its outermost group.
    public static let deep = DesignModifiers(rawValue: 8)
    /// The second press of a double-click: on the picked group it enters the group and picks inside.
    public static let enter = DesignModifiers(rawValue: 16)
}

extension DesignWorkspace: GroupPickTarget {
    /// The selected page's layers as the kernel picks among them, frames flattened.
    public var pickTree: LayerTree<DesignPickLayer> { LayerTree(Self.pickLayers(selectedPage?.nodes ?? [], locked: false)) }

    /// The one picked layer; nil with none or several.
    public var pickedLayer: String? { selectedNodeIDs.count == 1 ? selectedNodeID : nil }

    public func layerHit(at point: Point) -> String? { hitTest(DesignPoint(x: point.x, y: point.y)) }

    public mutating func setGroupPick(_ id: String?, scope: GroupScope) throws {
        if let id { selectItem(id) } else { deselect() }
        groupScope = scope
    }

    /// `nodes` as pick layers: a frame is a leaf followed by its children, which take its lock.
    static func pickLayers(_ nodes: [DesignNode], locked: Bool) -> [LayerNode<DesignPickLayer>] {
        nodes.flatMap { node -> [LayerNode<DesignPickLayer>] in
            let isLocked = locked || node.isLocked
            let isFrame = node.kind == .frame
            let layer = LayerNode(id: node.id, name: node.name, isHidden: node.isHidden, isLocked: isLocked,
                                  children: isFrame ? [] : pickLayers(node.children, locked: false),
                                  payload: DesignPickLayer(holdsChildren: node.kind == .group))
            return isFrame ? [layer] + pickLayers(node.children, locked: isLocked) : [layer]
        }
    }

    /// The group commands: pick at a point, enter the picked group, exit one level.
    static let groupSpecs = GroupPick.specs(DesignWorkspace.self)

    /// The layer a Move press at `point` picks: a double-click on the picked group enters it first; a hit outside
    /// the entered group leaves it for the root. Nil on empty canvas.
    mutating func pressedLayer(at point: DesignPoint, modifiers: DesignModifiers) -> String? {
        guard let hit = hitTest(point) else { return nil }
        let tree = pickTree
        let deep = modifiers.contains(.deep)
        if modifiers.contains(.enter), let id = pickedLayer, let inside = GroupPick.entering(id, scope: groupScope, in: tree),
           GroupPick.target(hit: hit, scope: inside, deep: deep, in: tree) != nil {
            groupScope = inside
        }
        if let id = GroupPick.target(hit: hit, scope: groupScope, deep: deep, in: tree) { return id }
        groupScope = .root
        return GroupPick.target(hit: hit, scope: .root, deep: deep, in: tree)
    }

    /// Escape on the canvas: out of the entered group, or deselect at the root.
    var escapeAction: DesignCanvasKeyAction { groupScope.path.isEmpty ? .deselect : .exitGroup }

    /// Return on the canvas enters the picked group when it can.
    var canEnterGroup: Bool { Self.catalog.availability("select.enter-group", on: self).why == nil }

    /// Edit > Enter Group and Return: enters the picked group; nothing when it can't.
    public mutating func enterGroup() { _ = try? Self.catalog.run("select.enter-group", params: .object([:]), on: &self) }

    /// Edit > Exit Group and Escape: steps out one level and picks that group; nothing at the root.
    public mutating func exitGroup() { _ = try? Self.catalog.run("select.exit-group", params: .object([:]), on: &self) }
}
