// GalleryAnchor.swift (anchor-parenting AN-5): the gallery's `anchor` page on fakes:
// two boxes, the anchor mark and AnchorRows; Layer picks a box and Rotation turns it.
import SuiteKernel
import SwiftUI

enum GalleryAnchor {
    static let name = "anchor"
    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryAnchorPage()) }]
}

/// One box: its placement in its parent and its box in its own space.
struct GalleryAnchorLayer: LayerPayload {
    var placement: Placement
    var box: Rect
    var holdsChildren: Bool { false }
}

/// The commands' target for one run; the board reads its tree back once the command is done.
private final class GalleryAnchorDoc: AnchorTarget, ParentTarget {
    var layerTree: LayerTree<GalleryAnchorLayer>
    init(_ tree: LayerTree<GalleryAnchorLayer>) { layerTree = tree }
    func placement(of id: String) -> Placement? { layerTree.node(id)?.payload.placement }
    func bounds(of id: String) -> Rect? { layerTree.node(id)?.payload.box }
    func setPlacement(_ p: Placement, of id: String) throws { _ = layerTree.update(id) { $0.payload.placement = p } }
    func local(_ node: LayerNode<GalleryAnchorLayer>) -> Matrix { node.payload.placement.matrix }
    func newNull(named name: String) throws -> String { throw CatalogError.unavailable(id: "layer.new-null", why: "The gallery page has no nulls.") }
    /// `world` back into a placement with the anchor unchanged (the boxes never shear).
    func keepPlace(_ node: inout LayerNode<GalleryAnchorLayer>, world: Matrix) {
        let o = world.apply(Point(x: 0, y: 0)), ex = world.apply(Point(x: 1, y: 0)), ey = world.apply(Point(x: 0, y: 1))
        let (ux, uy, vx, vy) = (ex.x - o.x, ex.y - o.y, ey.x - o.x, ey.y - o.y)
        let turn = atan2(uy, ux), sx = (ux * ux + uy * uy).squareRoot(), sy = -vx * sin(turn) + vy * cos(turn)
        var p = node.payload.placement
        let at = world.apply(Point(x: p.anchorX, y: p.anchorY))
        (p.x, p.y, p.scaleX, p.scaleY, p.rotation) = (at.x, at.y, sx, sy, turn * 180 / .pi)
        node.payload.placement = p
    }
}

/// The page's local document: two boxes and the one the rows and mark act on.
struct GalleryAnchorBoard {
    private(set) var tree = LayerTree([
        LayerNode(id: "box-1", name: "Box 1", payload: GalleryAnchorLayer(
            placement: Placement(x: 120, y: 110, anchorX: 60, anchorY: 40), box: Rect(minX: 0, minY: 0, maxX: 120, maxY: 80))),
        LayerNode(id: "box-2", name: "Box 2", payload: GalleryAnchorLayer(
            placement: Placement(x: 280, y: 200, anchorX: 40, anchorY: 30), box: Rect(minX: 0, minY: 0, maxX: 80, maxY: 60))),
    ])
    private(set) var selected = "box-1"
    var layer: GalleryAnchorLayer? { tree.node(selected)?.payload }
    var layers: [InspectorOption<String>] { tree.roots.map { InspectorOption(id: $0.id, title: $0.name) } }
    mutating func select(_ id: String) { selected = id }

