// SuiteSearchable.swift: `suiteSearchable(text:identifier:)`, the window's
// `.searchable` field with accessibility identifiers. On the Mac that modifier
// puts an NSSearchField in the toolbar and gives SwiftUI no way to name it or
// its Search and cancel buttons, which the app audit's identifier check and the
// journeys need (#2215). A zero-size AppKit view behind the content finds the
// window's search fields once it is in a window (and again on the next turn of
// the run loop, after the toolbar is built) and names the field `<identifier>`,
// its buttons `<identifier>.search` and `<identifier>.cancel`.
import AppKit
import SwiftUI

extension View {
    /// `.searchable(text:)` whose toolbar field and its two buttons carry identifiers.
    public func suiteSearchable(text: Binding<String>, identifier: String) -> some View {
        searchable(text: text).background(SearchFieldNamer(identifier: identifier))
    }
}

private struct SearchFieldNamer: NSViewRepresentable {
    let identifier: String

    func makeNSView(context: Context) -> NamerView { NamerView(identifier: identifier) }

    func updateNSView(_ view: NamerView, context: Context) {
        view.identifier = NSUserInterfaceItemIdentifier(identifier)
        view.nameSoon()
    }

    final class NamerView: NSView {
        init(identifier: String) {
            super.init(frame: .zero)
            self.identifier = NSUserInterfaceItemIdentifier(identifier)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            nameSoon()
        }

        /// Names the fields now and once more after this turn, when a new toolbar has its items.
        func nameSoon() {
            name()
            DispatchQueue.main.async { [weak self] in self?.name() }
        }

        private func name() {
            guard let name = identifier?.rawValue, let root = window?.contentView?.superview else { return }
            for field in Self.searchFields(in: root) where field.accessibilityIdentifier() != name {
                field.setAccessibilityIdentifier(name)
                let cell = field.cell as? NSSearchFieldCell
                cell?.searchButtonCell?.setAccessibilityIdentifier(name + ".search")
                cell?.cancelButtonCell?.setAccessibilityIdentifier(name + ".cancel")
            }
        }

        private static func searchFields(in view: NSView) -> [NSSearchField] {
            if let field = view as? NSSearchField { return [field] }
            return view.subviews.flatMap(searchFields)
        }
    }
}
