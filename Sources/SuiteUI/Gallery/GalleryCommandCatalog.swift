// GalleryCommandCatalog.swift: the gallery's `command-catalog` page (packet
// docs/blueprints/suiteui/features/command-catalog.md, CC-9). It lists the
// kernel's fake catalog (`FakeCanvasDocument.catalog`) as menu items built
// from their specs (`MenuCommand(spec:on:)`): the six document commands in
// menu order, each with its help shown under it, so a disabled one's why-not
// is on screen ("Remove Rectangle: Select a rectangle first." on the empty
// document the page starts from). Clicking a row runs its spec, with the
// spec's example params, on the page's document; the log
// (`suite.gallery.log`) gets one line per run, the document line
// (`suite.gallery.command-catalog.document`) counts the rects, and the Edit
// row, built from `edit.undo`, names the step to undo ("Undo Add Rectangle")
// in `suite.gallery.status`.
//
// A debug-only `bodyRuns` counts the page's bodies, the window bodies CC-10's
// render budget reads (RenderBudgetCommandCatalogTests).
import SuiteKernel
import SwiftUI

enum GalleryCommandCatalog {
    static let name = "command-catalog"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryCommandCatalogPage()) }]

    /// The page's rows: every command but Undo and Redo, in menu order.
    static var rows: [CommandSpec<FakeCanvasDocument>] {
        ["rect.add", "rect.move", "rect.remove", "rect.select", "rect.list", "doc.export-json"]
            .compactMap { FakeCanvasDocument.catalog.spec($0) }
    }

    /// The Edit row's title: "Undo", plus the name of the step it would undo.
    static func undoTitle(_ doc: FakeCanvasDocument) -> String {
        let title = FakeCanvasDocument.catalog.spec("edit.undo")?.title ?? "Undo"
        return doc.history.undoName.map { "\(title) \($0)" } ?? title
    }

    /// Runs `id` with its example params on `doc`; the log line: the step it recorded, or the refusal.
    static func run(_ id: String, on doc: inout FakeCanvasDocument) -> String {
        let catalog = FakeCanvasDocument.catalog
        do {
            let outcome = try catalog.run(id, params: catalog.spec(id)?.example ?? .object([:]), on: &doc)
            return "\(id): \(outcome.undoStep ?? "ran")"
        } catch {
            return String(describing: error)
        }
    }
}

/// Internal, not private, so the snapshots seed its document and RenderBudgetCommandCatalogTests reads `bodyRuns`.
struct GalleryCommandCatalogPage: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif
    @State private var doc: FakeCanvasDocument
    @State private var log: [String] = []

    init(document: FakeCanvasDocument = FakeCanvasDocument()) {
        _doc = State(initialValue: document)
    }

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        HStack(alignment: .top, spacing: SuiteSpacing.m) {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                header("Commands")
                ForEach(GalleryCommandCatalog.rows, id: \.id) { spec in row(spec) }
                header("Edit")
                undoRow
                logView
            }
            .frame(width: SuiteSize.editorPanelWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                header("Document")
                canvas
                documentView
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

    /// One command: the spec-built item, its help under it.
    private func row(_ spec: CommandSpec<FakeCanvasDocument>) -> some View {
        let item = MenuCommand(spec, on: doc) { perform(spec.id) }
        let id = "suite.gallery.command-catalog.\(spec.id)"
        return VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            item.suiteControl(id: id, enabled: item.isEnabled, reason: item.isEnabled ? nil : item.help)
            caption(item.help, id: "\(id).help")
        }
    }

    @ViewBuilder private var undoRow: some View {
        if let spec = FakeCanvasDocument.catalog.spec("edit.undo") {
            let title = GalleryCommandCatalog.undoTitle(doc)
            let item = MenuCommand(spec, on: doc, title: title) { perform(spec.id) }
            item.suiteControl(id: "suite.gallery.command-catalog.edit.undo", enabled: item.isEnabled,
                              reason: item.isEnabled ? nil : item.help)
            caption(title, id: "suite.gallery.status")
        }
    }

    private var canvas: some View {
        CanvasViewport(documentSize: CGSize(width: 240, height: 160), zoom: 1, checkerboard: false) {
            Path { path in
                for rect in doc.rects { path.addRect(CGRect(x: rect.x, y: rect.y, width: rect.w, height: rect.h)) }
            }
            .stroke(SuiteColor.outline, lineWidth: 1)
            .accessibilityHidden(true)
        } overlay: {
            EmptyView()
        }
    }

    private var documentView: some View {
        caption(doc.rects.count == 1 ? "1 rect" : "\(doc.rects.count) rects", id: "suite.gallery.command-catalog.document")
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

    /// A caption line whose label and value both hold its text (XCUITest reads a SwiftUI value as empty, #262).
    private func caption(_ text: String, id: String) -> some View {
        Text(text)
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
            .accessibilityValue(text)
            .accessibilityIdentifier(id)
    }

    private func perform(_ id: String) {
        log.append(GalleryCommandCatalog.run(id, on: &doc))
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
