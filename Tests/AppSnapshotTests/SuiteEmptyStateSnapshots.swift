// SuiteEmptyStateSnapshots.swift: SuiteUI's EmptyStateView in Light and
// Dark: once with its action available (the one primary, system prominent
// button), once unavailable (the same button disabled, its reason as the
// tooltip) and once with no action at all (no button). Writes
// suiteui-empty-state-{available,unavailable,no-action}-{light,dark}.png.
// The button lists itself in `suite.controls` with role "primary" (EC-4);
// SwiftUI builds a hosting view's accessibility tree only for an assistive
// client, so the control inventory and the rendered pixels stand in for it:
// the prominent button is the only saturated fill on the view, so the
// variant with no action draws none. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteEmptyStateSnapshots {
    static let reason = "Importing needs a catalog folder; choose one in Settings first."

    static func importAction(enabled: Bool = true) -> ToolbarAction {
        ToolbarAction(
            "Import Photos", systemImage: "square.and.arrow.down",
            unavailableHelp: enabled ? nil : reason, identifier: "suite.gallery.empty.import")
    }

    static func view(_ action: ToolbarAction?) -> EmptyStateView {
        EmptyStateView(
            "No Photos", systemImage: "photo.on.rectangle",
            message: "Import photos to start your catalog.", action: action)
    }

    @Test func emptyStateAction() throws {
        let available = Self.importAction()
        let unavailable = Self.importAction(enabled: false)
        #expect(available.isEnabled)
        #expect(!unavailable.isEnabled)
        #expect(unavailable.help == Self.reason)
        let states: [(String, ToolbarAction?)] = [
            ("available", available), ("unavailable", unavailable), ("no-action", nil),
        ]
        for (state, action) in states {
            for scheme in [ColorScheme.light, .dark] {
                let suffix = scheme == .dark ? "dark" : "light"
                try snapshot(Self.view(action), name: "suiteui-empty-state-\(state)-\(suffix)", scheme: scheme)
            }
        }
    }

    @Test func theActionRegistersAsThePrimaryControl() throws {
        let store = SuiteControlStore()
        _ = try #require(render(Self.view(Self.importAction()).environment(\.suiteControlStore, store), scheme: .light))
        #expect(store.inventory.document().controls == [
            ControlEntry(id: "suite.gallery.empty.import", enabled: true, role: "primary"),
        ])
        #expect(store.inventory.violations().isEmpty)
    }

    @Test func anUnavailableActionRegistersDisabledWithItsReason() throws {
        let store = SuiteControlStore()
        let view = Self.view(Self.importAction(enabled: false))
        _ = try #require(render(view.environment(\.suiteControlStore, store), scheme: .light))
        #expect(store.inventory.document().controls == [
            ControlEntry(id: "suite.gallery.empty.import", enabled: false, reason: Self.reason, role: "primary"),
        ])
        #expect(store.inventory.violations().isEmpty)
    }

    @Test func theVariantWithNoActionShowsNoButton() throws {
        let store = SuiteControlStore()
        _ = try #require(render(Self.view(nil).environment(\.suiteControlStore, store), scheme: .light))
        #expect(store.inventory.document().controls.isEmpty)
        for scheme in [ColorScheme.light, .dark] {
            let withButton = try saturatedPixels(Self.view(Self.importAction()), scheme)
            let withoutButton = try saturatedPixels(Self.view(nil), scheme)
            #expect(withButton > 100, "the primary button drew no prominent fill in \(scheme)")
            #expect(withoutButton == 0, "\(withoutButton) saturated pixels with no action in \(scheme)")
        }
    }
}

/// How many of every other pixel carry a strong hue: the prominent button's
/// fill. The view's title, symbol and message are grays.
@MainActor
private func saturatedPixels(_ view: some View, _ scheme: ColorScheme) throws -> Int {
    let image = try #require(render(view, scheme: scheme))
    var count = 0
    for y in stride(from: 0, to: image.pixelsHigh, by: 2) {
        for x in stride(from: 0, to: image.pixelsWide, by: 2) {
            guard let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
            let channels = [color.redComponent, color.greenComponent, color.blueComponent]
            let spread = (channels.max() ?? 0) - (channels.min() ?? 0)
            if spread > 0.3 { count += 1 }
        }
    }
    return count
}
