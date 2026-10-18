// KernelFixtures.swift (EK-2): the trees the gallery page, the logic slices'
// tests and the snapping lead share, so every one of them reads one tree.
// `tree200` is the layers panel's load (200 nodes, seven roots, groups three
// deep, one hidden group, one locked); `cards` is the snapping packet's page.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The kernel's shared fixtures.
public enum KernelFixtures {
    /// The fixtures' payload: a frame in document space and whether it is a container.
    public struct Box: LayerPayload {
        /// The left, top, width and height of the frame.
        public var x, y, width, height: Double
        /// True for a group or frame.
        public var holdsChildren: Bool
        /// The frame as a kernel `Rect`.
        public var frame: Rect { Rect(minX: x, minY: y, maxX: x + width, maxY: y + height) }
    }

    /// 200 nodes under seven roots, back to front: Header (3 children, so a
    /// drop lands at 3), Hero (5), Cards ("Card 1" to "Card 30"), Gallery
    /// (4 rows of 3 columns of 9 items: groups three deep), Archive (hidden,
    /// 21), Footer (locked, 10) and Background.
    public static let tree200: LayerTree<Box> = LayerTree([
        group("header", "Header", numbered("header", "Item", 3)),
        group("hero", "Hero", numbered("hero", "Hero", 5)),
        group("cards", "Cards", numbered("card", "Card", 30)),
        group("gallery", "Gallery", (1...4).map { r in
            group("row-\(r)", "Row \(r)", (1...3).map { c in
                group("row-\(r)-col-\(c)", "Column \(c)", numbered("item-\(r)-\(c)", "Item", 9))
            })
        }),
        group("archive", "Archive", numbered("archive", "Old", 21), hidden: true),
        group("footer", "Footer", numbered("footer", "Link", 10), locked: true),
        leaf("background", "Background", index: 0),
    ])

    /// The snapping packet's page: A, B, C, Title, Pair (holding E1 and E2),
    /// Locked and Hidden, all in Desktop (0, 0, 1440 × 1024).
    public static let cards: LayerTree<Box> = LayerTree([
        LayerNode(id: "desktop", name: "Desktop", children: [
            box("a", "A", 100, 100, 100, 80), box("b", "B", 300, 140, 200, 80),
            box("c", "C", 700, 100, 100, 120), box("title", "Title", 100, 40, 200, 32),
            LayerNode(id: "pair", name: "Pair", children: [
                box("e1", "E1", 900, 400, 140, 100), box("e2", "E2", 1060, 400, 140, 100),
            ], payload: Box(x: 900, y: 400, width: 300, height: 100, holdsChildren: true)),
            box("locked", "Locked", 400, 600, 100, 100, locked: true),
            box("hidden", "Hidden", 600, 600, 100, 100, hidden: true),
        ], payload: Box(x: 0, y: 0, width: 1440, height: 1024, holdsChildren: true)),
    ])

    private static func box(_ id: String, _ name: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double,
                            hidden: Bool = false, locked: Bool = false) -> LayerNode<Box> {
        LayerNode(id: id, name: name, isHidden: hidden, isLocked: locked,
                  payload: Box(x: x, y: y, width: w, height: h, holdsChildren: false))
    }

    private static func leaf(_ id: String, _ name: String, index: Int) -> LayerNode<Box> {
        box(id, name, Double(index % 10) * 120, Double(index / 10) * 90, 100, 80)
    }

    private static func numbered(_ id: String, _ name: String, _ count: Int) -> [LayerNode<Box>] {
        (1...count).map { leaf("\(id)-\($0)", "\(name) \($0)", index: $0) }
    }

    private static func group(_ id: String, _ name: String, _ children: [LayerNode<Box>],
                              hidden: Bool = false, locked: Bool = false) -> LayerNode<Box> {
        LayerNode(id: id, name: name, isHidden: hidden, isLocked: locked, children: children,
                  payload: Box(x: 0, y: 0, width: 1200, height: 900, holdsChildren: true))
    }
}
