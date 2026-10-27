// LibraryWindow+Share.swift: File > Share…'s action (share-sheet SH-5, packet
// docs/blueprints/library/features/share-sheet.md). It makes the selection's
// copies as the toolbar's Share button does (`prepareShare`, the files
// `file.share-prepare` names, in `Share/<run>` beside the catalog file), then
// opens the system's share sheet (NSSharingServicePicker) from the window's
// top-trailing corner, under the Share button. A prepare that fails, or makes
// nothing, opens an alert sheet with SuiteUI's reason instead, never nothing.
import AppKit
import Foundation
import LibraryModel
import SuiteUI

extension LibraryWindow {
    /// Prepares the selection's share copies and offers them in the system's share sheet.
    func shareFromMenu() {
        let model = self.model
        Task { @MainActor in
            let support = CatalogStore().folder.path(percentEncoded: false)
            let result: Result<[URL], any Error>
            do {
                let files = try await model.prepareShare(support: support, run: UUID().uuidString)
                result = .success(files.map { URL(fileURLWithPath: $0) })
            } catch {
                result = .failure(error)
            }
            guard let window = NSApp.keyWindow ?? NSApp.mainWindow, let view = window.contentView else { return }
            switch SharePhase.finished(result) {
            case .ready(let urls):
                let top = view.isFlipped ? view.bounds.minY : view.bounds.maxY - 1
                let corner = NSRect(x: view.bounds.maxX - 1, y: top, width: 1, height: 1)
                let below: NSRectEdge = view.isFlipped ? .maxY : .minY
                NSSharingServicePicker(items: urls).show(relativeTo: corner, of: view, preferredEdge: below)
            case let phase:
                let alert = NSAlert()
                alert.messageText = "The photos couldn't be shared."
                alert.informativeText = phase.tooltip(help: nil)
                alert.beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }
}
