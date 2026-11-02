// DesignFixtures.swift: the named documents the tests, snapshots and fixture
// journeys open (docs/blueprints/design.md section 4, Fixtures): `empty`,
// `cards`, `twoPages` ("two-pages") and `crowd`. Built in code, never read from
// disk. Each one is a workspace that has just opened the document, the same
// state `open(_:at:)` leaves: first page selected, empty history, no location
// (an unsaved file). Frames are absolute page points; children are listed back
// to front. Ids follow the counters' "page-N" and "node-N", so the next minted
// id is past every fixture id. `animated(_:)` and `keyedCrowd` are the keyed documents the node-time tests
// and budgets use; `animated(_:kinds:)` is `animated(_:)` per node kind (text, gradient, stroke, a mixed
// UI of cards), keyed the same way, for the raster costing rows. They stay off `names`. Linux-safe.

import SuiteKernel

public enum DesignFixtures {
    /// The fixture names a launch argument uses, in the blueprint's order.
    public static let names = ["empty", "cards", "two-pages", "crowd"]

    /// The fixture called `name` in `names`, or nil.
    public static func named(_ name: String) -> DesignWorkspace? {
        switch name {
        case "empty": empty
        case "cards": cards
        case "two-pages": twoPages
        case "crowd": crowd
        default: nil
        }
    }

    /// New File: one page holding the "Desktop" frame.
    public static var empty: DesignWorkspace {
        var workspace = DesignWorkspace()
        workspace.newFile()
        return workspace
    }

    /// One 1440 × 1024 page whose "Desktop" frame holds A, B, C, Title, the group Pair (E1, E2),
    /// a locked rectangle "Locked" and a hidden one "Hidden".
    public static var cards: DesignWorkspace { opened([cardsPage]) }

    /// `cards` plus a second page "Mobile", 390 × 844, holding the frame "Phone".
    public static var twoPages: DesignWorkspace {
        let phone = DesignNode(id: "node-11", name: "Phone", kind: .frame, frame: rect(0, 0, 390, 844))
        let mobile = DesignPage(id: "page-2", name: "Mobile", frameWidth: 390, frameHeight: 844, nodes: [phone])
        return opened([cardsPage, mobile])
    }

