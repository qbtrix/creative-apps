// GalleryHistoryPanel.swift: the gallery's `history-panel` page (autosave-history AH-2; AH-8 runs it live). The page
// holds a local document with a kernel `History`: "Open" and eleven named steps, three undone, so the eighth is
// current and the three after it read as undone. A jump the panel asks for runs `history.jump` through the kernel's
// `HistoryCommands` on that document and writes one line, `history.jump {"index": <n>}`, to the `suite.gallery.log`
// element the journey reads. The page's Undo (`suite.gallery.history.undo`) then undoes from the jumped state, one
// step back, logging `edit.undo {"index": <n>}` (Journey step 5). The page is listed in `GalleryLists.pages`.
import SuiteKernel
import SwiftUI

/// The page's document: a number each step set, and the history holding the value each step replaced.
struct GalleryHistoryDocument: HistoryJumping {
    var value = 0
    var history = History<Int>()

    var historyListing: HistoryListing { history.listing(base: "Open") }

    /// The one-line conformance an app writes: `History.jumpEndingRun(to:)` over its undo adapter.
    mutating func jumpHistory(to index: Int) throws {
        var current = value
        history.jumpEndingRun(to: index) { old in defer { current = old }; return current }
        value = current
    }

    /// Undoes the last applied step; false when there is none.
    mutating func undo() -> Bool {
        var current = value
        let moved = history.undo { old in defer { current = old }; return current }
        value = current
        return moved
    }
}

enum GalleryHistoryPanel {
    static let name = "history-panel"

    static let names = ["Brush", "Brush", "Fill", "Erase", "Brush", "Move", "Transform", "Levels", "Brush", "Crop", "Rename"]

    /// The page's document as it opens: eleven steps, the last three undone, never saved (no row carries the dot).
    static var document: GalleryHistoryDocument {
        var doc = GalleryHistoryDocument()
        for (n, name) in names.enumerated() {
            doc.history.record(name, doc.value)
            doc.value = n + 1
        }
        for _ in 0..<3 { _ = doc.undo() }
        doc.history.savedStepID = -1
        return doc
    }

    /// "Open" and eleven steps, the eighth current; the sixth is "Move" (VoiceOver's "Step 6 of 11, Move").
    static var listing: HistoryListing { document.historyListing }

    static let catalog = try? CommandCatalog(
        app: "gallery", HistoryCommands.specs(GalleryHistoryDocument.self), history: { $0.history })

    static func line(_ index: Int) -> String { "history.jump {\"index\": \(index)}" }

    /// Runs `history.jump` to `index` on `doc`; the log line, or the refusal in words.
    static func jump(_ index: Int, on doc: inout GalleryHistoryDocument) -> String {
        guard let catalog else { return "history.jump: no catalog" }
        do {
            _ = try catalog.run("history.jump", params: .object(["index": .number(Double(index))]), on: &doc)
            return line(index)
        } catch {
            return String(describing: error)
        }
    }

    /// Undoes one step on `doc`; the log line names the index it landed on.
    static func undo(on doc: inout GalleryHistoryDocument) -> String {
        doc.undo() ? "edit.undo {\"index\": \(doc.history.index)}" : "edit.undo: nothing to undo"
    }
}

/// The `history-panel` page: HistoryPanel on the page's live document, its Undo, and the log under them.
struct GalleryHistoryPanelPage: View {
    @State private var doc = GalleryHistoryPanel.document
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HistoryPanel(listing: doc.historyListing, onJump: jump)
                .frame(maxWidth: SuiteSize.editorPanelWidth, maxHeight: .infinity)
            InspectorAction(ToolbarAction(
                "Undo", systemImage: "arrow.uturn.backward",
                unavailableHelp: doc.history.canUndo ? nil : "Nothing to undo.",
                identifier: "suite.gallery.history.undo"
            ) { write(GalleryHistoryPanel.undo(on: &doc)) })
            .frame(maxWidth: SuiteSize.editorPanelWidth)
            GalleryListLog(lines: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func jump(_ index: Int) { write(GalleryHistoryPanel.jump(index, on: &doc)) }

    private func write(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
