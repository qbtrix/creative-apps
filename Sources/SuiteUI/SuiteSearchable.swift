// SuiteSearchable.swift: `suiteSearchable(text:identifier:)`, the window's
// `.searchable` field with accessibility identifiers. On the Mac that modifier
// puts an NSSearchField in the toolbar and gives SwiftUI no way to name it or
// its Search and cancel buttons, which the app audit's identifier check and the
// journeys need (#2215). A zero-size AppKit view behind the content finds the
// window's search fields once it is in a window (and again on the next turn of
// the run loop, after the toolbar is built) and names the field and its cell
// `<identifier>` (accessibility reads the cell), its buttons `<identifier>.search`
// and `<identifier>.cancel`, and a collapsed item's Search button
// `<identifier>.collapsed`. On each window update it names a toolbar search
// item's field again, which AppKit rebuilds when the item collapses or the page
// changes, and the toolbar's "more toolbar items" pop-up, if a titlebar
// accessory pushed items into it, `<identifier minus its last part>.toolbar.more`.
// While a sheet is up it also does that every quarter second: AppKit can swap
// the field's button cells under a sheet with no event, so no window update,
// after it (the Help menu's sheets, #6204), and accessibility reads whichever
// cell is current.
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
            NotificationCenter.default.removeObserver(self)
            sheetTimer?.invalidate()
            sheetTimer = nil
            if let window {
                let center = NotificationCenter.default
                center.addObserver(self, selector: #selector(windowDidUpdate), name: NSWindow.didUpdateNotification, object: window)
                center.addObserver(self, selector: #selector(sheetDidChange), name: NSWindow.willBeginSheetNotification, object: window)
                center.addObserver(self, selector: #selector(sheetDidChange), name: NSWindow.didEndSheetNotification, object: window)
            }
            nameSoon()
        }

        private var sheetTimer: Timer?

        /// Renames on a timer while a sheet is attached, since nothing else runs then (#6204); stops when it ends.
        @objc private func sheetDidChange(_ note: Notification) {
            sheetTimer?.invalidate()
            sheetTimer = nil
            guard note.name == NSWindow.willBeginSheetNotification else { return windowDidUpdate() }
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.windowDidUpdate() }
            }
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
            sheetTimer = timer
        }

        /// A toolbar search item rebuilds its field when it collapses or the page changes; only the
        /// toolbar's items are read here, so this per-update pass stays cheap.
        @objc private func windowDidUpdate() {
            guard let name = identifier?.rawValue else { return }
            for item in window?.toolbar?.items ?? [] {
                if let field = (item as? NSSearchToolbarItem)?.searchField {
                    Self.name(field, name)
                    Self.nameOverflow(near: field, name)
                }
            }
        }

        /// Names the fields now and once more after this turn, when a new toolbar has its items.
        func nameSoon() {
            name()
            DispatchQueue.main.async { [weak self] in self?.name() }
        }

        private func name() {
            guard let name = identifier?.rawValue, let root = window?.contentView?.superview else { return }
            for field in Self.searchFields(in: root) { Self.name(field, name) }
        }

        private static func name(_ field: NSSearchField, _ name: String) {
            let cell = field.cell as? NSSearchFieldCell
            // Accessibility reads the cell, not the field (under a sheet the bare field shows), and AppKit can swap
            // the button cells while the field keeps its name, so each is checked on its own.
            set(field, name)
            if let cell { set(cell, name) }
            if let search = cell?.searchButtonCell { set(search, name + ".search") }
            if let cancel = cell?.cancelButtonCell { set(cancel, name + ".cancel") }
            // A collapsed toolbar search item shows a Search button beside the field, read through its cell.
            for case let button as NSButton in field.superview?.subviews ?? [] {
                set(button, name + ".collapsed")
                if let cell = button.cell { set(cell, name + ".collapsed") }
            }
        }

        /// A titlebar accessory can squeeze the toolbar until AppKit folds items into its "more toolbar items"
        /// pop-up, which nothing else names (#6204). It sits in the same toolbar view as the search item.
        private static func nameOverflow(near field: NSSearchField, _ name: String) {
            var toolbar = field.superview
            while let view = toolbar, String(describing: type(of: view)) != "NSToolbarView" { toolbar = view.superview }
            guard let toolbar else { return }
            let more = String(name.split(separator: ".").dropLast().joined(separator: ".")) + ".toolbar.more"
            func walk(_ view: NSView) {
                let type = String(describing: Swift.type(of: view))
                // Only an unnamed one: a toolbar menu the app named keeps its own identifier.
                if view.accessibilityIdentifier().isEmpty || view.accessibilityIdentifier() == more,
                   view is NSPopUpButton || type.contains("Clipped") || type.contains("Overflow") {
                    set(view, more)
                    if let cell = (view as? NSControl)?.cell { set(cell, more) }
                }
                view.subviews.forEach(walk)
            }
            walk(toolbar)
        }

        private static func set(_ element: NSAccessibilityProtocol, _ name: String) {
            if element.accessibilityIdentifier() != name { element.setAccessibilityIdentifier(name) }
        }

        private static func searchFields(in view: NSView) -> [NSSearchField] {
            if let field = view as? NSSearchField { return [field] }
            return view.subviews.flatMap(searchFields)
        }
    }
}
