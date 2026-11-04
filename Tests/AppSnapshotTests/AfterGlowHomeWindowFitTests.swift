// AfterGlowHomeWindowFitTests.swift: the real HomeWindow hosted at the
// journeys' 880 and 1000 by 640 (testHomeAtEveryWidth, #2042) on `weekOfWork`
// fakes. The split view and every column in it stay inside the window: at 880
// the journey found the sidebar's column 4 pt left of the window. It hosts the
// whole window, so it runs with the other hosted suites. The toolbar's search
// field and its Search and cancel buttons carry identifiers (#2215: the audit
// found the two buttons with none). macOS only.
#if canImport(AppKit)
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI
import Testing

@testable import AfterGlowApp

@MainActor @Suite struct AfterGlowHomeWindowFitTests {
    @Test(.timeLimit(.minutes(3)), arguments: [880.0, 1000.0])
    func splitViewFitsTheWindow(width: Double) async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let week = SuiteFixtures.store("weekOfWork", documents: "/fixture", now: now)?.recents ?? RecentsList()
        let size = CGSize(width: width, height: 640)
        let hosted = RenderBudgetWindow(HomeWindow(services: .fake(recents: week), support: "/fixture"), size: size)
        defer { hosted.close() }
        try await hosted.settle(500)
        let split = try #require(await hosted.first(NSSplitView.self), "no split view at \(width)")
        let bounds = CGRect(origin: .zero, size: size)
        let frame = split.convert(split.bounds, to: nil)
        let columns = split.arrangedSubviews.map { $0.convert($0.bounds, to: nil) }
        let report = "at \(width): split \(frame), columns \(columns), fitting \(hosted.host.fittingSize)"
        print("HOME-FIT " + report)
        #expect(frame.minX >= bounds.minX - 0.5 && frame.maxX <= bounds.maxX + 0.5, "\(report)")
        for column in columns {
            #expect(column.minX >= bounds.minX - 0.5 && column.maxX <= bounds.maxX + 0.5, "\(report)")
        }
    }

    @Test(.timeLimit(.minutes(3))) func searchFieldAndItsButtonsAreIdentified() async throws {
        // A titled window whose hosting controller bridges the toolbar, where `.searchable` puts its field.
        let window = NSWindow(contentViewController: NSHostingController(rootView: HomeWindow(services: .fake(), support: "/fixture")))
        window.styleMask = [.titled, .resizable]
        window.isReleasedWhenClosed = false
        window.setFrame(CGRect(x: -20_000, y: -20_000, width: 1000, height: 640), display: false)
        window.orderFrontRegardless()
        defer { window.close() }
        try await Task.sleep(for: .milliseconds(800))
        func search(_ view: NSView) -> NSSearchField? {
            view as? NSSearchField ?? view.subviews.lazy.compactMap(search).first
        }
        let root = try #require(window.contentView?.superview)
        let field = try #require(search(root), "no search field; toolbar \(String(describing: window.toolbar?.items))")
        let cell = try #require(field.cell as? NSSearchFieldCell)
        #expect(field.accessibilityIdentifier() == "afterglow.home.search")
        #expect(cell.searchButtonCell?.accessibilityIdentifier() == "afterglow.home.search.search")
        #expect(cell.cancelButtonCell?.accessibilityIdentifier() == "afterglow.home.search.cancel")
    }
}
#endif
