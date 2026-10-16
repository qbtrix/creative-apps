// HomeNewRow.swift: the home's New row (blueprint suite.md 6.1, 7.3; HM-2b):
// one tile per NewTile, HomeLayout.tileWidth wide for the measured content
// width; its presets as ChoiceChips (at most 3) when HomeLayout.tileShowsChips,
// else a Menu. A click sends the tile's first preset through
// `model.newDocument`. A disabled tile says why (tooltip and suite.controls).
// While `model.launching` is the tile's app a small ProgressView shows (the
// AppTile #803 placeholder). HomeLayoutAnchors carries the frames
// AfterGlowHomeLayoutTests reads.
import SuiteModel
import SuiteUI
import SwiftUI

struct HomeNewRow: View {
    let model: HomeModel
    /// The row's width, measured; 0 until the first layout.
    @State private var width: CGFloat = 0

    /// HomeLayout works from the window width: the content plus the sidebar and both margins.
    private var windowWidth: Double { Double(width) + HomeLayout.sidebar + 2 * HomeLayout.margin }

    var body: some View {
        let tileWidth = CGFloat(HomeLayout.tileWidth(windowWidth: windowWidth))
        let chips = HomeLayout.tileShowsChips(windowWidth: windowWidth)
        HStack(alignment: .top, spacing: CGFloat(HomeLayout.gap)) {
            ForEach(model.state.tiles, id: \.app) { tile in
                HomeTile(tile: tile, showsChips: chips, isLaunching: model.launching == tile.app) { preset in
                    Task { await model.newDocument(preset, now: Date()) }
                }
                .frame(width: tileWidth, alignment: .topLeading)
                .homeLayoutAnchor("tile.\(tile.app.rawValue)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .homeLayoutAnchor("tiles")
    }
}

/// One New tile: the app's symbol and title as the button, its presets under it.
private struct HomeTile: View {
    let tile: NewTile
    let showsChips: Bool
    let isLaunching: Bool
    let create: @MainActor (NewDocumentPreset) -> Void

    private var id: String { "afterglow.home.new.\(tile.app.rawValue)" }
    private var enabled: Bool { tile.disabledReason == nil && !tile.presets.isEmpty }
    private var reason: String? { tile.disabledReason ?? (tile.presets.isEmpty ? "No presets for \(tile.title)." : nil) }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Button {
                if let first = tile.presets.first { create(first) }
            } label: {
                VStack(spacing: SuiteSpacing.xs) {
                    // A fixed glyph box and two reserved lines: every tile is one height.
                    Image(systemName: HomeSidebarRows.symbol(tile.app)).font(SuiteFont.title)
                        .frame(height: SuiteSize.switcherIcon)
                    Text(tile.title).font(SuiteFont.caption).lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, SuiteSpacing.s)
            }
            .buttonStyle(.bordered)
            .disabled(!enabled)
            .help(reason ?? tile.title)
            .suiteControl(id: id, enabled: enabled, reason: reason)
            .overlay(alignment: .topTrailing) {
                if isLaunching {
                    ProgressView().controlSize(.small).padding(SuiteSpacing.xs)
                        .accessibilityLabel("Opening \(tile.app.displayName)")
                }
            }
            presets
        }
    }

    @ViewBuilder private var presets: some View {
        let options = tile.presets.prefix(3).map { InspectorOption(id: $0.id, title: $0.title) }
        if showsChips {
            ChoiceChips(options: Array(options), selected: nil) { picked in
                if let preset = tile.presets.first(where: { $0.id == picked }) { create(preset) }
            }
            .disabled(!enabled)
            .help(reason ?? "Start from a preset")
            .suiteControl(id: id + ".presets", enabled: enabled, reason: reason, identifies: false)
            .homeLayoutAnchor("chips.\(tile.app.rawValue)")
        } else {
            Menu("Presets") {
                ForEach(tile.presets, id: \.id) { preset in
                    Button(preset.title) { create(preset) }
                }
            }
            .font(SuiteFont.pill)
            .controlSize(.small)
            .disabled(!enabled)
            .help(reason ?? "Start from a preset")
            .suiteControl(id: id + ".presets", enabled: enabled, reason: reason)
            .homeLayoutAnchor("menu.\(tile.app.rawValue)")
        }
    }
}

/// The home's frames by name ("tiles", "tile.<app>", "chips.<app>",
/// "menu.<app>", "recents", "empty", "running"), read by AfterGlowHomeLayoutTests.
struct HomeLayoutAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, next in next }
    }
}

extension View {
    /// Publishes this view's bounds under `name` in HomeLayoutAnchors.
    func homeLayoutAnchor(_ name: String) -> some View {
        anchorPreference(key: HomeLayoutAnchors.self, value: .bounds) { [name: $0] }
    }
}
