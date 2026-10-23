// DesignSnapSettingTests.swift: snapping SN-8, View > Snap to Layers and the
// modifiers of a canvas step, on a private UserDefaults suite. With no stored
// value the setting reads on and the mapping has no `.noSnap`; stored off, or
// ⌘ held, the mapping has it; Shift and Option keep their meanings; the menu
// item's toggle writes the key. The item takes no DesignMenu, so no file state
// can turn it off; its place after Fit Page in the live menu bar is the snap
// journey's (UITests/DesignJourneyTests+Snap.swift, step 1). macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignSnapSettingTests {
    /// A fresh defaults suite, removed again when `body` returns.
    private func withSuite(_ body: (UserDefaults) throws -> Void) throws {
        let name = "design.snap-setting-tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test func missingValueReadsOn() throws {
        try withSuite { defaults in
            #expect(defaults.object(forKey: DesignSnapSettings.defaultsKey) == nil)
            #expect(DesignModifiers.snapsToLayers(in: defaults))
            #expect(!DesignModifiers.make(flags: [], defaults: defaults).contains(.noSnap))
            #expect(DesignModifiers.make(flags: [.shift, .option], defaults: defaults) == [.shift, .option])
        }
    }

    @Test func storedOffMapsToNoSnap() throws {
        try withSuite { defaults in
            defaults.set(false, forKey: DesignSnapSettings.defaultsKey)
            #expect(!DesignModifiers.snapsToLayers(in: defaults))
            #expect(DesignModifiers.make(flags: [], defaults: defaults) == .noSnap)
            #expect(DesignModifiers.make(flags: .shift, defaults: defaults) == [.shift, .noSnap])
        }
    }

    @Test func commandAloneMapsToNoSnap() throws {
        try withSuite { defaults in
            #expect(DesignModifiers.make(flags: .command, defaults: defaults) == .noSnap)
            #expect(DesignModifiers.make(flags: [.command, .option], defaults: defaults) == [.option, .noSnap])
        }
    }

    @Test func togglingWritesTheKey() throws {
        try withSuite { defaults in
            let item = DesignSnapToLayersItem(store: defaults)
            item.set(false)
            #expect(defaults.object(forKey: DesignSnapSettings.defaultsKey) as? Bool == false)
            #expect(DesignModifiers.make(flags: [], defaults: defaults).contains(.noSnap))
            item.set(true)
            #expect(defaults.object(forKey: DesignSnapSettings.defaultsKey) as? Bool == true)
            #expect(!DesignModifiers.make(flags: [], defaults: defaults).contains(.noSnap))
        }
    }

    @Test func viewMenuBuildsWithNoFileOpen() throws {
        try withSuite { defaults in
            let menu = DesignViewMenu(menu: DesignMenu(), snapStore: defaults)
            #expect(!menu.menu.isOpen)
            _ = try #require(render(menu.labelStyle(.titleAndIcon), scheme: .light))
        }
    }
}
#endif
