// SuiteDragSource.swift (file-flow SF-2 on the fakes, SF-8 live): a view a suite item is dragged out of.
// Files drag as their file URLs and text as a string; SF-8 writes PasteboardCoding's representations for
// the rest. An item the view can't give (nil) drags nothing.
import Foundation
import SuiteModel
import SwiftUI

extension View {
    /// Drags the item `item` gives when the drag starts.
    public func suiteDraggable(_ item: @escaping () -> SuiteClipItem?) -> some View {
        onDrag { SuiteDragSource.provider(for: item()) }
    }
}

enum SuiteDragSource {
    /// The provider a drag carries: the first file's URL, the text, or nothing.
    static func provider(for item: SuiteClipItem?) -> NSItemProvider {
        switch item {
        case .files(let refs):
            guard let ref = refs.first, let provider = NSItemProvider(contentsOf: URL(fileURLWithPath: ref.path)) else {
                return NSItemProvider()
            }
            return provider
        case .text(let text):
            return NSItemProvider(object: text as NSString)
        default:
            return NSItemProvider()
        }
    }
}
