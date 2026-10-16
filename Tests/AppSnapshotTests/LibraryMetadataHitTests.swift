// LibraryMetadataHitTests.swift: the metadata inspector's rating stars and
// label dots are the main cull controls, and they were 12-16 pt plain
// buttons 2 pt apart (#1669). Hosts MetadataInspector at the inspector's
// ideal and least widths, for one photo and for a mixed selection, and reads
// each star's and dot's accessibility frame: at least 20 x 20 pt
// (docs/design.md's floor), inside the inspector, and no two overlapping.
// A mixed row's "Mixed" text is one line, inside, and clear of every mark
// (#1719). No Label is not the grid's Rejected xmark (#1721). macOS only.
import AppKit
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryMetadataHitTests {
    static let ids: [String] = (1...5).map(MetadataInspectorID.star)
        + ([nil as PhotoLabel?] + PhotoLabel.allCases.map { $0 }).map(MetadataInspectorID.label)

    @Test(arguments: [false, true], [SuiteSize.inspectorWidth.ideal, SuiteSize.inspectorWidth.min])
    func everyStarAndDotHasAFullSizeHit(mixed: Bool, width: CGFloat) throws {
        let metadata = try Self.metadata(mixed: mixed)
        let size = CGSize(width: width, height: 400)
        let window = host(MetadataInspector(metadata: metadata), size: size)
        defer { window.orderOut(nil) }
        let bounds = CGRect(origin: .zero, size: size)
        var frames: [(String, CGRect)] = []
        for id in Self.ids {
            let hit = try #require(frame(of: id, in: window), "no \(id)")
            #expect(hit.width >= SuiteSize.iconButtonHit - 0.5, "\(id) is \(hit.width) pt wide")
            #expect(hit.height >= SuiteSize.iconButtonHit - 0.5, "\(id) is \(hit.height) pt tall")
            #expect(bounds.insetBy(dx: -0.5, dy: -0.5).contains(hit), "\(id) at \(hit) leaves the inspector")
            frames.append((id, hit))
        }
        for (i, a) in frames.enumerated() {
            for b in frames.dropFirst(i + 1) {
                let overlap = a.1.intersection(b.1)
                #expect(overlap.isNull || overlap.width * overlap.height < 1, "\(a.0) overlaps \(b.0)")
            }
        }
    }

    @Test(arguments: [SuiteSize.inspectorWidth.ideal, SuiteSize.inspectorWidth.min])
    func mixedTextIsOneLineClearOfTheMarks(width: CGFloat) throws {
        let metadata = try Self.metadata(mixed: true)
        #expect(metadata.rating == .mixed && metadata.label == .mixed)
        let size = CGSize(width: width, height: 400)
        let window = host(MetadataInspector(metadata: metadata), size: size)
        defer { window.orderOut(nil) }
        let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -0.5, dy: -0.5)
        let marks = try Self.ids.map { try #require(frame(of: $0, in: window), "no \($0)") }
        let line = NSFont.preferredFont(forTextStyle: .subheadline).boundingRectForFont.height
        for row in ["rating", "label"] {
            let id = MetadataInspector.mixedID(row)
            let text = try #require(frame(of: id, in: window), "no \(id)")
            #expect(text.height <= line + 1, "\(id) is \(text.height) pt tall: it wraps")
            #expect(text.width >= 20, "\(id) is \(text.width) pt wide")
            #expect(bounds.contains(text), "\(id) at \(text) leaves the inspector")
            for mark in marks {
                let overlap = text.intersection(mark)
                #expect(overlap.isNull || overlap.width * overlap.height < 1, "\(id) overlaps a mark at \(mark)")
            }
        }
    }

    @Test func noLabelIsNotTheRejectedMark() {
        #expect(MetadataInspector.noLabelSymbol != "xmark.circle")
        #expect(!MetadataInspector.noLabelSymbol.hasPrefix("xmark"))
        #expect(NSImage(systemSymbolName: MetadataInspector.noLabelSymbol, accessibilityDescription: nil) != nil)
    }

    private static func metadata(mixed: Bool) throws -> PhotoMetadata {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        let order = catalog.sortedItems.map(\.id)
        catalog.select(Set(order.prefix(1)))
        catalog.setRating(5)
        catalog.setLabel(.blue)
        catalog.select(Set(order.prefix(mixed ? 3 : 1)))
        return try #require(catalog.selectedMetadata)
    }
}

@MainActor private func host(_ view: some View, size: CGSize) -> NSWindow {
    let app = NSApplication.shared
    for attribute in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
        app.accessibilitySetValue(true, forAttribute: NSAccessibility.Attribute(rawValue: attribute))
    }
    let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(
        rootView: view.frame(width: size.width, height: size.height, alignment: .topLeading))
    window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    return window
}

/// The frame, in window coordinates, of the accessibility node `identifier`.
@MainActor private func frame(of identifier: String, in window: NSWindow) -> CGRect? {
    guard let view = window.contentView,
        let node = axNodes(in: view).first(where: { ($0.accessibilityIdentifier?() ?? nil) == identifier }),
        let screen = node.accessibilityFrame?()
    else { return nil }
    return window.convertFromScreen(screen)
}

/// Every node under `element` in the accessibility tree, in tree order.
@MainActor private func axNodes(in element: Any) -> [AnyObject] {
    let node = element as AnyObject
    return [node] + ((node.accessibilityChildren?() ?? nil) ?? []).flatMap { axNodes(in: $0) }
}
