// SuiteGalleryTests.swift: the -SuiteGallery parser, the page list the area
// files declare (unique, the blueprint's 18 names, each resolving to one page
// view and an unknown name to the empty state), the stub wording, and the
// SuiteWindow hook with the internal init that skips it. macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct SuiteGalleryTests {
    static let blueprintPages: Set<String> = [
        "index", "window", "editor", "editor-plain", "empty", "inspector", "curves", "layers", "layers-300",
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
        #expect(SuiteGallery.stubTitle(page: "editor-plain", feature: "editor-chrome")
            == "Editor-plain components land with editor-chrome.")
        #expect(SuiteGallery.stubTitle(page: "graph", feature: "node-graph") == "Graph components land with node-graph.")
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
}
