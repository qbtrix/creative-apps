// GalleryEditorKernel.swift: the gallery's `editor-kernel` page (packet
// docs/blueprints/suiteui/features/editor-kernel.md, EK-4; EK-5 and EK-30 add
// to it). It draws LayerTreeList over the kernel fixture `tree200`, every
// container open: 200 rows, groups three deep, Archive hidden (its rows
// dimmed) and Footer locked. The page is the host: it owns the tree, the open
// set and the log in @State, applies each list action through the kernel
// (`LayerTree.update` and `move`, stubs until EK-12 lands their bodies) and
// writes one line per action to the `suite.gallery.log` element the journey
// reads (`move(into: "header", at: 3)`, `hide archive`, `lock footer`,
// `open cards`, `close cards`).
//
// EK-5 adds two canvases beside the list. The first draws the Cards group's
// boxes with Card 1 to Card 4 picked (a kernel `Selection`) and
// `SelectionHandles` around their union, the handles placed by
// `BoxMath.handles` (a stub drawing none until EK-20); hovering one names it
// in the `suite.gallery.status` line (`.topLeft`). The second draws
// `SnapGuideMarks` over `SnapGuides.fake` between two boxes: a line at x 300
// and gaps labelled 100, the `suite.guides` value its `summary`.
import SuiteKernel
import SwiftUI

enum GalleryEditorKernel {
    static let name = "editor-kernel"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryEditorKernelPage()) }]

    /// Every container id of `tree`, found by opening rows until no new one shows.
    static func allOpen<P: LayerPayload>(_ tree: LayerTree<P>) -> Set<String> {
        var open: Set<String> = []
        while true {
            let next = Set(tree.rows(expanded: open).filter(\.holdsChildren).map(\.id))
            if next.isSubset(of: open) { return open }
            open.formUnion(next)
        }
    }

    /// The log line for an action.
    static func line(_ action: LayerTreeAction, open: Bool) -> String {
        switch action {
        case .disclose(let id): "\(open ? "close" : "open") \(id)"
        case .toggleHidden(let id): "hide \(id)"
        case .toggleLocked(let id): "lock \(id)"
        case .move(let drop): "move(into: \"\(drop.parent)\", at: \(drop.index))"
        }
    }
}

private struct GalleryEditorKernelPage: View {
    @State private var tree = KernelFixtures.tree200
    @State private var open = GalleryEditorKernel.allOpen(KernelFixtures.tree200)
    @State private var log: [String] = []
    @State private var hovered: EditorHandle?
    private let picked = Selection<String>(["card-1", "card-2", "card-3", "card-4"])
    private let zoom = 0.5

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.m) {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                header("Layers")
                LayerTreeList(rows: tree.rows(expanded: open), childCount: childCount, onAction: apply)
                    .frame(maxWidth: SuiteSize.editorPanelWidth, maxHeight: .infinity)
                logView
            }
            .frame(maxWidth: SuiteSize.editorPanelWidth)
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                header("Selection")
                selectionCanvas
                statusView
                header("Smart guides")
                guidesCanvas
            }
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(SuiteFont.sectionCaps)
            .foregroundStyle(SuiteColor.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }

    /// The Cards group's children, read from the fixture's roots.
    private var cards: [LayerNode<KernelFixtures.Box>] {
        tree.roots.first { $0.id == "cards" }?.children ?? []
    }

    private var selectionCanvas: some View {
        let frames = cards.filter { picked.contains($0.id) }.map(\.payload.frame)
        let union = Rect(enclosing: frames.flatMap { [Point(x: $0.minX, y: $0.minY), Point(x: $0.maxX, y: $0.maxY)] })
        return CanvasViewport(documentSize: CGSize(width: 1200, height: 360), zoom: zoom, checkerboard: false) {
            boxes(cards.map(\.payload.frame))
        } overlay: {
            if let union {
                SelectionHandles(box: union, handles: BoxMath.handles(of: union, size: Double(SuiteSize.selectionHandle) / zoom),
                                 zoom: zoom, hovered: hovered) { hovered = $0 }
            }
        }
    }

    private var guidesCanvas: some View {
        let pair = [Rect(minX: 100, minY: 100, maxX: 200, maxY: 200), Rect(minX: 300, minY: 100, maxX: 400, maxY: 400)]
        return CanvasViewport(documentSize: CGSize(width: 480, height: 440), zoom: zoom, checkerboard: false) {
            boxes(pair)
        } overlay: {
            SnapGuideMarks(guides: .fake, zoom: zoom)
        }
    }

    private func boxes(_ frames: [Rect]) -> some View {
        Path { path in
            for frame in frames { path.addRect(SelectionHandles.viewRect(frame, zoom: zoom)) }
        }
        .stroke(SuiteColor.outline, lineWidth: 1)
        .accessibilityHidden(true)
    }

    private var statusView: some View {
        let text = hovered.map { ".\(SelectionHandles.name($0))" } ?? "No handle"
        return Text(text)
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .accessibilityLabel(text)
            .accessibilityValue(text)
            .accessibilityIdentifier("suite.gallery.status")
    }

    private var logView: some View {
        let text = log.joined(separator: "\n")
        return Text(log.last ?? "Nothing yet")
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .lineLimit(1)
            .accessibilityLabel(text)
            .accessibilityValue(text)
            .accessibilityIdentifier("suite.gallery.log")
    }

    private func childCount(_ id: String) -> Int {
        tree.node(id)?.children.count ?? 0
    }

    private func apply(_ action: LayerTreeAction) {
        var wasOpen = false
        if case .disclose(let id) = action { wasOpen = open.contains(id) }
        write(GalleryEditorKernel.line(action, open: wasOpen))
        switch action {
        case .disclose(let id):
            if open.contains(id) { open.remove(id) } else { open.insert(id) }
        case .toggleHidden(let id):
            _ = tree.update(id) { $0.isHidden.toggle() }
        case .toggleLocked(let id):
            _ = tree.update(id) { $0.isLocked.toggle() }
        case .move(let drop):
            try? tree.move(drop.id, into: drop.parent, at: drop.index)
        }
    }

    private func write(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