    /// 2,000 layers on one page: 40 frames in 8 columns and 5 rows, each holding 48 rectangles
    /// (8 across, 6 down) and one text.
    public static var crowd: DesignWorkspace {
        var number = 0
        func nextID() -> String {
            number += 1
            return "node-\(number)"
        }
        var frames: [DesignNode] = []
        for index in 0..<40 {
            let (x, y) = (10 + Double(index % 8) * 175, 10 + Double(index / 8) * 200)
            let frameID = nextID()
            var children: [DesignNode] = []
            for cell in 0..<48 {
                let at = rect(x + 2 + Double(cell % 8) * 20, y + 2 + Double(cell / 8) * 20, 16, 16)
                children.append(DesignNode(id: nextID(), name: "Rectangle \(cell + 1)", kind: .rectangle, frame: at))
            }
            children.append(
                DesignNode(id: nextID(), name: "Text", kind: .text, frame: rect(x + 2, y + 124, 156, 24), text: "Text"))
            frames.append(
                DesignNode(id: frameID, name: "Frame \(index + 1)", kind: .frame, frame: rect(x, y, 160, 150),
                           children: children))
        }
        return opened([DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: frames)])
    }

    /// One 1440 × 1024 UI frame holding `count` 24 × 16 rectangles in rows of 25. Every rectangle's x, y and
    /// opacity are keyed over 2 s (frames 0 and 120 at 60 fps) and the frame's x too, so sampling moves a subtree.
    /// Not in `names`: no journey opens it.
    public static func animated(_ count: Int) -> DesignWorkspace {
        let cells = (0..<count).map { i in
            keyed(DesignNode(id: "node-\(i + 2)", name: "Rectangle \(i + 1)", kind: .rectangle,
                             frame: rect(30 + Double(i % 25) * 54, 30 + Double(i / 25) * 48, 24, 16)), dx: 24, dy: 20)
        }
        var frame = DesignNode(id: "node-1", name: "Frame 1", kind: .frame, frame: rect(10, 10, 1400, 1000),
                               children: cells)
        frame.time = DesignNodeTime(tracks: [.x: [Keyframe(frame: 0, value: 10), Keyframe(frame: 120, value: 20)]])
        return opened([DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [frame])])
    }

    /// The node kinds `animated(_:kinds:)` fills its frame with.
    public enum AnimatedKinds: String, CaseIterable, Sendable {
        /// `animated(_:)` itself: plain 24 × 16 rectangles.
        case rectangles
        /// 48 × 20 text nodes reading "Label".
        case texts
        /// 24 × 16 rectangles with a blue-to-white linear gradient.
        case gradients
        /// 24 × 16 rectangles with a 1 pt stroke, solid and dashed (4, 2) by turns.
        case strokes
        /// A gradient header and `(count - 1) / 5` cards (a stroked card, title, body, dashed chip, chip label).
        case realUI
    }

    /// `animated(_:)` with its `count` leaves of `kinds`, every leaf keyed as there and the frame's x too.
    /// Not in `names`.
    public static func animated(_ count: Int, kinds: AnimatedKinds) -> DesignWorkspace {
        func cell(_ i: Int, _ width: Double, _ height: Double) -> DesignRect {
            rect(30 + Double(i % 25) * 54, 30 + Double(i / 25) * 48, width, height)
        }
        let blueToWhite = Fill.linear(
            stops: [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 1)), GradientStop(offset: 1, color: .white)],
            start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
        let solid = DesignStroke(width: 1), dashed = DesignStroke(width: 1, dash: [4, 2])
        var leaves: [DesignNode]
        switch kinds {
        case .rectangles:
            return animated(count)
        case .texts:
            leaves = (0..<count).map {
                DesignNode(id: "", name: "Text \($0 + 1)", kind: .text, frame: cell($0, 48, 20), text: "Label")
            }
        case .gradients:
            leaves = (0..<count).map {
                DesignNode(id: "", name: "Gradient \($0 + 1)", kind: .rectangle, frame: cell($0, 24, 16),
                           gradient: blueToWhite)
            }
        case .strokes:
            leaves = (0..<count).map {
                DesignNode(id: "", name: "Stroke \($0 + 1)", kind: .rectangle, frame: cell($0, 24, 16),
                           stroke: $0.isMultiple(of: 2) ? solid : dashed)
            }
        case .realUI:
            leaves = [DesignNode(id: "", name: "Header", kind: .rectangle, frame: rect(30, 30, 1360, 80),
                                 cornerRadius: 12, gradient: blueToWhite)]
            for card in 0..<(count - 1) / 5 {
                let (x, y) = (30 + Double(card % 8) * 170, 130 + Double(card / 8) * 170)
                leaves += [
                    DesignNode(id: "", name: "Card \(card + 1)", kind: .rectangle, frame: rect(x, y, 160, 150),
                               fill: .white, cornerRadius: 12, stroke: solid),
                    DesignNode(id: "", name: "Title", kind: .text, frame: rect(x + 12, y + 12, 136, 24),
                               text: "Card \(card + 1)"),
                    DesignNode(id: "", name: "Body", kind: .text, frame: rect(x + 12, y + 44, 136, 48),
                               text: "Two lines of body copy on a card."),
                    DesignNode(id: "", name: "Chip", kind: .rectangle, frame: rect(x + 12, y + 106, 64, 28),
                               fill: .white, cornerRadius: 14, stroke: dashed),
                    DesignNode(id: "", name: "Chip Label", kind: .text, frame: rect(x + 20, y + 110, 48, 20), text: "Tag"),
                ]
            }
        }
        let cells = leaves.enumerated().map { i, leaf in keyed(DesignNode(id: "node-\(i + 2)", copying: leaf), dx: 24, dy: 20) }
        var frame = DesignNode(id: "node-1", name: "Frame 1", kind: .frame, frame: rect(10, 10, 1400, 1000),
                               children: cells)
        frame.time = DesignNodeTime(tracks: [.x: [Keyframe(frame: 0, value: 10), Keyframe(frame: 120, value: 20)]])
        return opened([DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [frame])])
    }

    /// `crowd` with every rectangle keyed as `animated`'s are; the frames and texts stay still. Not in `names`.
    public static var keyedCrowd: DesignWorkspace {
        var workspace = crowd
        workspace.pages[0].nodes = workspace.pages[0].nodes.map { frame in
            var frame = frame
            frame.children = frame.children.map { $0.kind == .rectangle ? keyed($0, dx: 4, dy: 4) : $0 }
            return frame
        }
        return workspace
    }

    /// `node` keyed from its rest pose at frame 0 to (+dx, +dy) and opacity 0.3 at frame 120.
    private static func keyed(_ node: DesignNode, dx: Double, dy: Double) -> DesignNode {
        var node = node
        let (x, y) = (node.frame.x, node.frame.y)
        node.time = DesignNodeTime(tracks: [
            .x: [Keyframe(frame: 0, value: x), Keyframe(frame: 120, value: x + dx)],
            .y: [Keyframe(frame: 0, value: y), Keyframe(frame: 120, value: y + dy)],
            .opacity: [Keyframe(frame: 0, value: 1), Keyframe(frame: 120, value: 0.3)],
        ])
        return node
    }

    private static var cardsPage: DesignPage {
        let pair = DesignNode(
            id: "node-6", name: "Pair", kind: .group, frame: rect(900, 400, 300, 100),
            children: [
                DesignNode(id: "node-7", name: "E1", kind: .ellipse, frame: rect(900, 400, 100, 100)),
                DesignNode(id: "node-8", name: "E2", kind: .ellipse, frame: rect(1100, 400, 100, 100)),
            ])
        let desktop = DesignNode(
            id: "node-1", name: "Desktop", kind: .frame, frame: rect(0, 0, 1440, 1024),
            children: [
                DesignNode(id: "node-2", name: "A", kind: .rectangle, frame: rect(100, 100, 100, 80)),
                DesignNode(id: "node-3", name: "B", kind: .rectangle, frame: rect(300, 140, 200, 80)),
                DesignNode(id: "node-4", name: "C", kind: .rectangle, frame: rect(700, 100, 100, 120)),
                DesignNode(id: "node-5", name: "Title", kind: .text, frame: rect(100, 40, 200, 32), text: "Title"),
                pair,
                DesignNode(id: "node-9", name: "Locked", kind: .rectangle, frame: rect(400, 600, 100, 100),
                           isLocked: true),
                DesignNode(id: "node-10", name: "Hidden", kind: .rectangle, frame: rect(600, 600, 100, 100),
                           isHidden: true),
            ])
        return DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [desktop])
    }

    private static func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> DesignRect {
        DesignRect(x: x, y: y, width: width, height: height)
    }

    /// A workspace that has just opened `pages`, as Open leaves it.
    private static func opened(_ pages: [DesignPage]) -> DesignWorkspace {
        var workspace = DesignWorkspace()
        workspace.load(pages)
        return workspace
    }
}
