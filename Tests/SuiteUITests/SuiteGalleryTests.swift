// SuiteGalleryTests.swift: the -SuiteGallery parser, the page list the area
// files declare (unique, the blueprint's 18 names, each resolving to one page
// view and an unknown name to the empty state; `editor` and `empty` built,
// `editor-plain` gone), the stub wording, the `editor` page's log lines on
// the live rule and the Fake, the SuiteWindow hook with the internal init
// that skips it, and a page's zero share of the window's minimum height.
// macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct SuiteGalleryTests {
    static let blueprintPages: Set<String> = [
        "index", "window", "editor", "empty", "inspector", "curves", "layers", "layers-300",
        "grid", "grid-2000", "canvas", "canvas-pt", "marks", "timeline", "timeline-long", "graph", "graph-loop",
    ]

    @Test func theParserReadsThePageFakesAndWidth() {
        #expect(SuiteGallery.request(from: ["Library", "-SuiteGallery", "editor"])
            == GalleryRequest(page: "editor", fakes: false, width: nil))
        #expect(SuiteGallery.request(from: ["Library"]) == nil)
        #expect(SuiteGallery.request(from: ["Library", "-SuiteGallery"]) == nil)
        #expect(SuiteGallery.request(from: ["Library", "-SuitePerfProbe", "-SuiteGalleryFakes"]) == nil)
        #expect(SuiteGallery.request(from: ["-SuiteGallery", "index", "-SuiteGalleryFakes"])?.fakes == true)
        #expect(SuiteGallery.request(from: ["-SuiteGallery", "index"])?.fakes == false)
        #expect(SuiteGallery.request(from: ["-SuiteGallery", "inspector", "-SuiteGalleryWidth", "240"])?.width == 240)
        for bad in ["abc", "0", "-5", "nan", "inf"] {
            #expect(SuiteGallery.request(from: ["-SuiteGallery", "inspector", "-SuiteGalleryWidth", bad])?.width == nil)
        }
        #expect(SuiteGallery.request(from: ["-SuiteGallery", "inspector", "-SuiteGalleryWidth"])?.width == nil)
    }

    @Test func pageNamesAreUniqueAcrossTheAreasAndHoldTheBlueprintNames() {
        let declared = SuiteGallery.areas.flatMap(\.keys)
        #expect(declared.count == Set(declared).count)
        #expect(Set(SuiteGallery.pages.keys) == Set(declared))
        #expect(Self.blueprintPages.isSubset(of: Set(declared)))
        #expect(SuiteGallery.pageNames == SuiteGallery.pages.keys.sorted())
    }

    @Test func everyPageResolvesToOneViewAndAnUnknownNameToTheEmptyState() {
        for name in SuiteGallery.pages.keys {
            #expect(SuiteGallery.resolve(name) == .page(name))
            #expect(SuiteGallery.areas.filter { $0[name] != nil }.count == 1)
        }
        #expect(SuiteGallery.resolve("nosuch") == .unknown("nosuch"))
        #expect(SuiteGallery.unknownTitle("nosuch") == "No gallery page named nosuch.")
    }

    @Test func aStubSaysWhichFeatureFillsIt() {
        #expect(SuiteGallery.stubTitle(page: "layers-300", feature: "lists")
            == "Layers-300 components land with lists.")
        #expect(SuiteGallery.stubTitle(page: "graph", feature: "node-graph") == "Graph components land with node-graph.")
    }

    @Test func theChromePagesAreEditorAndEmptyNotEditorPlain() {
        #expect(Set(GalleryChrome.pages.keys) == ["editor", "empty", "save-status"])
        #expect(SuiteGallery.resolve("editor-plain") == .unknown("editor-plain"))
    }

    @Test func theEditorPageLogsEachChangeTheJourneysRead() {
        var page = GalleryEditorPage()
        page.play()
        page.move(to: SuiteTransport().stepped(page.shownTransport, by: 1))
        page.setLoops(true)
        page.toggleOnion()
        page.select(tab: "layers")
        page.select(tool: "b")
        page.setReduceMotion(true)
        page.setWarning(false)
        #expect(page.lines == [
            "play on", "frame 13", "loop on", "toggle onion", "tab layers", "tool b", "reduce motion on",
            "warning off",
        ])
        #expect(page.onion && page.tab == "layers" && page.tool == "b" && page.reduceMotion && !page.warning)
        #expect(GalleryEditorPage.tabs.map(\.id) == ["adjust", "layers"])
    }

    @Test func theFrameCountSwitchLeavesNothingToPlayOnTheLiveRuleAndTheFake() {
        var page = GalleryEditorPage()
        page.setNoFrames(true)
        #expect(page.shownTransport.frameCount == 0)
        #expect(page.lines.last == "frames 0")
        let rules: [any TransportStepping] = [SuiteTransport(), FakeTransportStepping()]
        for stepping in rules {
            #expect(stepping.face(page.shownTransport).unavailableHelp == "Nothing to play.")
        }
        page.move(to: TransportState(frame: 5, frameCount: 48, fps: 24))
        #expect(page.lines.last == "frames 0")
        page.setNoFrames(false)
        #expect(page.shownTransport == TransportState(frame: 12, frameCount: 48, fps: 24))
        #expect(page.lines.last == "frames 48")
    }

    @Test func theInternalInitIgnoresTheGalleryFlag() {
        let inner = SuiteWindow(
            galleryPage: nil, title: "Window", sections: [], selection: nil, onSelect: { _ in },
            content: { Text(verbatim: "Content") }, inspector: { Text(verbatim: "Inspector") })
        #expect(inner.galleryRequest == nil)
        let hooked = SuiteWindow(
            galleryPage: SuiteGallery.request(from: ["-SuiteGallery", "window"]), title: "Window", sections: [],
            selection: nil, onSelect: { _ in }, content: { Text(verbatim: "Content") },
            inspector: { Text(verbatim: "Inspector") })
        #expect(hooked.galleryRequest?.page == "window")
        // The test runner has no -SuiteGallery, so the public init shows the app.
        let plain = SuiteWindow(
            title: "App", sections: [], selection: nil, onSelect: { _ in }, content: { Text(verbatim: "Content") },
            inspector: { Text(verbatim: "Inspector") })
        #expect(plain.galleryRequest == nil)
    }

    /// The editor-window page is a whole SuiteWindow; under the back row it
    /// must not raise the gallery's minimum height over the window's own, or
    /// SwiftUI grows a `-SuiteWindowSize` window past the visible frame (#2497).
    @Test func aPageAddsNothingToTheWindowMinimumHeight() {
        let host = NSHostingController(rootView: SuiteGallery(GalleryRequest(page: GalleryEditorWindow.name)))
        let minimum = host.sizeThatFits(in: CGSize(width: SuiteSize.windowLaunch.width, height: .zero))
        #expect(minimum.height <= SuiteSize.windowMinimum.height)
    }
}
