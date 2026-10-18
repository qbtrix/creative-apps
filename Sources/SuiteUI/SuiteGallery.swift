// SuiteGallery.swift: SuiteUI's component gallery, the test surface its
// journeys drive (blueprint 4.1). Launching any SuiteWindow app with
// `-SuiteGallery <page>` makes the window's whole body this gallery, opened
// at that page; `-SuiteGalleryFakes` asks pages to run on the contract Fakes
// and `-SuiteGalleryWidth <points>` pins an inspector page's panel width.
// The flags are parsed in one pure function, `request(from:)`, so a different
// gate later is a one-line change; the gallery ships in release builds
// because the journeys launch release bundles. Each `Gallery/Gallery<Area>.swift`
// declares its own `pages`, so a feature adds a page in its own file; this
// file joins them. Every page root carries `suite.gallery.<page>`; an unknown
// name shows an EmptyStateView naming it. The index page lists every page and
// opens one through `openGalleryPage`; every other page has a back button to
// the index. The gallery root applies `.suiteProbes()`.
import SwiftUI

/// What `-SuiteGallery` asked for: the page, whether to run on the Fakes, and
/// an inspector page's pinned width in points.
public struct GalleryRequest: Equatable, Sendable {
    public var page: String
    public var fakes: Bool
    public var width: Double?

    public init(page: String, fakes: Bool = false, width: Double? = nil) {
        self.page = page
        self.fakes = fakes
        self.width = width
    }
}

/// What a page name shows: its page, or the unknown-page empty state.
enum GalleryContent: Equatable {
    case page(String)
    case unknown(String)
}

/// The page builders an area file declares, by page name.
typealias GalleryPages = [String: @MainActor () -> AnyView]

public struct SuiteGallery: View {
    public static let launchFlag = "-SuiteGallery"
    public static let fakesFlag = "-SuiteGalleryFakes"
    public static let widthFlag = "-SuiteGalleryWidth"

    private let request: GalleryRequest
    @State private var opened: String?

    public init(_ request: GalleryRequest) {
        self.request = request
    }

    /// The gallery request in `arguments`; nil without `-SuiteGallery <page>`.
    public static func request(from arguments: [String]) -> GalleryRequest? {
        guard let page = value(after: launchFlag, in: arguments) else { return nil }
        var width: Double?
        if let text = value(after: widthFlag, in: arguments), let points = Double(text), points.isFinite, points > 0 {
            width = points
        }
        return GalleryRequest(page: page, fakes: arguments.contains(fakesFlag), width: width)
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// Every area's pages, one dictionary per `Gallery<Area>.swift`.
    @MainActor static let areas: [GalleryPages] = [
        GalleryIndex.pages, GalleryMenus.pages, GalleryChrome.pages, GalleryInspector.pages, GalleryLists.pages,
        GalleryCanvas.pages, GalleryTimeline.pages, GalleryGraph.pages, GalleryEditorWindow.pages,
        GalleryAppMarks.pages, GalleryCanvasHost.pages, GalleryRenderingPane.pages,
    ]

    /// All pages by name; `SuiteGalleryTests` checks no two areas declare one name.
    @MainActor static let pages: GalleryPages = areas.reduce(into: [:]) { all, area in
        all.merge(area) { first, _ in first }
    }

    @MainActor static var pageNames: [String] { pages.keys.sorted() }

    @MainActor static func resolve(_ name: String) -> GalleryContent {
        pages[name] == nil ? .unknown(name) : .page(name)
    }

    static func unknownTitle(_ name: String) -> String { "No gallery page named \(name)." }

    /// A stub page's title: "<Page> components land with <feature>."
    static func stubTitle(page: String, feature: String) -> String {
        "\(page.prefix(1).uppercased())\(page.dropFirst()) components land with \(feature)."
    }

    /// Placeholder pages until `feature` fills them in its own area file.
    static func stubs(_ names: [String], feature: String) -> GalleryPages {
        var pages: GalleryPages = [:]
        for name in names {
            let title = stubTitle(page: name, feature: feature)
            let build: @MainActor () -> AnyView = {
                AnyView(EmptyStateView(title, systemImage: "square.dashed", message: "This page is a placeholder until then."))
            }
            pages[name] = build
        }
        return pages
    }

    public var body: some View {
        let name = opened ?? request.page
        // The back button sits in the page's own stack, not a safe-area inset:
        // from the inset, its `.suiteControl` never reached the window's
        // `suite.controls` while the index rows in the page did (SJ0).
        VStack(alignment: .leading, spacing: 0) {
            if name != GalleryIndex.name {
                Button {
                    opened = GalleryIndex.name
                } label: {
                    Label("Gallery Index", systemImage: "chevron.backward")
                }
                .help("Gallery Index")
                .suiteControl(id: "suite.gallery.back", enabled: true, reason: nil)
                .padding(SuiteSpacing.s)
            }
            GalleryPageView(name: name)
                .id(name)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.galleryRequest, request)
        .environment(\.openGalleryPage, { page in opened = page })
        .suiteProbes()
    }
}

/// One page, or the unknown-page empty state, under its `suite.gallery.*` identifier.
private struct GalleryPageView: View {
    let name: String

    var body: some View {
        switch SuiteGallery.resolve(name) {
        case .page(let page):
            (SuiteGallery.pages[page]?() ?? AnyView(EmptyView()))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suite.gallery.\(page)")
        case .unknown(let page):
            EmptyStateView(
                SuiteGallery.unknownTitle(page), systemImage: "questionmark.square.dashed",
                message: "Launch with -SuiteGallery index to list every page.")
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suite.gallery.unknown")
        }
    }
}

extension EnvironmentValues {
    /// The request the gallery was opened with; nil outside the gallery.
    var galleryRequest: GalleryRequest? {
        get { self[GalleryRequestKey.self] }
        set { self[GalleryRequestKey.self] = newValue }
    }

    /// Opens a gallery page by name; does nothing outside the gallery.
    var openGalleryPage: @MainActor (String) -> Void {
        get { self[OpenGalleryPageKey.self] }
        set { self[OpenGalleryPageKey.self] = newValue }
    }
}

private struct GalleryRequestKey: EnvironmentKey {
    static let defaultValue: GalleryRequest? = nil
}

private struct OpenGalleryPageKey: EnvironmentKey {
    static let defaultValue: @MainActor (String) -> Void = { _ in }
}
