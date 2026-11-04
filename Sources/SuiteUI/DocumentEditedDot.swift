// DocumentEditedDot.swift: `.suiteDocumentEdited(_:)`, the window's unsaved-changes
// dot (the close button's edited state, NSWindow.isDocumentEdited) driven from an
// editor Model's dirty flag (#2861). A zero-size background view sets its hosting
// window's flag when it lands in a window and on every change, so an editor passes
// `model.isDirty` from a body that already reads the save state and adds no body
// runs of its own.
import AppKit
import SwiftUI

extension View {
    /// Keeps the hosting window's edited dot (`NSWindow.isDocumentEdited`) on `edited`.
    public func suiteDocumentEdited(_ edited: Bool) -> some View {
        background(DocumentEditedDot(edited: edited))
    }
}

private struct DocumentEditedDot: NSViewRepresentable {
    let edited: Bool

    func makeNSView(context: Context) -> DocumentEditedView { DocumentEditedView() }

    func updateNSView(_ view: DocumentEditedView, context: Context) { view.edited = edited }
}

final class DocumentEditedView: NSView {
    var edited = false {
        didSet { window?.isDocumentEdited = edited }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isDocumentEdited = edited
    }
}
