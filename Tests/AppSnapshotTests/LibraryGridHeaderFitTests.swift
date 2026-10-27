// LibraryGridHeaderFitTests.swift: the two rows over Library's grid, the
// filter bar and the toolbar row (LibraryGridToolbar), fit the content column
// of the narrowest window the journeys use: 880 pt less the sidebar's and the
// inspector's ideal widths. Hosted at that width, every control is inside the
// column, one line tall, and wider than a squeezed sliver. When they didn't
// fit, the toolbar row pushed the grid under both side columns and the filter
// bar wrapped Hide Rejected into a 19 pt column of letters, which the app
// audit read as unreadable text (#4727, #3877, #3325). macOS only.
import AppKit
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryGridHeaderFitTests {
    static let column = 880 - SuiteSize.sidebarWidth.ideal - SuiteSize.inspectorWidth.ideal
    /// Taller than one row of controls (the Size bar is 34 pt): a label wrapped onto several lines.
    static let oneLine: CGFloat = 40
    /// Narrower than any control showing its title or symbol: a chip squeezed to one letter.
    static let sliver: CGFloat = 24

    static let toolbarIDs = ["library.grid.toolbar.size", "library.grid.toolbar.sort",
                             "library.grid.toolbar.import", "library.grid.toolbar.export"]
    static let filterIDs = ["library.filter.flag.pick", "library.filter.flag.none", "library.filter.flag.reject",
                            "library.filter.rating", "library.filter.hideRejected", "library.filter.label",
                            "library.filter.clear"]

    @Test func theToolbarRowFitsTheColumn() throws {
        let model = LibraryGridToolbarSnapshots.samples(selecting: ["IMG_0001"])
        try expectFits(LibraryGridToolbar(model: model), ids: Self.toolbarIDs)
    }

    @Test func theFilterBarFitsTheColumn() throws {
        var model = LibraryGridToolbarSnapshots.samples()
        model.toggleHideRejected()
        var menu = LibraryFiltersMenu()
        menu.toggleFlag = { (_: PhotoFlag) in }
        menu.setRating = { (_: RatingRule) in }
        menu.toggleLabel = { (_: PhotoLabel) in }
        menu.toggleHideRejected = {}
        menu.clearFilter = {}
        let bar = LibraryFilterBar(
            filter: model.activeFilter, value: model.filterValue, caption: model.filterCaption, menu: menu)
        try expectFits(bar.fixedSize(horizontal: false, vertical: true), ids: Self.filterIDs)
    }

    /// Hosts `view` at the column's width and checks each of `ids`.
    private func expectFits(_ view: some View, ids: [String]) throws {
        let size = CGSize(width: Self.column, height: 300)
        let window = host(view, size: size)
        defer { window.orderOut(nil) }
        let column = CGRect(origin: .zero, size: size).insetBy(dx: -0.5, dy: -0.5)
        for id in ids {
            let rect = try #require(frame(of: id, in: window), "no \(id)")
            #expect(column.contains(rect), "\(id) at \(rect) leaves the \(Self.column) pt column")
            #expect(rect.height <= Self.oneLine, "\(id) is \(rect.height) pt tall: its label wraps")
            #expect(rect.width >= Self.sliver, "\(id) is \(rect.width) pt wide: squeezed")
        }
    }
}

@MainActor private func host(_ view: some View, size: CGSize) -> NSWindow {
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        NSApplication.shared.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: view.frame(width: size.width, height: size.height, alignment: .top))
    window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    return window
}

/// The window-coordinate frame of the accessibility node `identifier`.
@MainActor private func frame(of identifier: String, in window: NSWindow) -> CGRect? {
    func nodes(_ element: Any) -> [AnyObject] {
        let node = element as AnyObject
        return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { nodes($0) }
    }
    guard let view = window.contentView,
        let node = nodes(view).first(where: { ($0.accessibilityIdentifier?() ?? nil) == identifier }),
        let screen = node.accessibilityFrame?()
    else { return nil }
    return window.convertFromScreen(screen)
}
