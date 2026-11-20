// DocumentEditedDot.swift: `.suiteDocumentEdited(_:)`, the window's unsaved-changes
// dot (the close button's edited state, NSWindow.isDocumentEdited) driven from an
// editor Model's dirty flag. A background view sets its hosting window's flag when
// it lands in a window and on every change, so an editor passes `model.isDirty`
// from a body that already reads the save state and adds no body runs of its own.
// XCUITest can't see the dot, so the same view is the hidden `suite.window.edited`
// element: a group (not text, not a control, so the app audit skips it) whose label
// and value read "edited" or "saved" from the WINDOW's flag at the moment they are
// asked, never from the model, so a journey proves what the window shows. Its frame
// is 1 x 1 pt at the view's corner and it takes no hits.
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
    /// The accessibility identifier journeys read the window's edited dot by.
    static let identifier = "suite.window.edited"

    var edited = false {
        didSet { window?.isDocumentEdited = edited }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isDocumentEdited = edited
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// "edited" or "saved", from the hosting window's own flag; nil outside a window.
    private var windowState: String? {
        window.map { $0.isDocumentEdited ? "edited" : "saved" }
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .group }
    override func accessibilityIdentifier() -> String { Self.identifier }
    override func accessibilityLabel() -> String? { windowState }
    override func accessibilityValue() -> Any? { windowState }

    override func accessibilityFrame() -> NSRect {
        guard let window else { return .zero }
        return window.convertToScreen(convert(NSRect(x: 0, y: 0, width: 1, height: 1), to: nil))
    }
}
