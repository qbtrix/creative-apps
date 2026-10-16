// HomeWindow.swift: the launcher's home window (blueprint suite.md 6.1,
// HM-2a): SuiteWindow (which applies `.suiteProbes()` once) over a HomeModel
// on LauncherServices.shared, reloaded then observed in a `.task`, with
// search, Open… (disabled, saying why, until a chosen file can be routed)
// and the model published as the `homeModel` focused value for the menus.
// HM-2b: the New row (HomeNewRow) and the inspector (HomeInspector).
import AppKit
import SuiteModel
import SuiteUI
import SwiftUI

/// A plain key rather than `@Entry`, as DesignMenuKey.
private struct HomeModelKey: FocusedValueKey { typealias Value = HomeModel }

extension FocusedValues {
    /// The focused home window's model; nil with no home window focused.
    var homeModel: HomeModel? { get { self[HomeModelKey.self] } set { self[HomeModelKey.self] = newValue } }
}

struct HomeWindow: View {
    @State private var model: HomeModel
    @State private var showsAssets = false
    @State private var images: [String: Image] = [:]
    private let services: SuiteServices
    private let support: String

    init(services: SuiteServices = LauncherServices.shared, support: String = LauncherServices.support) {
        self.services = services; self.support = support
        _model = State(initialValue: HomeModel(services: services, fileExists: { FileManager.default.fileExists(atPath: $0) }))
    }

    var body: some View {
        SuiteWindow(
            title: "AfterGlow", sections: HomeSidebarRows.sections,
            selection: HomeSidebarRows.selection(showsAssets: showsAssets, filter: model.filter),
            onSelect: select, actions: [HomeContent.open(services, identifier: "afterglow.home.open")]
        ) {
            if showsAssets { AssetsPage() } else { HomeContent(model: model, services: services, images: images) }
        } inspector: {
            HomeInspector(model: model, services: services)
        }
        .searchable(text: Binding(get: { model.query }, set: { model.search($0, now: Date()) }))
        .task { await model.reload(now: Date()); await model.observe(now: { Date() }) }
        .task(id: model.state.cards.compactMap(\.item.thumbnail)) {  // load each thumbnail once
            for path in model.state.cards.compactMap(\.item.thumbnail) where images[path] == nil {
                if let image = NSImage(contentsOfFile: support + "/" + path) { images[path] = Image(nsImage: image) }
            }
        }
        .focusedSceneValue(\.homeModel, model)
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
                     open: Self.open(services, identifier: "afterglow.home.empty.open"))
                .homeLayoutAnchor("recents")
            HomeRunningStrip(model: model)
                .homeLayoutAnchor("running")
        }
        .padding(SuiteSpacing.xl)
    }

    /// The "Preview data" pill shows only on the fakes, never on a live store.
    static func showsPreview(_ services: SuiteServices) -> Bool { services.isPreview }

    /// Open…: disabled with the routing or sending slot's reason until a chosen file can be routed.
    static func open(_ services: SuiteServices, identifier: String) -> ToolbarAction {
        let reason = services.pending["routing"] ?? services.pending["sending"] ?? SuiteServices.notConnected("routing")
        return ToolbarAction("Open…", systemImage: "folder", unavailableHelp: reason, identifier: identifier)
    }
}
