// SuiteDragSource.swift (file-flow SF-2 on the fakes, SF-8 live): a view suite items are dragged out of.
// The drag offers every representation PasteboardCoding gives for each item, richest first, so each app
// takes the best one it accepts: the suite envelope, SVG, PNG, text, and files as their file URLs. No item
// drags nothing.
import Foundation
import SuiteModel
import SwiftUI

extension View {
    /// Drags the items `items` gives when the drag starts, written through `coding`.
    public func suiteDraggable(_ coding: any PasteboardCoding, _ items: @escaping () -> [SuiteClipItem]) -> some View {
        onDrag { SuiteDragSource.provider(for: items(), coding: coding) }
    }

    /// Drags the item `item` gives when the drag starts, written through `coding`.
    public func suiteDraggable(_ coding: any PasteboardCoding, _ item: @escaping () -> SuiteClipItem?) -> some View {
        onDrag { SuiteDragSource.provider(for: item().map { [$0] } ?? [], coding: coding) }
    }
}

enum SuiteDragSource {
    /// The provider a drag carries: each item's representations in order, a type registered once.
    static func provider(for items: [SuiteClipItem], coding: any PasteboardCoding) -> NSItemProvider {
        let provider = NSItemProvider()
        var registered: Set<String> = []
        for rep in items.flatMap(coding.representations(of:)) where !registered.contains(rep.type.rawValue) {
            registered.insert(rep.type.rawValue)
            if rep.type == .fileURL {
                // PasteboardCoding writes `file://<path>` unescaped, so a `#` or `%` in a name is part of the path.
                let text = String(decoding: rep.data, as: UTF8.self)
                let path = text.hasPrefix("file://") ? String(text.dropFirst("file://".count)) : text
                provider.registerObject(URL(fileURLWithPath: path) as NSURL, visibility: .all)
            } else {
                let data = rep.data
                provider.registerDataRepresentation(forTypeIdentifier: rep.type.rawValue, visibility: .all) { load in
                    load(data, nil)
                    return nil
                }
            }
        }
        return provider
    }
}
