// SuiteEmptyStateSnapshots.swift: SuiteUI's EmptyStateView in Light and Dark:
// with its one action available (the primary button, bordered prominent in
// accentFill), unavailable (the same button disabled, its reason as the
// tooltip), and with no action (no button at all). Writes
// suiteui-empty-state-{available,unavailable,none}-{light,dark}.png, and
// checks the available state against Golden/chrome/empty-state-<appearance>.png
// in the four appearances (EC-12 commits the baselines). The button registers
// in `suite.controls` with role "primary" and, while disabled, its tooltip as
// the reason; the variant with no action registers nothing. SwiftUI builds a
// hosting view's accessibility tree only for an assistive client, so the
// inventory stands in for it. macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteEmptyStateSnapshots {
    static let reason = "Importing needs a catalog folder; choose one in Settings first."
    static let available = ToolbarAction(
        "Import Photos", systemImage: "square.and.arrow.down", identifier: "suite.empty.import")
    static let unavailable = ToolbarAction(
        "Import Photos", systemImage: "square.and.arrow.down", unavailableHelp: reason,
        identifier: "suite.empty.import")

    static func emptyState(_ action: ToolbarAction?) -> EmptyStateView {
        EmptyStateView(
            "No Photos", systemImage: "photo.on.rectangle",
            message: "Import photos to start your catalog.", action: action)
    }

    @Test func emptyStateAction() throws {
        #expect(Self.available.isEnabled)
        #expect(!Self.unavailable.isEnabled)
        #expect(Self.unavailable.help == Self.reason)
        let states: [(String, ToolbarAction?)] = [
            ("available", Self.available), ("unavailable", Self.unavailable), ("none", nil),
        ]
        for (state, action) in states {
            for scheme in [ColorScheme.light, .dark] {
                let suffix = scheme == .dark ? "dark" : "light"
                try snapshot(Self.emptyState(action), name: "suiteui-empty-state-\(state)-\(suffix)", scheme: scheme)
            }
        }
    }

    @Test func emptyStateGolden() {
        let size = CGSize(width: 420, height: 260)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(
                Self.emptyState(Self.available), size: size, name: "empty-state", area: "chrome",
                appearance: appearance)
        }
    }

    @Test func theButtonRegistersAsPrimaryWithItsTooltipAsTheReason() throws {
        for action in [Self.available, Self.unavailable] {
            let store = SuiteControlStore()
            let view = Self.emptyState(action)
            #expect(view.primaryAction?.title == action.title)
            _ = try #require(render(view.environment(\.suiteControlStore, store), scheme: .light))
            let entries = store.inventory.document().controls
            let expected = try #require(action.controlEntry(role: "primary"))
            #expect(entries == [expected])
            for entry in entries {
                #expect(entry.role == "primary")
                #expect(entry.enabled == action.isEnabled)
                // A disabled control's reason is exactly its tooltip; an enabled one needs none.
                #expect(entry.reason == (entry.enabled ? nil : action.help))
            }
            #expect(store.inventory.violations().isEmpty)
        }
    }

    @Test func withNoActionThereIsNoButton() throws {
        let store = SuiteControlStore()
        let view = Self.emptyState(nil)
        #expect(view.primaryAction == nil)
        _ = try #require(render(view.environment(\.suiteControlStore, store), scheme: .light))
        #expect(store.inventory.document().controls.isEmpty)
    }
}
