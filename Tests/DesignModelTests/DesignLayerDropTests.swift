// DesignLayerDropTests.swift: layerDrop, the move target a Layers drop above,
// below or into a row maps to (layers-panel L-2), on `cards`: Desktop holds A, B,
// C, Title, Pair (E1, E2), Locked and Hidden, back to front. The targets on a
// frame, a group and a rectangle row, the same-parent adjustment for the
// dragged layer's removal, nil for a drop the rows can't take, a drop onto the
// dragged row's own child refused by moveLayerHelp, and each target fed through
// LiveOrdering.move to land the layer next to its row. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignLayerDropTests {
    let workspace = DesignFixtures.cards
    var page: DesignPage { workspace.selectedPage ?? DesignPage(id: "none", name: "None", frameWidth: 1, frameHeight: 1) }
    let desktop = "node-1", a = "node-2", b = "node-3", c = "node-4", title = "node-5"
    let pair = "node-6", e1 = "node-7", e2 = "node-8", locked = "node-9", hidden = "node-10"

    /// `layerDrop`'s target as a comparable pair; nil when it refuses.
    private func drop(_ dragged: String, _ row: String, _ position: DesignDropPosition) -> [String?]? {
        page.layerDrop(dragged, onto: row, position).map { [$0.parentID, String($0.index)] }
    }

    /// The names of Desktop's children, back to front, after moving `dragged` to its drop target.
    private func movedNames(_ dragged: String, _ row: String, _ position: DesignDropPosition) throws -> [String] {
        let target = try #require(page.layerDrop(dragged, onto: row, position))
        let edit = try LiveOrdering().move(dragged, into: target.parentID, at: target.index, on: page)
        return (edit.nodes.node(desktop)?.children ?? []).map(\.name)
    }

    @Test func aFrameRowTakesDropsAroundAndInsideIt() {
        #expect(drop(e1, desktop, .above) == [nil, "1"])
        #expect(drop(e1, desktop, .below) == [nil, "0"])
        #expect(drop(e1, desktop, .into) == [desktop, "7"])
        #expect(drop(a, desktop, .into) == [desktop, "6"])
    }

    @Test func aGroupRowTakesDropsAroundAndInsideIt() {
        #expect(drop(e1, pair, .above) == [desktop, "5"])
        #expect(drop(e1, pair, .below) == [desktop, "4"])
        #expect(drop(a, pair, .into) == [pair, "2"])
        #expect(drop(e1, pair, .into) == [pair, "1"])
    }

    @Test func aRectangleRowTakesDropsAroundItButNotInside() {
        #expect(drop(e1, b, .above) == [desktop, "2"])
        #expect(drop(e1, b, .below) == [desktop, "1"])
        #expect(drop(e1, b, .into) == nil)
        #expect(drop(a, e1, .into) == nil)
    }

    @Test func theDraggedLayersRemovalShiftsALaterTarget() throws {
        #expect(drop(a, b, .above) == [desktop, "1"])
        #expect(try movedNames(a, b, .above).prefix(3) == ["B", "A", "C"])
        #expect(drop(c, a, .below) == [desktop, "0"])
        #expect(try movedNames(c, a, .below).prefix(3) == ["C", "A", "B"])
        #expect(drop(title, b, .below) == [desktop, "1"])
        #expect(try movedNames(title, b, .below).prefix(3) == ["A", "Title", "B"])
    }

    @Test func everyDropLandsNextToItsRow() throws {
        let movable = [a, b, c, title, pair, hidden]
        for dragged in movable {
            for row in movable + [locked] where row != dragged {
                for position in [DesignDropPosition.above, .below] {
                    let target = try #require(page.layerDrop(dragged, onto: row, position))
                    let nodes: [DesignNode]
                    do {
                        nodes = try LiveOrdering().move(dragged, into: target.parentID, at: target.index, on: page).nodes
                    } catch {
                        #expect(error == .unchanged, "\(dragged) \(position) \(row)")
                        nodes = page.nodes
                    }
                    let ids = (nodes.node(desktop)?.children ?? []).map(\.id)
                    let (at, rowAt) = (ids.firstIndex(of: dragged), ids.firstIndex(of: row))
                    let step = position == .above ? 1 : -1
                    #expect(at.flatMap { at in rowAt.map { at == $0 + step } } == true, "\(dragged) \(position) \(row)")
                }
            }
        }
    }

    @Test func aDropTheRowsCantTakeIsNil() {
        #expect(drop(a, a, .above) == nil)
        #expect(drop(pair, pair, .into) == nil)
        #expect(drop("nope", b, .above) == nil)
        #expect(drop(a, "nope", .below) == nil)
    }

    @Test func aDropOntoItsOwnChildIsRefusedByTheMove() throws {
        let target = try #require(workspace.layerDrop(pair, onto: e1, .below))
        #expect(target.parentID == pair && target.index == 0)
        #expect(workspace.moveLayerHelp(pair, into: target.parentID, at: target.index) == "Pair can't go inside itself.")
        let nested = try #require(workspace.layerDrop(desktop, onto: pair, .into))
        #expect(workspace.moveLayerHelp(desktop, into: nested.parentID, at: nested.index) == "Desktop can't go inside itself.")
    }

    @Test func theWorkspaceDropsOnTheSelectedPage() {
        #expect(workspace.layerDrop(a, onto: b, .above)?.index == 1)
        #expect(DesignWorkspace().layerDrop(a, onto: b, .above) == nil)
    }
}