    /// Runs `command` through AnchorCommands on the board; the log line.
    mutating func send(_ command: AnchorCommand) -> String {
        let doc = GalleryAnchorDoc(tree)
        do {
            _ = try AnchorCommands.run(command.id, command.params, anchor: doc, parent: doc)
            tree = doc.layerTree
            return "\(command.id) \(selected)"
        } catch {
            return "\(command.id): refused, \(error)"
        }
    }
    /// The mark let go: `{at:}` for a snapped point, else `{x, y}` in the box's own space.
    mutating func drop(_ drop: AnchorDrop) -> String {
        if case .at(let at) = drop { return send(AnchorRows.command(at: at, layer: selected)) }
        guard case .point(let p) = drop, let back = try? world(selected).inverted() else { return "transform.set-anchor: no inverse" }
        let local = back.apply(Point(x: p.x, y: p.y))
        return send(AnchorRows.command(x: local.x.rounded(), y: local.y.rounded(), layer: selected))
    }
    /// Turns the chosen box to `degrees` about its anchor; its followers go with it.
    mutating func turn(to degrees: Double) -> String {
        _ = tree.update(selected) { $0.payload.placement.rotation = degrees }
        return "turn \(selected) to \(Int(degrees.rounded()))°"
    }
    func world(_ id: String) -> Matrix { tree.worldPlacement(of: id) { $0.payload.placement.matrix } }
    /// `p` in `id`'s own space, on the page.
    func onPage(_ p: Point, of id: String) -> CGPoint { let q = world(id).apply(p); return CGPoint(x: q.x, y: q.y) }

    /// `id`'s box corners on the page, clockwise from its top left.
    func corners(_ id: String) -> [CGPoint] {
        guard let b = tree.node(id)?.payload.box else { return [] }
        return [(b.minX, b.minY), (b.maxX, b.minY), (b.maxX, b.maxY), (b.minX, b.maxY)].map { onPage(Point(x: $0.0, y: $0.1), of: id) }
    }
    /// The chosen box's anchor and its nine points on the page.
    var anchorOnPage: CGPoint { onPage(Point(x: layer?.placement.anchorX ?? 0, y: layer?.placement.anchorY ?? 0), of: selected) }
    var snaps: [BoxAnchor: CGPoint] {
        guard let box = layer?.box else { return [:] }
        return Dictionary(uniqueKeysWithValues: BoxAnchor.allCases.map { ($0, onPage(Placement.anchorPoint(at: $0, in: box), of: selected)) })
    }
}

/// `anchor`: two boxes, the anchor mark and the anchor rows.
struct GalleryAnchorPage: View {
    @State private var board: GalleryAnchorBoard
    @State private var log = GalleryCanvasLog()
    init(board: GalleryAnchorBoard = GalleryAnchorBoard()) { _board = State(initialValue: board) }
    var body: some View {
        let layer = board.layer
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                CanvasViewport(documentSize: GalleryCanvas.document, zoom: 1) {
                    SuiteColor.artboard
                } overlay: {
                    ZStack(alignment: .topLeading) {
                        ForEach(["box-1", "box-2"], id: \.self) { id in
                            let outline = Path { $0.addLines(board.corners(id)); $0.closeSubpath() }
                            outline.fill(SuiteColor.panel)
                            outline.stroke(SuiteColor.overlayInk, lineWidth: SuiteSize.pointMarkInk)
                            ProbeElement("suite.gallery.anchor.\(id)", label: id, rect: outline.boundingRect)
                        }
                        AnchorMark(point: board.anchorOnPage, zoom: 1, snaps: board.snaps) { log.add(board.drop($0)) }
                    }
                }
                VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
                    InspectorPickerRow("Layer", options: board.layers, selection: board.selected) { board.select($0) }
                        .suiteControl(id: "suite.gallery.anchor.layer", enabled: true, reason: nil)
                    InspectorRow("Rotation") {
                        ScrubField("Rotation", value: layer?.placement.rotation ?? 0, in: -360...360, unit: "°", decimals: 0,
                                   onChange: { log.add(board.turn(to: $0)) })
                            .suiteControl(id: "suite.gallery.anchor.rotation", enabled: true, reason: nil)
                    }
                    AnchorRows(layer: board.selected, anchor: Point(x: layer?.placement.anchorX ?? 0, y: layer?.placement.anchorY ?? 0),
                               box: layer?.box, parent: board.tree.node(board.selected)?.followsID,
                               parents: AnchorRows.parentOptions(of: board.selected, in: board.tree)) { log.add(board.send($0)) }
                }
                .frame(width: SuiteSize.inspectorWidth.max)
            }
            GalleryCanvasLogLine(log: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }
}
