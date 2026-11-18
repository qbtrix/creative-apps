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
// While a sheet is attached it names every search field in the window every
// quarter second: AppKit can swap the field's button cells under a sheet with
// no event, so no window update, after it (the Help menu's sheets, #6204), and
// accessibility reads whichever cell is current.
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

        /// Renames every search field in the window on a timer while a sheet is attached, since nothing else runs
        /// then (#6204). The timer itself stops once no sheet is attached, so one sheet's end under another doesn't.
        @objc private func sheetDidChange(_ note: Notification) {
            windowDidUpdate()
            guard sheetTimer == nil else { return }
            let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.sheetTick() }
            }
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
            sheetTimer = timer
        }

        private func sheetTick() {
            name()
            windowDidUpdate()
            if let path = UserDefaults.standard.string(forKey: "SuiteAXProbe") { Self.probe(to: path) }
            guard window?.attachedSheet == nil else { return }
            sheetTimer?.invalidate()
            sheetTimer = nil
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

        // DIAG ONLY (never lands): what serves the Search button under a sheet.
        static func probe(to path: String) {
            var out = "os \(ProcessInfo.processInfo.operatingSystemVersionString) t=\(Date().timeIntervalSince1970)\n"
            func ptr(_ o: AnyObject?) -> String { o.map { "\(type(of: $0))@\(Unmanaged.passUnretained($0).toOpaque())" } ?? "nil" }
            func id(_ o: NSObject) -> String {
                let a = o.accessibilityAttributeValue(.identifier) as? String
                let p = o as? NSAccessibilityProtocol; let b = p?.accessibilityIdentifier()
                return "attr=\(a ?? "nil") proto=\(b ?? "nil")"
            }
            for window in NSApp.windows {
                out += "window \(ptr(window)) title=\(window.title) sheet=\(ptr(window.attachedSheet)) key=\(window.isKeyWindow)\n"
                guard let root = window.contentView?.superview else { continue }
                for field in searchFields(in: root) {
                    let cell = field.cell as? NSSearchFieldCell
                    out += " field \(ptr(field)) \(id(field)) frame=\(field.frame) super=\(ptr(field.superview))\n"
                    out += "  cell \(ptr(cell)) \(cell.map(id) ?? "")\n"
                    out += "  searchButtonCell \(ptr(cell?.searchButtonCell)) \(cell?.searchButtonCell.map(id) ?? "")\n"
                    out += "  cancelButtonCell \(ptr(cell?.cancelButtonCell)) \(cell?.cancelButtonCell.map(id) ?? "")\n"
                    for case let kid as NSObject in (field.accessibilityChildren() ?? []) {
                        out += "  fieldKid \(kid) \(id(kid))\n"
                        for case let k2 as NSObject in (kid.accessibilityAttributeValue(.children) as? [Any] ?? []) {
                            out += "   kid2 \(k2) \(id(k2)) real=\(k2.responds(to: NSSelectorFromString("realElement")) ? ptr(k2.perform(NSSelectorFromString("realElement"))?.takeUnretainedValue()) : "n/a")\n"
                        }
                    }
                }
                func walk(_ o: NSObject, _ depth: Int) {
                    guard depth < 40 else { return }
                    let role = o.accessibilityAttributeValue(.role) as? String ?? ""
                    let desc = o.accessibilityAttributeValue(.description) as? String; let ttl = o.accessibilityAttributeValue(.title) as? String; let title = desc ?? ttl ?? ""
                    if role == "AXButton" && title == "Search" || role == "AXSearchField" || role == "AXTextField" && depth < 12 {
                        let pos = o.accessibilityAttributeValue(.position); let frame = pos.map { String(describing: $0) } ?? "?"
                        out += " ax d\(depth) \(role) '\(title)' \(o) \(id(o)) pos=\(frame)\n"
                    }
                    for case let k as NSObject in (o.accessibilityAttributeValue(.children) as? [Any] ?? []) { walk(k, depth + 1) }
                }
                walk(window, 0)
            }
            try? out.write(toFile: path, atomically: true, encoding: .utf8)
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
