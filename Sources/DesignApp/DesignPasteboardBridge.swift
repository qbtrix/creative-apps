// DesignPasteboardBridge.swift: moves Design's layer bytes to and from a
// pasteboard (the general one in the app, a private named one in tests) under
// the Model's own type (`DesignWorkspace.pasteboardType`). The Model makes and
// reads the bytes; this file only carries them. A write replaces what the
// pasteboard held; a read never changes it; another type reads as nil.
//
// `designPasteboardCommands` hooks the system's Cut, Copy, Paste and Delete (the
// stock Edit items and their shortcuts) on a focused view, the canvas and the
// Layers list, to `.cut`, `.copy`, `.paste` and `.deleteSelection`, which
// DesignWindow runs (the first three through the bridge). Copy and Cut are off
// while the Model gives a reason (nothing selected, a text edit under way), and
// Delete while DesignMenu can't delete a layer, so a text field keeps its own. A hook
// hands the system the bytes the window just wrote, so whatever the system
// then writes holds the same bytes under the same type. macOS only.
import AppKit
import DesignModel
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct DesignPasteboardBridge {
    var pasteboard: NSPasteboard = .general

    /// Puts `data` on the pasteboard as its only contents, under `type`.
    func write(_ data: Data, type: String) {
        let kind = NSPasteboard.PasteboardType(type)
        _ = pasteboard.declareTypes([kind], owner: nil)
        _ = pasteboard.setData(data, forType: kind)
    }

    /// The bytes under `type`; nil when the pasteboard holds none of it. Leaves the pasteboard as it was.
    func read(type: String) -> Data? {
        pasteboard.data(forType: NSPasteboard.PasteboardType(type))
    }

    /// `data` under `type` as one item provider for a SwiftUI pasteboard hook; empty for nil.
    nonisolated static func providers(_ data: Data?, type: String) -> [NSItemProvider] {
        guard let data else { return [] }
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { load in
            load(data, nil)
            return nil
        }
        return [provider]
    }
}

extension View {
    /// The system's Cut, Copy, Paste and Delete on this view, sent to the window as `.cut`, `.copy`,
    /// `.paste` and `.deleteSelection`.
    func designPasteboardCommands(_ model: DesignWorkspace, _ perform: @escaping DesignPerform) -> some View {
        let type = model.pasteboardType
        let canCopy = model.copyHelp() == nil
        let canDelete = DesignMenu.deletesLayer(model)
        // Each runs the intent, then reads back what the window wrote, on the main actor.
        let copied: @MainActor () -> Data? = { perform(.copy); return DesignPasteboardBridge().read(type: type) }
        let cut: @MainActor () -> Data? = { perform(.cut); return DesignPasteboardBridge().read(type: type) }
        let bridge = DesignPasteboardBridge.self
        return self
            .onCopyCommand(perform: canCopy ? { bridge.providers(MainActor.assumeIsolated(copied), type: type) } : nil)
            .onCutCommand(perform: canCopy ? { bridge.providers(MainActor.assumeIsolated(cut), type: type) } : nil)
            .onPasteCommand(of: [UTType(importedAs: type)]) { _ in MainActor.assumeIsolated { perform(.paste) } }
            .onDeleteCommand(perform: canDelete ? { MainActor.assumeIsolated { perform(.deleteSelection) } } : nil)
    }
}
