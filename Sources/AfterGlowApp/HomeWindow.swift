// HomeWindow.swift: the launcher's home window (blueprint suite.md 6.1,
// HM-2a): SuiteWindow (which applies `.suiteProbes()` once) over a HomeModel
// on LauncherServices.shared, reloaded then observed in a `.task`, with
// search, Open… (a file panel whose files go to the apps that read them)
// and the model published as the `homeModel` focused value for the menus,
// with the page it shows as `homePage`, so Edit > Delete is titled for it.
// HM-2b: the New row (HomeNewRow) and the inspector (HomeInspector).
// File-flow SF-2: files dropped on the window go to the apps that read them
// (DropPlan through the documents bridge); the launcher opens none itself.
import AppKit
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// A plain key rather than `@Entry`, as DesignMenuKey.
private struct HomeModelKey: FocusedValueKey { typealias Value = HomeModel }
private struct HomePageKey: FocusedValueKey { typealias Value = HomePage }

extension FocusedValues {
    /// The focused home window's model; nil with no home window focused.
    var homeModel: HomeModel? { get { self[HomeModelKey.self] } set { self[HomeModelKey.self] = newValue } }
    /// The page the focused home window shows; nil with no home window focused.
    var homePage: HomePage? { get { self[HomePageKey.self] } set { self[HomePageKey.self] = newValue } }
}

struct HomeWindow: View {
    @State private var model: HomeModel
    @State private var showsAssets = false
    @State private var images: [String: Image] = [:]
    @State private var bridge: SuiteDocumentsBridge
    private let services: SuiteServices
    private let support: String

    init(services: SuiteServices = LauncherServices.shared, support: String = LauncherServices.support) {
        self.services = services; self.support = support
        _model = State(initialValue: HomeModel(services: services, fileExists: { FileManager.default.fileExists(atPath: $0) }))
        _bridge = State(initialValue: SuiteDocumentsBridge(app: .launcher, services: services))
    }

    var body: some View {
        SuiteWindow(
            title: "AfterGlow", sections: HomeSidebarRows.sections,
            selection: HomeSidebarRows.selection(showsAssets: showsAssets, filter: model.filter),
            onSelect: select, actions: [HomeContent.open(services, identifier: "afterglow.home.open", model: model)]
        ) {
            if showsAssets { AssetsPage() } else { HomeContent(model: model, services: services, images: images) }
        } inspector: {
            HomeInspector(model: model, services: services)
        }
        .suiteSwitcher(current: .launcher)
        .suiteFileDrop(.launcher, bridge: bridge, hasDocument: false, places: [], perform: { actions in
            let bridge = self.bridge
            Task { await bridge.handOff(actions) }
        })
        .suiteSearchable(text: Binding(get: { model.query }, set: { model.search($0, now: Date()) }),
                         identifier: "afterglow.home.search")
        .task { await model.reload(now: Date()); await model.observe(now: { Date() }) }
        .task(id: model.state.cards.compactMap(\.item.thumbnail)) {  // load each thumbnail once
            for path in model.state.cards.compactMap(\.item.thumbnail) where images[path] == nil {
                if let image = NSImage(contentsOfFile: support + "/" + path) { images[path] = Image(nsImage: image) }
            }
        }
        .focusedSceneValue(\.homeModel, model)
        .focusedSceneValue(\.homePage, showsAssets ? .assets : .home)
    }

    private func select(_ id: SidebarItem.ID) {
        showsAssets = id == HomeSidebarRows.assets
        model.filter(SuiteApp(rawValue: id), now: Date())
    }
}

/// The Home page on HomeLayout's 24 pt margin: the New row pinned at the
/// top, the running strip at the bottom, the recents in the height between.
struct HomeContent: View {
    let model: HomeModel
    let services: SuiteServices
    let images: [String: Image]

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            HomeNewRow(model: model)
            HomeGrid(model: model, images: images, isPreview: Self.showsPreview(services),
                     open: Self.open(services, identifier: "afterglow.home.empty.open", model: model))
                .homeLayoutAnchor("recents")
            HomeRunningStrip(model: model)
                .homeLayoutAnchor("running")
        }
        .padding(SuiteSpacing.xl)
    }

    /// The "Preview data" pill shows only on the fakes, never on a live store.
    static func showsPreview(_ services: SuiteServices) -> Bool { services.isPreview }

    /// Open…: disabled with HomeMenu's reason, as File > Open…, while routing or sending is pending;
    /// else it asks for files and the model hands each to the app that reads it.
    static func open(_ services: SuiteServices, identifier: String, model: HomeModel? = nil) -> ToolbarAction {
        ToolbarAction("Open…", systemImage: "folder", unavailableHelp: HomeMenu.openReason(pending: services.pending),
                      identifier: identifier) {
            guard let model else { return }
            let paths = chooseFiles()
            if !paths.isEmpty { Task { await model.open(paths: paths, now: Date()) } }
        }
    }

    /// The Open… panel: one or more files; empty when cancelled.
    // view-static: main-actor
    static func chooseFiles() -> [String] {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return [] }
        return panel.urls.map { $0.path(percentEncoded: false) }
    }
}
