// DesignFixtures.swift: the named documents the tests, snapshots and fixture
// journeys open (docs/blueprints/design.md section 4, Fixtures): `empty`,
// `cards`, `twoPages` ("two-pages") and `crowd`. Built in code, never read from
// disk. Each one is a workspace that has just opened the document, the same
// state `open(_:at:)` leaves: first page selected, empty history, no location
// (an unsaved file). Frames are absolute page points; children are listed back
// to front. Ids follow the counters' "page-N" and "node-N", so the next minted
// id is past every fixture id. Linux-safe.

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
