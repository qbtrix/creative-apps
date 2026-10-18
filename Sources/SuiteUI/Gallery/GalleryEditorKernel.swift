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

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Layers")
                .font(SuiteFont.sectionCaps)
                .foregroundStyle(SuiteColor.secondaryText)
                .accessibilityAddTraits(.isHeader)
            LayerTreeList(rows: tree.rows(expanded: open), childCount: childCount, onAction: apply)
                .frame(maxWidth: SuiteSize.editorPanelWidth, maxHeight: .infinity)
            logView
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
