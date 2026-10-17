// CanvasHostIntegrationTests.swift: canvas-host CH-9. The gallery's
// `settings-rendering` and `canvas-host` pages run on the live preference
// store (CH-7), the hit map (CH-6) and the tile set (CH-8), and the viewport
// variant hosts a CanvasHost under the viewport's ids. Each preference test
// opens a scratch defaults domain so it never touches the suite's real one.
// macOS only.
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite(.serialized) struct CanvasHostIntegrationTests {
    private func scratchDomain() -> String { "org.creativesuite.tests.rendering.\(UUID().uuidString)" }
    private func forget(_ domain: String) { UserDefaults.standard.removePersistentDomain(forName: domain) }

    @Test func theRenderingPageRunsOnTheSuitesSharedDomain() {
        #expect(GalleryRenderingPane.suiteName == RenderingPreference.suiteName)
    }

    @Test func theRenderingPagesModelReadsAndWritesTheLiveStore() {
        let domain = scratchDomain()
        defer { forget(domain) }
        let model = GalleryRenderingPane.liveModel(suiteName: domain)
        let other = RenderingPreference(suiteName: domain)
        other.set(.cpu)
        #expect(model.choice == .cpu)
        model.pick(.gpu)
        #expect(other.choice == .gpu)
        #expect(model.statusLine == "Drawing on GPU")
    }

    @Test func theRenderingChoicePersistsAcrossARelaunch() {
        let domain = scratchDomain()
        defer { forget(domain) }
        do {
            let first = GalleryRenderingPane.liveModel(suiteName: domain)
            first.pick(.cpu)
        }
        let relaunched = GalleryRenderingPane.liveModel(suiteName: domain)
        #expect(relaunched.choice == .cpu)
        #expect(relaunched.statusLine == "Drawing on CPU")
    }

    @Test func hoverNamesTheTileUnderThePointerFromTheHitMap() {
        let log = CanvasHostLog()
        log.hover(CGPoint(x: 10, y: 10))
        #expect(log.hovered == "Tile 1-1")
        log.hover(CGPoint(x: 4090, y: 2150))
        #expect(log.hovered == "Tile 5-4")
        log.hover(nil)
        #expect(log.hovered == nil)
        #expect(GalleryCanvasDocument.hitMap.marks.count == 20)
    }

    @Test func theDocumentsTilesComeThroughTheTileSet() {
        let tileSet = CanvasTileSet()
        let document = GalleryCanvasDocument.make(through: tileSet)
        let tiles = document.tiles(dirtyOnly: false)
        #expect(document.documentSize == CGSize(width: 4096, height: 2160))
        #expect(tiles.count == 20)
        #expect(tiles.allSatisfy { $0.image.map(CanvasTileSet.isPremultipliedSRGB) == true })
        #expect(tiles.allSatisfy { $0.image === tileSet.image(at: $0.rect) })
        #expect(document.tiles(dirtyOnly: true).count == 20)
        #expect(tileSet.documentSize == document.documentSize)
    }

    @Test func theViewportVariantHostsACanvasHostUnderTheViewportsIDs() throws {
        let log = CanvasHostLog()
        let viewport = CanvasViewport(host: GalleryCanvasDocument.make(), delegate: log, zoom: 0.25)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = NSHostingView(rootView: viewport.frame(width: 960, height: 600))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let canvas = try #require(hostView(in: window.contentView))
        #expect(canvas.accessibilityIdentifier() == RenderingControlID.canvas)
    }

    @Test func theCanvasHostPageReadsTheLiveStoreItIsGiven() throws {
        let domain = scratchDomain()
        defer { forget(domain) }
        RenderingPreference(suiteName: domain).set(.cpu)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.contentView = NSHostingView(rootView: CanvasHostPage(suiteName: domain).frame(width: 960, height: 600))
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let canvas = try #require(hostView(in: window.contentView))
        #expect(canvas.accessibilityIdentifier() == RenderingControlID.canvas)
        #expect(RenderingMenuModel(preference: RenderingPreference(suiteName: domain)).choice == .cpu)
    }
}

@MainActor private func hostView(in view: NSView?) -> CanvasHostView? {
    guard let view else { return nil }
    return view as? CanvasHostView ?? view.subviews.lazy.compactMap { hostView(in: $0) }.first
}
